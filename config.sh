components=(pipeline triggers operator)

operator_branch=release-next
pipeline_branch=release-next
triggers_branch=release-next

registry_namespace=rhosp-images
pipeline_imagestreams_namespace=rhosp-pipeline-images
triggers_imagestreams_namespace=rhosp-triggers-images
operator_imagestreams_namespace=rhosp-operator-images

PIPELINE_VERSION=${PIPELINE_VERSION:-nightly}
TRIGGERS_VERSION=${TRIGGERS_VERSION:-nightly}
CATALOG_RELEASE_BRANCH=${CATALOG_RELEASE_BRANCH:-release-next}
# RHOSP (Red Hat OpenShift Pipelines)
# RHOSP_VERSION=${RHOSP_VERSION:-$(date  +"%Y.%-m.%-d")-nightly}
RHOSP_VERSION=${RHOSP_VERSION:-1.6.0} # we need to keep this constant for now as, we cannot push generated csv on a daily basis (NT)
RHOSP_PREVIOUS_VERSION=${RHOSP_PREVIOUS_VERSION:-1.5.2}
OLM_SKIP_RANGE=${OLM_SKIP_RANGE:-\'>=1.5.0 <1.6.0\'}

BUNDLE_GENERATION_CONFIG=image_replacement_override.yaml
