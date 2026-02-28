JSONNET=jsonnet
JSONNET_FLAGS=-J vendor -S
MAIN=main.jsonnet
OUT=mixins-bundle.yaml

define render
	$(JSONNET) $(JSONNET_FLAGS) \
	-e 'std.manifestYamlStream($(1))' \
	> $(OUT)
	@echo "Generated $(OUT)"
endef

.PHONY: all clean kubernetes node alloy cert-manager cilium go-runtime grafana loki prometheus argocd coredns

all: kubernetes node alloy cert-manager cilium go-runtime grafana loki prometheus argocd coredns
	$(call render,(import "$(MAIN)").all)

clean:
	rm -f $(OUT)
	rm -rf jsonnetfile.json jsonnetfile.lock.json vendor

kubernetes: vendor/kubernetes-mixin
	$(call render,(import "$(MAIN)").components.kubernetes)

node: vendor/node-mixin
	$(call render,(import "$(MAIN)").components.node)

alloy: vendor/alloy-mixin
	$(call render,(import "$(MAIN)").components.alloy)

cert-manager: vendor/cert-manager-mixin
	$(call render,(import "$(MAIN)").components.certManager)

cilium: vendor/cilium-mixin
	$(call render,(import "$(MAIN)").components.cilium)

go-runtime: vendor/go-runtime-mixin
	$(call render,(import "$(MAIN)").components.goRuntime)

grafana: vendor/grafana-mixin
	$(call render,(import "$(MAIN)").components.grafana)

loki: vendor/loki-mixin
	$(call render,(import "$(MAIN)").components.loki)

prometheus: vendor/prometheus-mixin
	$(call render,(import "$(MAIN)").components.prometheus)

argocd: vendor/argocd-mixin
	$(call render,(import "$(MAIN)").components.argocd)

coredns: vendor/coredns-mixin
	$(call render,(import "$(MAIN)").components.coredns)

vendor/kubernetes-mixin:
	jb install https://github.com/kubernetes-monitoring/kubernetes-mixin

vendor/alloy-mixin:
	jb install https://github.com/grafana/alloy/operations/alloy-mixin@main

vendor/node-mixin:
	jb install https://github.com/prometheus/node_exporter/docs/node-mixin

vendor/cert-manager-mixin:
	jb install https://github.com/imusmanmalik/cert-manager-mixin@main

vendor/cilium-mixin:
	jb install https://github.com/grafana/jsonnet-libs/cilium-enterprise-mixin

vendor/go-runtime-mixin:
	jb install https://github.com/grafana/jsonnet-libs/go-runtime-mixin

vendor/grafana-mixin:
	jb install https://github.com/grafana/grafana/grafana-mixin@main

vendor/loki-mixin:
	jb install https://github.com/grafana/loki/production/loki-mixin@main

vendor/prometheus-mixin:
	jb install https://github.com/prometheus/prometheus/documentation/prometheus-mixin@main

vendor/argocd-mixin:
	jb install https://github.com/grafana/jsonnet-libs/argocd-mixin

vendor/coredns-mixin:
	jb install https://github.com/povilasv/coredns-mixin
