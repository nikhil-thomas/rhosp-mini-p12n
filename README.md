# How to install the operator using this script


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
