local kubernetes =
  (import 'kubernetes-mixin/mixin.libsonnet') {
    _config+:: {
      cadvisorSelector: 'job="integrations/kubernetes/cadvisor"',
      kubeletSelector: 'job="integrations/kubernetes/kubelet"',
      kubeStateMetricsSelector: 'job="integrations/kubernetes/kube-state-metrics"',
      nodeExporterSelector: 'job="integrations/node_exporter"',
      kubeSchedulerSelector: 'job="kube-scheduler"',
      kubeControllerManagerSelector: 'job="kube-controller-manager"',
      kubeApiserverSelector: 'job="integrations/kubernetes/kube-apiserver"',
      kubeProxySelector: 'job="integrations/kubernetes/kube-proxy"',
      podLabel: 'pod',
      hostNetworkInterfaceSelector: 'device!~"veth.+"',
      hostMountpointSelector: 'mountpoint="/"',
      windowsExporterSelector: 'job="integrations/windows_exporter"',
      containerfsSelector: 'container!=""',

      grafanaK8s+:: {
        dashboardNamePrefix: '',
        dashboardTags: ['kubernetes', 'infrastructure'],
      },
    },
  };

local node =
  (import 'node-mixin/mixin.libsonnet') {
    _config+:: {
      nodeExporterSelector: 'job="integrations/node_exporter"',
    },
  };

local alloy = (import 'alloy-mixin/mixin.libsonnet');
local certManager = (import 'cert-manager-mixin/mixin.libsonnet');
local cilium = (import 'cilium-enterprise-mixin/mixin.libsonnet');
local goRuntime = (import 'go-runtime-mixin/mixin.libsonnet');
local grafana = (import 'grafana-mixin/mixin.libsonnet');
local loki = (import 'loki-mixin/mixin.libsonnet');

local prometheus = (import 'prometheus-mixin/mixin.libsonnet') {
  _config+:: {
    prometheusSelector: 'job="kube-prometheus-stack-prometheus"',
  },
};

local argocd = (import 'argocd-mixin/mixin.libsonnet');
local coredns = (import 'coredns-mixin/mixin.libsonnet');


{
  kubernetes: kubernetes,
  node: node,
  alloy: alloy,
  certManager: certManager,
  cilium: cilium,
  goRuntime: goRuntime,
  grafana: grafana,
  loki: loki,
  prometheus: prometheus,
  argocd: argocd,
  coredns: coredns,
}
