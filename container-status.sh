#!/bin/bash

D_APP_NAME=$1

D_APP_STATUS="docker inspect --format \"{{index .State.Health.Status}}\" ${D_APP_NAME}"

eval ${D_APP_STATUS}
while [ "$(eval ${D_APP_STATUS})" == "starting" ]; do
    printf "."
    sleep 3
done
eval ${D_APP_STATUS}
