# Red Hat OpenShift Pipelines (RHOSP) Mini-Productization (p12n)

Quick Install RHOSP on OpenShift 4.x

## How to install the operator using this script


1. create an OpenShift Cluster
2. token login to the OpenShift Cluster
   ```bash
    oc login --token=<token>--server=<openshift cluster url>
    ```
3. install ko https://github.com/google/ko#install-from-releases
4. install opm https://github.com/operator-framework/operator-registry/releases
5. install kustomize https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/
6. then run
   ```bash
   ./install-rhosp-release-next.sh
   ```
   
   This will create a custom CatalogSource and the operator will show up in OperatorHub on the OpenShift Cluster.
7. Then install the operator from OperatorHub (make sure the source=rhosp-catalog is checked under available filters)

**Note:** After running the script, it will take 2 - 5 minutes for OperatorHub on the cluster to refresh
and show this new operator listing.

**Note:** This script will disable all other operator on the OperatorHub

## For each new Namespace/Project...

if we switch to a new/different project/namespace while testing.
Run
```bash
   ./rhospify-my-namespace.sh <namespace-name>
```
before running pipelineruns, taskruns in that namespace.

## FAQ

### OperatorHub view is empty

1. wait for 2 - 3 mins and refresh the screen
2. if step 1 did not resolve the issue:
   1. then check if there is a `rhosp-catalog-xxxx` pod in `openshift-marketplace` namespace.
   2. if the pod is up and running, go to step 1
   3. else kill the pod, wait till the pod to be recreated automatically and `status=running`, then goto step 1
   4. if the pod is not reaching `status: running` find the error from pod definition/details, and reach out to tektonpipeline-dev

### TaskRuns, Pipelineruns are in pendingstate

1. is you project/namepace different from `default`
2. then run `./rhospify-my-namespace.sh <namespace-name>`

