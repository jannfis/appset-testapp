#!/bin/sh
set -eo pipefail

CONTEXT="$1"
NAMESPACE="$2"

if test "$CONTEXT" = "" -o "$NAMESPACE" = ""; then
	echo "USAGE: $0 <context> <namespace>" >&2
	echo >&2
	echo "<context> must be the name of the kubectl context of the control plane cluster" >&2
	echo "<namespace> is the installation namespace on the control plane cluster" >&2
	exit 1
fi

starttime=$(date)
numapps=$(kubectl --context ${CONTEXT} --namespace ${NAMESPACE} --no-headers=true get apps | { grep -v Synced || true; } | wc -l)
iter=1
echo "Starting test at $(date)"
while :; do
	remaining=$(kubectl --context ${CONTEXT} --namespace ${NAMESPACE} --no-headers=true get apps | { grep -v Synced || true; } | wc -l)
	err="$?"
	if test "$err" != "0"; then
		echo "FATAL: kubectl exit code $err, aborting" >&2
		exit 1
	fi
	if test "$remaining" -eq 0; then
		echo "All apps synced or no apps found. Remaining apps:"
		kubectl --context ${CONTEXT} --namespace ${NAMESPACE} --no-headers=true get apps
		break
	fi
	echo "Number of apps remaining to be synced: $remaining"
	if test $(($iter % 60)) -eq 0; then
		echo "Summary at $(date)"
		kubectl --context ${CONTEXT} --namespace ${NAMESPACE} --no-headers=true get apps | { grep OutOfSync || true; }
	fi
	iter=$((iter + 1))
	sleep 1
done
echo "Test started at $starttime"
echo "Test ended at $(date)"
echo "Synced $numapps apps"
