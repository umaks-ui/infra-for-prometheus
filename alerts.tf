variable "notification_email" {
  description = "Email address to receive alert notifications"
  type        = string
  # No default on purpose — pass via -var or a .tfvars file so it's
  # never accidentally left blank or committed to the repo.
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "${var.cluster_name} alerts (email)"
  type         = "email"

  labels = {
    email_address = var.notification_email
  }
}

# --- Slack alternative ---
# If you'd rather route to Slack, add an Incoming Webhook in your Slack
# workspace, then replace the channel above (or add alongside it) with:
#
# resource "google_monitoring_notification_channel" "slack" {
#   display_name = "${var.cluster_name} alerts (Slack)"
#   type         = "webhook_tokenauth"
#   labels = {
#     url = var.slack_webhook_url
#   }
# }
#
# and add its .name to each alert policy's notification_channels list below.

locals {
  notification_channels = [google_monitoring_notification_channel.email.name]
}

# 1. Pod crash-looping
resource "google_monitoring_alert_policy" "pod_crash_looping" {
  display_name = "${var.cluster_name}: pod crash-looping"
  combiner      = "OR"

  conditions {
    display_name = "Container restarts > 2 in 15m"
    condition_prometheus_query_language {
      query    = "increase(kube_pod_container_status_restarts_total{namespace=\"default\"}[15m]) > 2"
      duration = "0s"
    }
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s" # auto-resolve after 30m of no data matching the condition
  }
}

# 2. Node not ready
resource "google_monitoring_alert_policy" "node_not_ready" {
  display_name = "${var.cluster_name}: node not ready"
  combiner      = "OR"

  conditions {
    display_name = "Node Ready condition == false for 5m"
    condition_prometheus_query_language {
      query    = "kube_node_status_condition{condition=\"Ready\",status=\"true\"} == 0"
      duration = "300s"
    }
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }
}

# 3. Scrape target down — catches the exact class of problem we hit today
# (collector running but nothing reaching Cloud Monitoring shows up here
# as targets going from up=1 to up=0, or missing entirely).
resource "google_monitoring_alert_policy" "scrape_target_down" {
  display_name = "${var.cluster_name}: scrape target down"
  combiner      = "OR"

  conditions {
    display_name = "up == 0 for 5m"
    condition_prometheus_query_language {
      query    = "up == 0"
      duration = "300s"
    }
  }

  notification_channels = local.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }
}
