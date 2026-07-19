local mixins = import 'mixin.libsonnet';

local components = {
  kubernetes: {
    prefix: 'kubernetes',
    folder: 'Kubernetes',
    mixin: mixins.kubernetes,
    // k3s bundles the scheduler, controller-manager, and kube-proxy into a single
    // binary with no separate scrape targets for them, so these absent() alerts
    // would always fire — they're not selector-fixable (no correct job label
    // exists) like cert-manager's was, so drop them outright.
    excludeGroups: [
      'kubernetes-system-scheduler',
      'kubernetes-system-controller-manager',
      'kubernetes-system-kube-proxy',
    ],
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
    excludeRules: ['PrometheusNotConnectedToAlertmanagers'],
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


local datasourceUid = 'prometheus-main';

local k8sName(name) =
  std.asciiLower(
    std.strReplace(std.strReplace(std.strReplace(name, '_', '-'), '.', '-'), ' ', '-')
  );

local mergedGroups(cfg) =
  local excludeGroups = std.get(cfg, 'excludeGroups', []);
  local excludeRules = std.get(cfg, 'excludeRules', []);
  local alertGroups = std.get(std.get(cfg.mixin, 'prometheusAlerts', {}), 'groups', []);
  local recordGroups = std.get(std.get(cfg.mixin, 'prometheusRules', {}), 'groups', []);
  local allGroups = std.filter(
    function(g) !std.member(excludeGroups, g.name),
    alertGroups + recordGroups
  );
  local names = std.set(std.map(function(g) g.name, allGroups));
  std.map(
    function(name)
      {
        name: name,
        interval: std.get(
          std.filter(function(g) g.name == name, allGroups)[0], 'interval', null
        ),
        rules: std.flattenArrays(
          std.map(
            function(g)
              std.filter(
                function(r)
                  local ruleName = if std.objectHas(r, 'alert') then r.alert else r.record;
                  !std.member(excludeRules, ruleName),
                g.rules
              ),
            std.filter(function(g) g.name == name, allGroups)
          )
        ),
      },
    names
  );

// Reproduces Grafana's own `/api/convert/prometheus/config/v1/rules` translation
// (verified by converting real mixin rules through that endpoint and inspecting the
// exported result), so it can run as a pure, offline jsonnet render instead of a live
// API round-trip.
local convertRule(cfg, groupName, rule) =
  local ruleName = if std.objectHas(rule, 'alert') then rule.alert else rule.record;
  local uid = std.md5(cfg.prefix + '/' + groupName + '/' + ruleName);
  local promQuery = {
    refId: 'query',
    queryType: 'prometheus',
    relativeTimeRange: { from: 660, to: 60 },
    datasourceUid: datasourceUid,
    model: {
      datasource: { type: 'prometheus', uid: datasourceUid },
      expr: rule.expr,
      instant: true,
      intervalMs: 1000,
      maxDataPoints: 43200,
      range: false,
      refId: 'query',
    },
  };
  if std.objectHas(rule, 'alert') then
    {
      uid: uid,
      title: rule.alert,
      condition: 'threshold',
      data: [
        promQuery,
        {
          refId: 'prometheus_math',
          queryType: 'math',
          relativeTimeRange: { from: 0, to: 0 },
          datasourceUid: '__expr__',
          model: {
            expression: 'is_number($query) || is_nan($query) || is_inf($query)',
            intervalMs: 1000,
            maxDataPoints: 43200,
            refId: 'prometheus_math',
            type: 'math',
          },
        },
        {
          refId: 'threshold',
          queryType: 'threshold',
          relativeTimeRange: { from: 0, to: 0 },
          datasourceUid: '__expr__',
          model: {
            conditions: [{ evaluator: { params: [0], type: 'gt' } }],
            expression: 'prometheus_math',
            intervalMs: 1000,
            maxDataPoints: 43200,
            refId: 'threshold',
            type: 'threshold',
          },
        },
      ],
      noDataState: 'OK',
      execErrState: 'OK',
      'for': std.get(rule, 'for', '0s'),
      labels: std.get(rule, 'labels', {}) + { __converted_prometheus_rule__: 'true' },
      annotations: std.get(rule, 'annotations', {}),
    }
  else
    {
      uid: uid,
      title: rule.record,
      // condition/noDataState/execErrState/for are required by the CRD schema but
      // unused by Grafana for recording rules; placeholders satisfy validation.
      condition: 'query',
      noDataState: 'OK',
      execErrState: 'OK',
      'for': '0s',
      data: [promQuery],
      // targetDatasourceUid isn't in the installed GrafanaAlertRuleGroup CRD version;
      // Grafana falls back to grafana.ini [recording_rules] default_datasource_uid.
      record: { metric: rule.record, from: 'query' },
      labels: { __converted_prometheus_rule__: 'true' },
    };

// The sole owner of cfg.folder's folder in Grafana — one per component, created
// fresh (no spec.uid: this repo's pre-existing same-titled folders are deleted as
// part of adopting this pipeline, precisely so there's no title collision and the
// operator creates each folder itself rather than ambiguously "adopting" one it
// didn't create — see https://grafana.github.io/grafana-operator/docs/examples/folder/).
// Both alertRuleGroupResources and dashboardResources reference it via folderRef;
// nothing in this pipeline hardcodes or fetches a Grafana folder UID.
local folderResource(cfg) =
  {
    apiVersion: 'grafana.integreatly.org/v1beta1',
    kind: 'GrafanaFolder',
    metadata: { name: k8sName(cfg.prefix + '-mixin-folder') },
    spec: {
      title: cfg.folder,
      instanceSelector: { matchLabels: { dashboards: 'grafana' } },
    },
  };

local alertRuleGroupResources(cfg) =
  local groups = mergedGroups(cfg);
  std.map(
    function(g)
      {
        apiVersion: 'grafana.integreatly.org/v1beta1',
        kind: 'GrafanaAlertRuleGroup',
        metadata: { name: k8sName(cfg.prefix + '-' + g.name + '-mixin-rules') },
        spec: {
          folderRef: k8sName(cfg.prefix + '-mixin-folder'),
          interval:
            if g.interval == null then '1m'
            else if std.isNumber(g.interval) then '%ds' % g.interval
            else g.interval,
          instanceSelector: { matchLabels: { dashboards: 'grafana' } },
          rules: std.map(function(r) convertRule(cfg, g.name, r), g.rules),
        },
      },
    groups
  );


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
                folderRef: k8sName(cfg.prefix + '-mixin-folder'),
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
      [folderResource(cfg)]
      +
      alertRuleGroupResources(cfg)
      +
      dashboardResources(cfg),
    components
  ),

  all:
    std.flattenArrays(
      std.map(
        function(name)
          [folderResource(components[name])]
          +
          alertRuleGroupResources(components[name])
          +
          dashboardResources(components[name]),
        std.objectFields(components)
      )
    ),
}
