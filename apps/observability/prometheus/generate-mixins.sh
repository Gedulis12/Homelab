#!/bin/bash

# generates https://monitoring.mixins.dev/kubernetes/ rules
rm -rf rules.yaml vendor jsonnetfile.json jsonnetfile.lock.json
cat <<EOF >rules.yaml
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kubernetes-mixin-rules
spec:
EOF
jb init
jb install https://github.com/kubernetes-monitoring/kubernetes-mixin
jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusRules)' | sed 's/^/  /' >> rules.yaml
rm -rf vendor jsonnetfile.json jsonnetfile.lock.json
