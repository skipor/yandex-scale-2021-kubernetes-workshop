#!/usr/bin/env bash

set -euo pipefail
\cp -af  steps/7_blue_green_balancing/clock/* deploy/clock
mv deploy/clock/{deployment,service}.yaml deploy/clock/base

cat <<'EOF'
- Текущие yaml выделены в базу 'deploy/clock/base'
- Определены кастомизации deploy/clock/{blue,green} с цветом в метке 'colour' и суффиксе имени
- deploy/clock/kustomization.yaml объединяет blue и green
EOF
tree deploy/clock
