#!/bin/bash
set -eo pipefail

MAX_CLUSTERS="${1:-}"
NUM_APPSETS=65
NAMESPACE="openshift-gitops"
PLACEMENT="scale-test-appset-placement"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if test "$MAX_CLUSTERS" = ""; then
	echo "USAGE: $0 <max_clusters>" >&2
	echo >&2
	echo "<max_clusters> is the number of managed clusters to target" >&2
	exit 1
fi

kubectl patch placement "${PLACEMENT}" -n "${NAMESPACE}" --type=merge \
    -p "{\"spec\":{\"numberOfClusters\":${MAX_CLUSTERS}}}"
sleep 3

for i in $(seq 1 "${NUM_APPSETS}"); do
    APPSET_NUM=$(printf "%02d" "$i")
    sed "s/APPSET_NUM/${APPSET_NUM}/g" "${SCRIPT_DIR}/appset-template.yaml" | kubectl apply -f -
done
sleep 10

starttime=$(date)
numapps=$(kubectl --namespace ${NAMESPACE} --no-headers=true get apps | { grep -v Synced || true; } | wc -l)
iter=1
echo "Starting test at $(date)"
while :; do
	remaining=$(kubectl --namespace ${NAMESPACE} --no-headers=true get apps | { grep -v Synced || true; } | wc -l)
	err="$?"
	if test "$err" != "0"; then
		echo "FATAL: kubectl exit code $err, aborting" >&2
		exit 1
	fi
	if test "$remaining" -eq 0; then
		echo "All apps synced or no apps found. Remaining apps:"
		kubectl --namespace ${NAMESPACE} --no-headers=true get apps
		break
	fi
	echo "Number of apps remaining to be synced: $remaining"
	if test $(($iter % 60)) -eq 0; then
		echo "Summary at $(date)"
		kubectl --namespace ${NAMESPACE} --no-headers=true get apps | { grep OutOfSync || true; }
	fi
	iter=$((iter + 1))
	sleep 1
done
echo "Test started at $starttime"
echo "Test ended at $(date)"
echo "Synced $numapps apps"
