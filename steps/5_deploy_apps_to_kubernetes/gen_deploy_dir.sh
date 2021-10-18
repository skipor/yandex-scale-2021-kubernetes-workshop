#!/usr/bin/env bash
set -eu
rm -rf ./deploy
cp -a steps/5_deploy_apps_to_kubernetes/deploy .
REGISTRY=$(yc container registry get workshop --format json | jq .id -r)
# Поменяем местозаполнитель 'REGISTRY' идентификатором нашего Container Registry
# NOTE: perl, т.к. inplace замена через sed немного разная на macOS и Linux
grep -rl REGISTRY ./deploy | xargs perl -pe "s/REGISTRY/${REGISTRY}/g" -i
tree ./deploy
