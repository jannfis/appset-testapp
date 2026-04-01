#!/bin/sh

CONTEXT="$1"
NAMESPACE="$2"

if test "$CONTEXT" = "" -o "$NAMESPACE" = ""; then
        echo "USAGE: $0 <context> <namespace>" >&2
        echo >&2
        echo "<context> must be the name of the kubectl context of the control plane cluster" >&2
        echo "<namespace> is the installation namespace on the control plane cluster" >&2
        exit 1
fi

kubectl --context ${CONTEXT} --namespace ${NAMESPACE} apply -f appset.yaml
sleep 10
./measure-time.sh ${CONTEXT} ${NAMESPACE}
