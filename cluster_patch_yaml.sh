#!/usr/bin/env bash
#set -x 

echo "
meta:
  resourceVersion: ${2}
" > /tmp/sample.yaml

#shellcheck disable=SC2016
yq ea '. as $item ireduce ({}; . * $item )' "$1"  /tmp/sample.yaml > "${3}"