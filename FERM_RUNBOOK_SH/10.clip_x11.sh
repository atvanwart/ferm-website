#!/usr/bin/env bash
set -euo pipefail
cd /home/pendor/Adam_Van_Wart/fermentors/ferm-website
git diff | ./tools/clip_x11.sh
