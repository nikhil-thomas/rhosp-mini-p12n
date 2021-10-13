#!/usr/bin/env bash


set +xe
source ./utils.sh

# STEP 0: Set up a workspace dir in /tmp
rm -rf /tmp/rhosp*
workspace_dir=$(mktemp -d /tmp/rhosp-$(date +%y-%m-%d)-XXXXX)
cp ${BUNDLE_GENERATION_CONFIG} ${workspace_dir}/config.yaml

echo workspace_dir=$(pwd)

# STEP 1: Configure OpenShift internal image registry
setup_openshift_registry

# STEP 3: Clone operator, pipeline and triggers code repositories (from github.com/openshift org)
clone_components


# STEP 4: Update pipelies, triggers release.yaml and addons (clusterTasks, clustertriggerbinding ...)
configure_rhosp_build

# STEP 5: Build all images from operator, pipeline and triggers
build_rhosp_images

# STEP 6: Generate RHOSP Bundle
create_rhosp_bundle

# STEP 7: Create an index image and create a custom catalog source on OpenShift cluster
add_operator_to_oncluster_operatorhub

# STEP 8: Configure necessary privilleges for operator, pipelines and triggers serviceaccounts
#         so that they can pull the image(streams) from namespaces like rhosp-operator-images, rhosp-pipeline-images ...
configure_image_pull_privileges

# STEP 9: Add necessary privilleges to `pipeline` serviceaccount in default namespace
set_up_default_and_current_project

# STEP 10: run/test pipelineRuns, TaskRuns...
