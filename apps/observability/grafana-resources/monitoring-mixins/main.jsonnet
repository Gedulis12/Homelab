local mixins = import 'mixin.libsonnet';

local components = {
  kubernetes: {
    prefix: 'kubernetes',
    folder: 'Kubernetes',
    mixin: mixins.kubernetes,
  },
  node: {
    prefix: 'node',
    folder: 'Host and hardware',
    mixin: mixins.node,
  },
  alloy: {
    prefix: 'alloy',
    folder: 'Alloy',
    mixin: mixins.alloy,
  },
  certManager: {
    prefix: 'cert-manager',
    folder: 'Cert manager',
    mixin: mixins.certManager,
  },
  cilium: {
    prefix: 'cilium',
    folder: 'Cilium',
    mixin: mixins.cilium,
  },
  goRuntime: {
    prefix: 'go-runtime',
    folder: 'Go runtime',
    mixin: mixins.goRuntime,
  },
  grafana: {
    prefix: 'grafana',
    folder: 'Grafana',
    mixin: mixins.grafana,
  },
  loki: {
    prefix: 'loki',
    folder: 'Loki',
    mixin: mixins.loki,
  },
  prometheus: {
    prefix: 'prometheus',
    folder: 'Prometheus',
    mixin: mixins.prometheus,
  },
  argocd: {
    prefix: 'argocd',
    folder: 'Argocd',
    mixin: mixins.argocd,
  },
  coredns: {
    prefix: 'coredns',
    folder: 'Coredns',
    mixin: mixins.coredns,
  },
};


local k8sName(name) =
  std.asciiLower(
    std.strReplace(name, '_', '-')
  );

local ruleResources(cfg) =
  local rules = std.get(cfg.mixin, 'prometheusRules', null);
  if rules != null then
    [
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'PrometheusRule',
        metadata: {
          name: k8sName(cfg.prefix + '-mixin-rules'),
          labels: {
                release: 'kube-prometheus-stack'
            },
        },
        spec: cfg.mixin.prometheusRules,
      },
    ]
  else
    [];


local dashboardResources(cfg) =
  local dashboards = std.get(cfg.mixin, 'grafanaDashboards', null);
  if dashboards != null then
    std.flattenArrays(
      std.map(
        function(fileName)
          local baseName = std.strReplace(fileName, '.json', '');
          local cmName = cfg.prefix + '-mixins-' + baseName;
          [
            {
              apiVersion: 'v1',
              kind: 'ConfigMap',
              metadata: {
                name: k8sName(cmName),
                labels: { dashboards: 'grafana' },
              },
              data: {
                [fileName]:
                  std.manifestJsonEx(
                    cfg.mixin.grafanaDashboards[fileName],
                    '  '
                  ),
              },
            },
            {
              apiVersion: 'grafana.integreatly.org/v1beta1',
              kind: 'GrafanaDashboard',
              metadata: { name: k8sName(baseName) },
              spec: {
                folder: cfg.folder,
                instanceSelector: {
                  matchLabels: { dashboards: 'grafana' },
                },
                configMapRef: {
                  name: cmName,
                  key: fileName,
                },
              },
            },
          ],
        std.objectFields(cfg.mixin.grafanaDashboards)
      )
    )
  else
    [];

{
  components: std.mapWithKey(
    function(name, cfg)
      ruleResources(cfg)
      +
      dashboardResources(cfg),
    components
  ),

  all:
    std.flattenArrays(
      std.map(
        function(name)
          ruleResources(components[name])
          +
          dashboardResources(components[name]),
        std.objectFields(components)
      )
    ),
}
