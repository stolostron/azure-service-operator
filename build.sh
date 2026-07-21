#!/bin/bash
set -e
#export GOROOT=/home/mveber/go1.26.2
#export PATH=$GOROOT/bin:$PATH

( cd v2/cmd/asoctl && go mod download && go mod tidy )
( cd v2/tools/generator && go mod download && go mod tidy )

DST_VER=v2.13.0-hcpclusters.5.0-rcap-dev
git tag --delete $DST_VER || true
git tag $DST_VER
#task controller:docker-build --force
echo "----------------  controller:docker-build done, pushing -> quay.io/capz/azureserviceoperator:${DST_VER}"

BUILDED_VER=$(./scripts/v2/build_version.py v2)
docker tag azureserviceoperator:${BUILDED_VER} quay.io/capz/azure-service-operator-rhel9:${DST_VER}
docker push quay.io/capz/azure-service-operator-rhel9:${DST_VER}


