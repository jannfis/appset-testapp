#!/bin/sh
# Measures the time until all Applications are synced to a given revision

REVISION="$1"
if test "$REVISION" = ""; then
        echo "USAGE: $0 <revision_to_watch_for>"
        exit 1
fi

num_apps=$(oc get apps --no-headers | wc -l)
start_time=$(date)
echo "Starting at $start_time"
echo "Total apps: $num_apps"
while :; do
        now=$(date)
        synced_apps=$(oc get apps --no-headers -o wide | grep "$REVISION" | grep Synced | wc -l)
        echo "$now: Apps to sync: $((num_apps - synced_apps))"
        if test $((num_apps - synced_apps)) -eq 0; then
                break
        fi
        sleep 5
done
end_time=$(date)
echo "Test started at $start_time"
echo "Test ended at $end_time"
echo "Synced $num_apps apps across all clusters"

