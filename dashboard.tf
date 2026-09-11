# Single dashboard: pod CPU/memory, restarts, and scrape health.
# Widgets query GMP directly via PromQL (no manual metric-name lookups
# needed in the console).

resource "google_monitoring_dashboard" "prod_overview" {
  dashboard_json = jsonencode({
    displayName = "${var.cluster_name} Overview"
    gridLayout = {
      columns = "2"
      widgets = [
        {
          title = "Pod CPU usage (cores)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                prometheusQuery = "sum(rate(container_cpu_usage_seconds_total{namespace=\"default\"}[5m])) by (pod)"
              }
              plotType = "LINE"
            }]
            yAxis = { scale = "LINEAR" }
          }
        },
        {
          title = "Pod memory usage (bytes)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                prometheusQuery = "sum(container_memory_working_set_bytes{namespace=\"default\"}) by (pod)"
              }
              plotType = "LINE"
            }]
            yAxis = { scale = "LINEAR" }
          }
        },
        {
          title = "Pod restarts (15m increase)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                prometheusQuery = "sum(increase(kube_pod_container_status_restarts_total{namespace=\"default\"}[15m])) by (pod)"
              }
              plotType = "STACKED_BAR"
            }]
            yAxis = { scale = "LINEAR" }
          }
        },
        {
          title = "Scrape health (up)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                prometheusQuery = "up"
              }
              plotType = "LINE"
            }]
            yAxis = { scale = "LINEAR" }
          }
        }
      ]
    }
  })
}

output "dashboard_url" {
  description = "Direct link to the dashboard once applied"
  value       = "https://console.cloud.google.com/monitoring/dashboards/builder/${element(split("/", google_monitoring_dashboard.prod_overview.id), 1)}?project=${var.project_id}"
}
