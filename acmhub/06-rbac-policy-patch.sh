#!/bin/bash
#
# Patches the GitOpsCluster-generated Policy to add cluster-admin RBAC
# for the ArgoCD application controller on managed clusters.
#
# Usage: ./06-rbac-policy-patch.sh
#
# The GitOpsCluster controller creates a Policy but does NOT include RBAC
# by default. This patch adds a ClusterRoleBinding granting cluster-admin
# to the ArgoCD application controller ServiceAccount.

set -euo pipefail

POLICY_NAME="scale-test-gitops-argocd-policy"
NAMESPACE="openshift-gitops"

echo "Waiting for policy ${POLICY_NAME} to be created..."
until kubectl get policy "${POLICY_NAME}" -n "${NAMESPACE}" &>/dev/null; do
    sleep 2
done
echo "Policy found. Patching..."

kubectl patch policy "${POLICY_NAME}" -n "${NAMESPACE}" --type=json -p='[
  {
    "op": "add",
    "path": "/spec/policy-templates/-",
    "value": {
      "objectDefinition": {
        "apiVersion": "policy.open-cluster-management.io/v1",
        "kind": "ConfigurationPolicy",
        "metadata": {
          "name": "scale-test-gitops-argocd-policy-rbac"
        },
        "spec": {
          "remediationAction": "enforce",
          "severity": "medium",
          "object-templates": [
            {
              "complianceType": "musthave",
              "objectDefinition": {
                "apiVersion": "rbac.authorization.k8s.io/v1",
                "kind": "ClusterRoleBinding",
                "metadata": {
                  "name": "acm-openshift-gitops-cluster-admin"
                },
                "roleRef": {
                  "apiGroup": "rbac.authorization.k8s.io",
                  "kind": "ClusterRole",
                  "name": "cluster-admin"
                },
                "subjects": [
                  {
                    "kind": "ServiceAccount",
                    "name": "acm-openshift-gitops-argocd-application-controller",
                    "namespace": "openshift-gitops"
                  }
                ]
              }
            }
          ]
        }
      }
    }
  }
]'

echo "Policy patched with RBAC successfully."
