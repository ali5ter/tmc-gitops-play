#!/bin/sh -l

export TMC_API_TOKEN="$1"
echo "» TMC Login with TMC_API_TOKEN"
tmc login --stg-unstable --no-configure --name tmc-unstable

echo "» Move to /github/workspace"
cd /github/workspace || exit

echo "» Fix git permissions"
git config --global --add safe.directory /github/workspace

echo "» Start TMC Apply -------------------------------------------------------------"
/usr/src/app/apply.sh 
echo "» End TMC Apply ---------------------------------------------------------------"