#!/usr/bin/env bash

source ./config.sh

function divider() {
  echo '::::::::::::::::::::::::::::::'
}

function clone_components() {
  for comp in ${components[*]}; do
    echo clonning ${comp}

    branch=${comp}_branch
    clone_component https://github.com/openshift/tektoncd-${comp}.git \
                    ${!branch} \
                    rhosp_${comp}
  done
}

function clone_component() {
  repo_url=${1}
  branch=${2}
  clone_dir=${3}
  rm -rf ${clone_dir} || true
  git clone --branch ${branch} --depth 1 ${repo_url} ${clone_dir}
}

function setup_openshift_registry() {
  ## configure openshift internal registry access
  oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
  sleep 30
  registry_url=$(oc registry info --public)
  divider
  echo registry_url = ${registry_url}
  divider
#   oc registry login --to=$HOME/.docker/config.json --insecure
  oc registry login --to=$HOME/.docker/config.json --insecure    --registry ${registry_url}
}

function get_buildah_task() {
# The fetch task script will not pull buildah task from github repository
# as we have have made modifications in the buildah task in operator repository
# This function will preserve the buildah task from the previous release (clusterTask payload)
    buildah_dest_dir="cmd/openshift/operator/kodata/tekton-addon/${RHOSP_VERSION}/addons/02-clustertasks/buildah"
    mkdir -p ${buildah_dest_dir} || true
    task_path=${buildah_dest_dir}/buildah-task.yaml
    version_suffix="${RHOSP_VERSION//./-}"
    task_version_path=${buildah_dest_dir}/buildah-${version_suffix}-task.yaml

    cp -r cmd/openshift/operator/kodata/tekton-addon/1.5.0/addons/02-clustertasks/buildah/buildah-task.yaml ${buildah_dest_dir}
    sed \
        -e "s|^\(\s\+name:\)\s\+\(buildah\)|\1 \2-$RHOSP_VERSION|g"  \
        $task_path  > "$task_version_path"
}

# copy all addon other than clustertasks into the nightly addon payload directory
function copy_static_addon_resources() {
  src_version=${1}
  dest_version=${2}
  src_dir="cmd/openshift/operator/kodata/tekton-addon/${src_version}"
  dest_dir="cmd/openshift/operator/kodata/tekton-addon/${dest_version}"

  cp -r ${src_dir}/optional ${dest_dir}/optional

  addons_dir_src=${src_dir}/addons
  addons_dir_dest=${dest_dir}/addons

  for item in $(ls ${addons_dir_src} | grep -v 02-clustertasks); do
    cp -r ${addons_dir_src}/${item} ${addons_dir_dest}/${item}
  done
}

function configure_rhosp_build() {
  #update pipelines and triggers payload
  pushd rhosp_operator
  pwd
  make get-releases TARGET='openshift' \
                  PIPELINES=${PIPELINE_VERSION} \
                  TRIGGERS=${TRIGGERS_VERSION}

  # handle buildah task separately
  get_buildah_task
  # pull tasks
  ./hack/openshift/update-tasks.sh ${CATALOG_RELEASE_BRANCH} cmd/openshift/operator/kodata/tekton-addon/${RHOSP_VERSION} ${RHOSP_VERSION}

  copy_static_addon_resources 1.5.0 ${RHOSP_VERSION}
  popd
}

function build_rhosp_images() {
  for comp in ${components[*]}; do
      echo building ${comp} images
      divider
      configure_image_build ${comp}
      pushd rhosp_${comp}
      pwd
      echo $KO_DOCKER_REPO
#       ko resolve -f config --base-import-paths --insecure-registry --tag-only --tags release-next
      if [[ ${comp} == "operator" ]]; then
        kustomize build --load-restrictor LoadRestrictionsNone config/openshift | ko resolve -f - --base-import-paths --insecure-registry --tag-only --tags release-next >> ../ko_build_log 2>&1
        continue
      fi
      if [[ ${comp} == "triggers" ]]; then
        ko resolve -f config/interceptors --base-import-paths --insecure-registry --tag-only --tags release-next >> ../ko_build_log 2>&1
      fi
      ko resolve -f config --base-import-paths --insecure-registry --tag-only --tags release-next >> ../ko_build_log 2>&1
      popd
  done
}

function configure_image_build() {
    component=$1
    namespace_var=${component}_imagestreams_namespace
    echo $component
    echo $namespace
    namespace=${!namespace_var}
    oc create namespace ${namespace} || true
    export KO_DOCKER_REPO=$(oc registry info --public)/${namespace}
    echo $KO_DOCKER_REPO
    divider
}

