#!/bin/bash
set -e
export GOROOT=/home/mveber/go1.25.4
export PATH=$GOROOT/bin:$PATH

( cd v2/cmd/asoctl && go mod download && go mod tidy )
( cd v2/tools/generator && go mod download && go mod tidy )

export DOCKER_REGISTRY=quay.io
export DOCKER_PUSH_TARGET=quay.io/mveber
export VERSION="v2.13.0-hcpclusters.9"


CONTROLLER_DOCKER_IMAGE="azure-service-operator-rhel9:{{.VERSION}}"
yq eval '
  .vars.VERSION = "'"${VERSION}"'" |
  .vars.CONTROLLER_DOCKER_IMAGE = "'"${CONTROLLER_DOCKER_IMAGE}"'" |
  del(.tasks."controller:docker-push-multiarch".deps[1])
' Taskfile.yml > Taskfile-multiarch.yml

task --taskfile Taskfile-multiarch.yml controller:docker-push-multiarch  --verbose --force


git tag  --delete "$VERSION"            || true; git tag "$VERSION"
git push --delete stolostron "$VERSION" || true; git push stolostron "$VERSION"
