#!/usr/bin/env bash

# Ref:
# 1. install ko: https://github.com/google/ko#install-from-releases
# 2. 'ko' with OpenShift Internal Regtistry: https://github.com/google/ko#does-ko-work-with-openshift-internal-registry

# set +xe
source ./utils.sh

rm -rf /tmp/rhosp*
workspace_dir=$(mktemp -d /tmp/rhosp-$(date +%y-%m-%d)-XXXXX)
cp ${BUNDLE_GENERATION_CONFIG} ${workspace_dir}/config.yaml

cd ${workspace_dir}
echo workspace_dir=$(pwd)

cd ${workspace_dir}
setup_openshift_registry

cd ${workspace_dir}
# step 1: clone all components
clone_components

cd ${workspace_dir}
# step 2: configure operator repo
configure_rhosp_build

# COPY bundle image replacement.yaml
# generate bundle

# build images

# Build all images using `ko`
echo '::::::::::::::: after configuerre_rhosp_build'
echo $KO_DOCKER_REPO
read
echo ':::::::::::::::'

cd ${workspace_dir}
build_rhosp_images

divider
echo "generate bundle"
cd ${workspace_dir}
create_rhosp_bundle
pwd
# divider

cd ${workspace_dir}
add_operator_to_oncluster_operatorhub