function create_rhosp_bundle() {
  pwd
  ls
  cp ./config.yaml rhosp_operator/operatorhub/openshift/config.yaml
  pushd rhosp_operator
  mkdir .bin || true
  divider
  echo bundle geration from: $(pwd)
  export BUNDLE_ARGS="--workspace operatorhub/openshift \
               --operator-release-version ${RHOSP_VERSION} \
               --channels stable,preview \
               --default-channel stable \
               --fetch-strategy-local \
                --upgrade-strategy-semver \
               --olm-skip-range ${OLM_SKIP_RANGE}"
  make operator-bundle
  divider
  pwd
  popd
  #                 --upgrade-strategy-replaces \
  #                 --upgrade-strategy-replaces \
  #                --operator-release-previous-version ${RHOSP_PREVIOUS_VERSION} \

}

function build_push_bundle_image() {
  pushd operatorhub/openshift/release-artifacts
  bundle_image=${KO_DOCKER_REPO}/rhosp-bundle:release-next
  divider
  echo bundle image build context $(pwd)
  divider
  pwd
  tree
  docker build -f bundle.Dockerfile -t ${bundle_image} .
  docker push ${bundle_image}
  popd
}

function build_push_index_image() {
  bundle_image=${KO_DOCKER_REPO}/rhosp-bundle:release-next
  index_image=${KO_DOCKER_REPO}/rhosp-catalog-index:release-next
  opm index add --build-tool docker --bundles ${bundle_image} --tag ${index_image}
  docker push ${index_image}
}

function build_operatorhub_images() {
  export KO_DOCKER_REPO=$(oc registry info --public)/openshift-marketplace
  pushd rhosp_operator
  divider
  echo building bundle image and index image
  pwd
  echo $KO_DOCKER_REPO
  divider

  build_push_bundle_image

  build_push_index_image
  popd
}

function disable_default_operatorhub_sources() {
  oc patch operatorhubs.config.openshift.io/cluster --patch '{"spec":{"disableAllDefaultSources":true}}' --type=merge
}

function create_custom_catalog() {
  index_image=${KO_DOCKER_REPO}/rhosp-catalog-index:release-next
  cat <<EOF | oc apply -f -
  apiVersion: operators.coreos.com/v1alpha1
  kind: CatalogSource
  metadata:
    name: rhosp-catalog
    namespace: openshift-marketplace
  spec:
    sourceType: grpc
    image: ${index_image}
EOF

}

function add_operator_to_oncluster_operatorhub() {
  build_operatorhub_images
  disable_default_operatorhub_sources
  create_custom_catalog
}

function configure_image_pull_privileges() {
  oc policy add-role-to-user \
      system:image-puller system:serviceaccount:openshift-operators:openshift-pipelines-operator \
      --namespace=rhosp-operator-images

  oc policy add-role-to-user \
        system:image-puller system:serviceaccount:openshift-pipelines:tekton-pipelines-controller \
        --namespace=rhosp-pipeline-images

  oc policy add-role-to-user \
          system:image-puller system:serviceaccount:openshift-pipelines:tekton-pipelines-webhook \
          --namespace=rhosp-pipeline-images

  oc policy add-role-to-user \
            system:image-puller system:serviceaccount:openshift-pipelines:tekton-operators-proxy-webhook \
            --namespace=rhosp-operator-images

  oc policy add-role-to-user \
          system:image-puller system:serviceaccount:openshift-pipelines:tekton-triggers-controller \
          --namespace=rhosp-triggers-images

  oc policy add-role-to-user \
          system:image-puller system:serviceaccount:openshift-pipelines:tekton-triggers-webhook \
          --namespace=rhosp-triggers-images

  oc policy add-role-to-user \
            system:image-puller system:serviceaccount:openshift-pipelines:tekton-triggers-core-interceptors \
            --namespace=rhosp-triggers-images
}

function set_up_default_and_current_project() {
  set_up_sa_for_taskruns default
  current_project=$(oc project --short)
  if [[ ${current_project} -ne "default" ]]; then
     set_up_sa_for_taskruns ${current_project}
  fi
}

function set_up_sa_for_taskruns() {
  service_account=pipeline
  namespace=$1

  oc policy add-role-to-user \
            system:image-puller system:serviceaccount:${namespace}:${service_account} \
            --namespace=rhosp-pipeline-images

  oc policy add-role-to-user \
            system:image-puller system:serviceaccount:${namespace}:${service_account} \
            --namespace=rhosp-triggers-images
}


