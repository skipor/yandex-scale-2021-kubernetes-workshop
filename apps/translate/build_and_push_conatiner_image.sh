#!/usr/bin/env bash
set -eu

TAG="${1:?Pass image tag in first argument}"
REGISTRY=$(yc container registry get workshop --format json | jq .id -r)
IMAGE="cr.yandex/${REGISTRY}/translate:${TAG}"

cd "$(dirname "$0")"
docker build . -t "$IMAGE"
docker push "$IMAGE" > /dev/stderr

echo "$IMAGE"
