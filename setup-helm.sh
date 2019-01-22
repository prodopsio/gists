#!/bin/sh

HELM_TILLER_SA=tiller
HELM_TILLER_NS=kube-system

tiller_tls() {
    [ ! -f tiller-ca.crt ] && \
        openssl req -x509 -new -newkey rsa:2048 -keyout tiller-ca.key -nodes -sha256 -days 3650 -out tiller-ca.crt -subj "/CN=tiller-ca"
    [ ! -f tiller.crt ] && {
      echo subjectAltName=IP:127.0.0.1 > extfile.cnf
      openssl req -new -newkey rsa:2048 -keyout tiller.key -nodes -sha256 -days 3650 -out tiller.csr -subj "/CN=tiller-server"
      openssl x509 -req -sha256 -CA tiller-ca.crt -CAkey tiller-ca.key -CAcreateserial -in tiller.csr -days 3650 -out tiller.crt -extfile extfile.cnf
    }
}

helm_tls() {
    [ ! -f helm.crt ] && {
      [ ! -f helm.key ] && openssl genrsa -out helm.key 2048
      openssl req -new -newkey rsa:2048 -keyout helm.key -nodes -sha256 -days 3650 -out helm.csr -subj "/CN=helm-client"
      openssl x509 -req -sha256 -CA tiller-ca.crt -CAkey tiller-ca.key -CAcreateserial -in helm.csr -days 3650 -out helm.crt
    }
}

tiller_init() {
    helm version -s \
        --tiller-connection-timeout 1 \
        >/dev/null 2>&1 \
    && return

    cat <<-EOF | kubectl apply -f -
	---
	apiVersion: v1
	kind: ServiceAccount
	metadata:
	  name: $HELM_TILLER_SA
	  namespace: $HELM_TILLER_NS
	---
	apiVersion: rbac.authorization.k8s.io/v1
	kind: ClusterRoleBinding
	metadata:
	  name: $HELM_TILLER_SA
	roleRef:
	  apiGroup: rbac.authorization.k8s.io
	  kind: ClusterRole
	  name: cluster-admin
	subjects:
	- kind: ServiceAccount
	  name: $HELM_TILLER_SA
	  namespace: $HELM_TILLER_NS
	EOF
    helm init \
      --upgrade \
      --wait \
      --service-account $HELM_TILLER_SA \
      --tiller-namespace $HELM_TILLER_NS \
      --tiller-tls \
      --tiller-tls-cert=tiller.crt \
      --tiller-tls-key=tiller.key \
      --tiller-tls-verify \
      --tls-ca-cert=tiller-ca.crt
}

helm() {
  command helm \
      --tiller-namespace $HELM_TILLER_NS \
      --tls \
      --tls-verify \
      --tls-key helm.key \
      --tls-cert helm.crt \
      --tls-ca-cert tiller-ca.crt \
      "$@"
}

tiller_tls
helm_tls
tiller_init

helm version
