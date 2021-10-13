#/usr/bin/env bash

set +xe

source ./utils.sh

namespace=$1
if [[ -z ${namespace} ]]; then
  namespace=$(oc project --short)
fi

set_up_sa_for_taskruns ${namespace}
