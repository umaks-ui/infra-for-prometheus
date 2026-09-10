# uma-yadav — prod-gke + Managed Prometheus

Picks up exactly where the manual `gcloud` inspection left off. This creates,
in order: a dedicated VPC (leaving `db-poc-vpc` untouched), a GKE Autopilot
cluster, and Managed Prometheus (GMP) wired into Cloud Monitoring.

## What this creates

```
uma-yadav
├── db-poc-vpc          ← untouched
└── prod-gke-vpc         ← new
    └── prod-gke-subnet
         ├── primary:   10.10.0.0/20
         ├── pods:      10.40.0.0/16
         └── services:  10.50.0.0/20
    └── prod-gke (GKE Autopilot)
         └── Managed Prometheus → Cloud Monitoring
```

None of these CIDRs overlap `db-poc-subnet` (10.20.0.0/16).

## 1. Authenticate and confirm the project

```bash
gcloud auth application-default login
gcloud config set project uma-yadav
```

## 2. Init and plan — review before applying anything

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
```

Check the plan output carefully. It should propose creating:
- `google_project_service.required` (6 resources)
- `google_compute_network.prod_gke`
- `google_compute_subnetwork.prod_gke`
- `google_compute_firewall.allow_internal`
- `google_container_cluster.prod_gke`

It should propose **zero changes** to `db-poc-vpc`, `db-poc-subnet`,
`private-service-access-db-poc`, or `default`.

## 3. Apply

```bash
terraform apply tfplan
```

GKE Autopilot cluster creation typically takes 8–12 minutes.

## 4. Verify

```bash
# Cluster exists and Autopilot is on
gcloud container clusters describe prod-gke \
  --project=uma-yadav --region=us-central1 \
  --format="value(autopilot.enabled)"

# Managed Prometheus is enabled
gcloud container clusters describe prod-gke \
  --project=uma-yadav --region=us-central1 \
  --format="yaml(monitoringConfig)"

# Get kubectl access
gcloud container clusters get-credentials prod-gke \
  --project=uma-yadav --region=us-central1

kubectl get nodes
```

## 5. Confirm metrics are flowing into Cloud Monitoring

```bash
gcloud monitoring time-series list \
  --project=uma-yadav \
  --filter='metric.type=starts_with("prometheus.googleapis.com")' \
  --format="table(metric.type)"
```

Or check the console: **Monitoring → Metrics Explorer**, search for a
`prometheus.googleapis.com/...` metric. This confirms GKE system metrics are
flowing through GMP — no application deployed yet, so you'll only see
infrastructure-level metrics at this point.

## 6. Application metrics (later, once you deploy workloads)

1. Deploy a service that exposes Prometheus-format metrics on `/metrics`.
2. Copy `kubernetes/monitoring/example-podmonitoring.yaml.template`, fill in
   the real `app` label and port, and apply it:
   ```bash
   kubectl apply -f kubernetes/monitoring/<service>-podmonitoring.yaml
   ```
3. Verify: `kubectl get podmonitoring -n <namespace>`

## 7. Dashboards and alerts

Build these in the console once metrics are confirmed flowing — start with
one dashboard (pod CPU/memory, restarts, scrape health) and a couple of
alerts (pod crash-looping, node not ready), then expand once you have real
application metrics to alert on.

## Notes / things deliberately deferred

- **Remote state**: this uses local state to start. Move to a GCS backend
  (see the commented block in `versions.tf`) before more than one person
  touches this repo.
- **Private cluster / Cloud NAT**: not configured — nodes get external IPs
  by default under this config. Add `private_cluster_config` + Cloud
  Router/NAT if you want private nodes later.
- **IAM/Workload Identity**: not set up yet. Add once you have a real
  service account structure for CI/CD (mirroring the WIF pattern used
  elsewhere, if you want consistency).
- **`deletion_protection = false`**: intentional for a POC-stage cluster.
  Flip to `true` once this is a cluster you don't want `terraform destroy`
  to be able to remove.
