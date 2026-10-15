# IBM ODM Dev — OpenShift GitOps RBAC

The CodeBuild bootstrap now creates/updates namespace `ibm-odm` with label `argocd.argoproj.io/managed-by: openshift-gitops`, then applies `rbac/argocd-rolebinding.yaml` before creating ExternalSecrets and the Argo CD Application.

The RoleBinding binds the `openshift-gitops-argocd-application-controller` service account to the built-in `admin` ClusterRole **only within** `ibm-odm`. This does not grant cluster-admin or permission to create cluster-scoped resources. Verify that the controller service account name matches your OpenShift GitOps installation and that the chart does not require cluster-scoped objects. Some OpenShift GitOps installations use operator-managed namespace RBAC; inspect any existing bindings to avoid duplicate privileges.

Prerequisites: the CodeBuild OpenShift identity must be authorized to label the namespace and create this RoleBinding. The GitOps operator must support namespace management via this label. Avoid enabling `clusterResourceWhitelist` without separately reviewing the chart and cluster-scoped permissions.

Manual checks after bootstrap:

```sh
oc get ns ibm-odm --show-labels
oc get rolebinding ibm-odm-argocd -n ibm-odm -o yaml
oc auth can-i create deployments.apps -n ibm-odm --as=system:serviceaccount:openshift-gitops:openshift-gitops-argocd-application-controller
oc get application ibm-odm -n openshift-gitops
```

The impersonation check needs permission to impersonate the service account. A `no` or forbidden result should be investigated rather than bypassed.
