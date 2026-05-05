# Kube-Prometheus-Stack Helm Values Template
# Tuned for a single ARM A1.Flex demo node (2 OCPU / 12 GB RAM).
# All components run on arm64; images are multi-arch from upstream.

# ── Global ───────────────────────────────────────────────────────────────────────

fullnameOverride: ""
nameOverride: ""

commonLabels:
  app.kubernetes.io/managed-by: opentofu

# ARM64 node selector applied globally
# kube-prometheus-stack propagates this via global.nodeSelector
global:
  nodeSelector:
    kubernetes.io/arch: arm64

# ── Prometheus ───────────────────────────────────────────────────────────────────

prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: ${storage_class}
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: ${prometheus_storage_size}

    retention: ${prometheus_retention}
    retentionSize: ${prometheus_retention_size}

    # Demo-friendly resource budget
    resources:
      limits:
        cpu: 500m
        memory: 1Gi
      requests:
        cpu: 100m
        memory: 512Mi

    securityContext:
      runAsNonRoot: true
      runAsUser: 65534
      fsGroup: 65534

    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false

    enableAdminAPI: true

    web:
      pageTitle: "Prometheus - OKE ARM Demo"

# ── Grafana ───────────────────────────────────────────────────────────────────────

grafana:
  service:
    type: ${grafana_service_type}
    port: 80
    targetPort: 3000

  adminPassword: ${grafana_admin_password}

  persistence:
    enabled: ${grafana_persistence_enabled}
    type: pvc
    storageClassName: ${storage_class}
    accessModes:
      - ReadWriteOnce
    size: ${grafana_storage_size}
    finalizers:
      - kubernetes.io/pvc-protection

  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 128Mi

  securityContext:
    runAsNonRoot: true
    runAsUser: 472
    fsGroup: 472

  grafana.ini:
    server:
      domain: localhost
      root_url: http://localhost:3000/
    analytics:
      check_for_updates: false
    security:
      admin_user: admin
      admin_password: ${grafana_admin_password}
    users:
      allow_sign_up: false
      auto_assign_org: true
      auto_assign_org_role: Viewer
    auth.anonymous:
      enabled: false
    log:
      mode: console

  defaultDashboardsEnabled: true

  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard
      labelValue: "1"
      folder: /tmp/dashboards
      searchNamespace: ALL
    datasources:
      enabled: true
      defaultDatasourceEnabled: true
      label: grafana_datasource
      labelValue: "1"

# ── Alertmanager ─────────────────────────────────────────────────────────────────
# Disabled to conserve resources on the demo node.

alertmanager:
  enabled: false

# ── Node Exporter ─────────────────────────────────────────────────────────────────

nodeExporter:
  enabled: ${node_exporter_enabled}
  resources:
    limits:
      cpu: 100m
      memory: 64Mi
    requests:
      cpu: 20m
      memory: 32Mi

# ── Kube State Metrics ────────────────────────────────────────────────────────────

kubeStateMetrics:
  enabled: ${kube_state_metrics_enabled}
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 20m
      memory: 64Mi

# ── Prometheus Operator ───────────────────────────────────────────────────────────

prometheusOperator:
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 128Mi

  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    fsGroup: 65534

# ── Default rules ─────────────────────────────────────────────────────────────────

defaultRules:
  create: true
  rules:
    alertmanager: false   # alertmanager disabled
    etcd: false           # OKE manages etcd; no scrape access
    configReloaders: true
    general: true
    k8s: true
    kubeApiserverAvailability: true
    kubeApiserverBurnrate: true
    kubeApiserverHistogram: true
    kubeApiserverSlos: true
    kubelet: true
    kubeProxy: false      # OKE doesn't expose kube-proxy metrics
    kubePrometheusGeneral: true
    kubePrometheusNodeRecording: true
    kubernetesApps: true
    kubernetesResources: true
    kubernetesStorage: true
    kubernetesSystem: true
    kubeScheduler: false  # OKE managed; no scrape access
    kubeStateMetrics: true
    network: true
    node: true
    nodeExporterAlerting: true
    nodeExporterRecording: true
    prometheus: true
    prometheusOperator: true

# ── Disabled OKE-managed components ──────────────────────────────────────────────
# These are managed by OCI/OKE and are not accessible for scraping.

kubeApiServer:
  enabled: false

kubeControllerManager:
  enabled: false

coreDns:
  enabled: false

kubeDns:
  enabled: false

kubeEtcd:
  enabled: false

kubeScheduler:
  enabled: false

kubeProxy:
  enabled: false
