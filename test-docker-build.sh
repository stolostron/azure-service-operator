#!/bin/bash
set -e
export GOROOT=/home/rcap/go/
export PATH=$GOROOT/bin:$PATH
export GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}"

( cd v2/cmd/asoctl && go mod download && go mod tidy )
( cd v2/tools/generator && go mod download && go mod tidy )
( cd v2/tools/mangle-test-json/ && go mod download && go mod tidy )

trap 'cd / && rm -rf /tmp/aso-build' EXIT
git clone --single-branch -b $(git branch --show-current) . /tmp/aso-build
cd /tmp/aso-build
git submodule init
(cd v2/specs/azure-rest-api-specs; git remote add mara git@github.com:marek-veber/azure-rest-api-specs.git )
git submodule  update
container_id=$(docker ps -q --filter name=aso-devcontainer)
if [ -n "$container_id" ] ; then
    if [ "$1" != "--reuse-devcontainer" ] ; then
        docker stop "$container_id"
        docker rm "$container_id"
        container_id=""
    fi
fi
if [ -z "$container_id" ] ; then
    docker build --cache-from docker.pkg.github.com/azure/azure-service-operator/aso-devcontainer:latest --tag devcontainer:latest -f .devcontainer/Dockerfile .
    container_id=$(docker create \
                    --name aso-devcontainer -w /workspace \
                    -v $PWD:/workspace -v /var/run/docker.sock:/var/run/docker.sock \
                    --user "$(id -u):$(id -g)" \
                    --group-add "$(stat -c '%g' /var/run/docker.sock)" \
                    -e HOME=/tmp -e GOPATH=/tmp/go -e GOCACHE=/tmp/go-cache \
                    --network=host devcontainer:latest)
    docker start "$container_id"
fi
docker exec "$container_id" task controller:docker-build-and-save
