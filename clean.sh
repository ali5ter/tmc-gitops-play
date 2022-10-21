#!/usr/bin/env bash
#set -x 
tmc cluster namespace delete alb-gitops-dev --cluster-name alb-gitops-dev-one -m eks -p eks
tmc workspace delete alb-gitops-kuard-dev
tmc cluster delete alb-gitops-dev-one -m eks -p eks