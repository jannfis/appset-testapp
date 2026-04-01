# ArgoCD Agent Scale Test

Scale test for ACM GitOps Addon with ArgoCD Agent (Principal/Agent) mode. Creates 65 ApplicationSets on the hub, each deploying 1 Application per managed cluster. Each Application deploys 100 ConfigMaps.

## Prerequisites

- ACM Hub OpenShift cluster with N ManagedClusters registered
- OpenShift GitOps Operator installed on the **hub cluster**
- OpenShift GitOps Operator **NOT** installed on managed clusters (the GitOps Addon installs it automatically)

Verify managed clusters are registered:

```bash
oc get managedcluster
```

## Setup

All commands run against the hub cluster.

```bash
export KUBECONFIG=/tmp/hub
```

### Step 1: Bind the global ManagedClusterSet

```bash
kubectl apply -f acmhub/01-managedclustersetbinding.yaml
```

### Step 2: Configure hub ArgoCD as principal

The hub ArgoCD CR is managed by the GitOps operator. Use `kubectl patch` to merge in the principal configuration without overwriting existing fields.

```bash
kubectl patch argocd openshift-gitops -n openshift-gitops --type=merge -p '{
  "spec": {
    "controller": {"enabled": false},
    "sourceNamespaces": ["*"],
    "server": {"route": {"enabled": true}},
    "argoCDAgent": {
      "principal": {
        "enabled": true,
        "destinationBasedMapping": true,
        "auth": "mtls:CN=system:open-cluster-management:cluster:([^:]+):addon:gitops-addon:agent:gitops-addon-agent",
        "namespace": {"allowedNamespaces": ["*"]}
      }
    }
  }
}'
```

### Step 3: Create the Placement for the GitOpsCluster

```bash
kubectl apply -f acmhub/03-placement-gitopscluster.yaml
```

### Step 4: Create the GitOpsCluster

```bash
kubectl apply -f acmhub/04-gitopscluster.yaml
```

### Step 5: Create the Placement for ApplicationSets

```bash
kubectl apply -f acmhub/05-placement-appset.yaml
```

### Step 6: Patch the Policy with RBAC

The Policy is created by the GitOpsCluster controller after Step 4. This script waits for it to appear, then patches it.

```bash
bash acmhub/06-rbac-policy-patch.sh
```

### Step 7: Verify agents are connected

On a fresh setup, this can take 5-10 minutes while the GitOps Addon installs the OpenShift GitOps Operator on each managed cluster, deploys ArgoCD in agent mode, and connects agents to the hub principal.

```bash
watch kubectl get gitopscluster scale-test-gitops -n openshift-gitops -o jsonpath='{.status.phase}'
```

Wait until the phase is `successful`, then verify the AppSet Placement has cluster decisions:

```bash
kubectl get placementdecision -n openshift-gitops \
  -l cluster.open-cluster-management.io/placement=scale-test-appset-placement \
  -o jsonpath='{range .items[*].status.decisions[*]}{.clusterName}{"\n"}{end}'
```

### Step 8: Patch the Policy with controller tuning (optional)

After agents are connected and stable, add `ARGOCD_K8S_CLIENT_QPS` and `ARGOCD_K8S_CLIENT_BURST` env vars to the managed cluster ArgoCD application controller for higher API throughput:

```bash
kubectl get policy scale-test-gitops-argocd-policy -n openshift-gitops -o json | \
  jq '.spec["policy-templates"][0].objectDefinition.spec["object-templates"][0].objectDefinition.spec.controller = {"env": [{"name": "ARGOCD_K8S_CLIENT_QPS", "value": "150"}, {"name": "ARGOCD_K8S_CLIENT_BURST", "value": "300"}]}' | \
  kubectl apply -f -
```

## Verify with 1 Cluster

Before running the full scale test, verify the setup works end-to-end with a single cluster and a single ApplicationSet.

Create one ApplicationSet targeting 1 cluster:

```bash
kubectl patch placement scale-test-appset-placement -n openshift-gitops --type=merge -p '{"spec":{"numberOfClusters":1}}'
```

```bash
sed 's/APPSET_NUM/01/g' appset-template.yaml | kubectl apply -f -
```

Verify the Application was generated:

```bash
kubectl get applications.argoproj.io -n openshift-gitops
```

Wait for the Application to sync (can take 2-5 minutes on a fresh setup):

```bash
watch kubectl get applications.argoproj.io -n openshift-gitops -o wide
```

On the managed cluster, verify the ConfigMaps were deployed:

```bash
KUBECONFIG=/tmp/<managed-cluster> kubectl get configmap -n test-appset-01
```

Clean up the single-cluster test before proceeding:

```bash
kubectl delete applicationset test-appset-01 -n openshift-gitops
```

Wait for the generated Application to be deleted:

```bash
kubectl get applications.argoproj.io -n openshift-gitops
```

## Run

`<max_clusters>` controls how many managed clusters to target. The script patches the AppSet Placement's `numberOfClusters` field to this value, then creates 65 ApplicationSets. Each AppSet deploys 1 Application per targeted cluster, so the total number of Applications is `65 × <max_clusters>`.

```bash
export KUBECONFIG=/tmp/hub

./run-test.sh <max_clusters> 2>&1 | tee /tmp/scale-test.log
```

In another terminal, follow the output:

```bash
tail -f /tmp/scale-test.log
```
