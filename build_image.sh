#!/bin/bash

DOCKERFILE_DIR="."
MULTIARCH_PLATFORMS="linux/amd64,linux/arm/v7,linux/arm64"

USER="kevinxw"
IMAGE="seafile-arm"
TAGS=""

OUTPUT=""
while getopts t:v:l:p flag
do
    case "${flag}" in
        t) TAGS="$TAGS -t $USER/$IMAGE:$OPTARG";;
        p) OUTPUT="--push";;
        l) OUTPUT="--load"; MULTIARCH_PLATFORMS="linux/$OPTARG";;
        :) exit;;
        \?) exit;; 
    esac
done

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $ROOT_DIR

# Enable use of docker buildx
export DOCKER_CLI_EXPERIMENTAL=enabled

# Register qemu handlers
docker run --rm --privileged docker/binfmt:a7996909642ee92942dcd6cff44b9b95f08dad64

# create multiarch builder if needed
BUILDER=multiarch_builder
if [ "$(docker buildx ls | grep $BUILDER)" == "" ]
then
    docker buildx create --name $BUILDER
fi

# Use the builder
docker buildx use $BUILDER

# Fix docker multiarch building when host local IP changes
BUILDER_CONTAINER="$(docker ps -qf name=$BUILDER)"
if [ ! -z "${BUILDER_CONTAINER}" ]; then
  echo 'Restarting builder container..'
  docker restart $(docker ps -qf name=$BUILDER)
  sleep 2
fi

# Build image
docker buildx build $OUTPUT --platform "$MULTIARCH_PLATFORMS" $TAGS "$DOCKERFILE_DIR"

export DOCKER_CLI_EXPERIMENTAL=disabled
