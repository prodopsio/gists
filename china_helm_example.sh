#!/bin/bash

# Setting a defaults
ECR_REG=${ECR_REG:-000.dkr.ecr.cn-northwest-1.amazonaws.com.cn}
CHINA=${CHINA:-false}


# Changing registries to Chinese accessible mirrors
#
set_china_environment() {  
  REGISTRY="000.dkr.ecr.cn-northwest-1.amazonaws.com.cn"
  QUAY="quay.azk8s.cn"
  GCR="gcr.azk8s.cn"
  K8SGCR="registry.aliyuncs.com/google_containers"
  DOCKERHUB="dockerhub.azk8s.cn"
}


# Switching China options on with an environment variable
#
running_from_china() {    
  if [[ ${CHINA} == "true" ]]; then        
    return 0    
  else        
    return 1    
  fi
}


# Using HELM to install and set registries dynamically
#
helm_install_my_application() {
  helm install --upgrade \
    --set global.repository="${REGISTRY}" \
    --set prometheus-operator.prometheus.prometheusSpec.image.repository="${QUAY}/prometheus/prometheus" \
    my_application .
    
    
# Main function
#
run() {
  running_from_china && set_china_environment
  helm_install_my_application
}


run
