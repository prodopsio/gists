#!/bin/sh

CONFIGMAP_NAME="coredns"
CONFIGMAP_KEY="Corefile"

do_something_with_data() {
    echo "This is the $CONFIGMAP_KEY from the $CONFIGMAP_NAME configmap:"
    cat
}

operator_read_configmap() {
  kubectl get configmap "$CONFIGMAP_NAME" -o jsonpath --template "{ .data.$CONFIGMAP_KEY }"
}

operator() {
  operator_read_configmap \
      | do_something_with_data
}

# generate a line of output each time configmap is changed/created/etc...
while true; do
  kubectl get configmap "$CONFIGMAP_NAME" -w -o jsonpath --template '{ .metadata.name }{"\n"}'
  echo "Kubectl stopped with rc $?, restarting: 'kubectl get -w configmap $CONFIGMAP_NAME'" 1>&2
  sleep 1
done | operator
