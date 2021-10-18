#!/usr/bin/env bash
set -eu

\cp -f steps/8_blue_green_deploy/clock_broken.go apps/clock/main.go
echo "В приложение clock добавлен возврат кода 500 с вероятностью 30%"
