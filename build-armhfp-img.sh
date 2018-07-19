#!/bin/bash
ks="$1"

if [ -z "$1" ] ;then
  echo $0 path/to/file.ks
  exit 1
fi

img=$(echo $ks|rev|cut -f 1 -d "/"|rev|sed s/\.ks//g)

time appliance-creator --config=${ks} --name="$img" --version="7" --debug --no-compress

