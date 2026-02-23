#!/bin/bash

# generates https://monitoring.mixins.dev/kubernetes/ dashboards
rm -rf vendor jsonnetfile.json jsonnetfile.lock.json
jb init
jb install https://github.com/kubernetes-monitoring/kubernetes-mixin
jsonnet -J vendor -m mixins/kubernetes -e '(import "mixin.libsonnet").grafanaDashboards'
rm -rf vendor jsonnetfile.json jsonnetfile.lock.json
