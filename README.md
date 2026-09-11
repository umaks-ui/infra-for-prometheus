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

## 7. Dashboard and alerts

`dashboard.tf` creates one Cloud Monitoring dashboard (pod CPU, memory,
restarts, scrape health via `up`), and `alerts.tf` creates three alert
policies — pod crash-looping, node not ready, and scrape target down — all
querying GMP directly via PromQL.

You need to supply a notification email (no default, on purpose — it's not
committed to the repo):

```bash
terraform apply -var="github_repo=umaks-ui/<your-repo-name>" \
                  -var="notification_email=you@example.com" \
                  -out=tfplan
terraform apply tfplan
```

Or put both in a `terraform.tfvars` file (add it to `.gitignore` if it has
anything you don't want committed):

```hcl
github_repo         = "umaks-ui/<your-repo-name>"
notification_email  = "you@example.com"
```

After applying, get the dashboard link:

```bash
terraform output dashboard_url
```

Prefer Slack over email? See the commented block in `alerts.tf` for the
webhook-based notification channel — add a Slack Incoming Webhook URL and
uncomment it, then reference it in each alert policy's
`notification_channels`.

**`iam.tf`** also codifies the `roles/monitoring.metricWriter` binding on
the GKE node service account — this was applied manually via `gcloud`
while debugging why metrics weren't reaching Cloud Monitoring (collectors
were healthy and scraping, but had no write permission). It's a no-op on
apply since the binding already exists, but now it's tracked in Terraform
instead of only existing as a one-off `gcloud` command.

## 8. Wire up CI/CD (GitHub Actions)

`.github/workflows/terraform.yml` runs `terraform plan` on every PR and
`terraform apply` on merge to `main`, authenticating via Workload Identity
Federation (no JSON key).

**Bootstrapping note:** the workflow needs the WIF pool/provider/service
account (`wif.tf`) to exist before it can authenticate — so the *first*
apply (which creates `wif.tf`'s resources) has to be run locally with your
own `gcloud` credentials, same as steps 1–3 above. After that, CI can take
over.

1. Set your repo before applying:
   ```bash
   terraform apply -var="github_repo=umaks-ui/<your-repo-name>" -out=tfplan
   terraform apply tfplan
   ```
2. Grab the two outputs:
   ```bash
   terraform output wif_provider
   terraform output wif_service_account
   ```
3. In the GitHub repo: **Settings → Secrets and variables → Actions**, add:
   - `WIF_PROVIDER` = the `wif_provider` output
   - `WIF_SERVICE_ACCOUNT` = the `wif_service_account` output
4. Optional but recommended: **Settings → Environments**, create an
   environment named `production` and require a manual approval — the
   apply job in the workflow is already scoped to that environment, so
   this gates every apply behind a review.

From then on: open a PR → CI comments the plan → merge → CI applies.

## 9. The `test-nginx` canary

Right now `test-nginx` exists only as an imperative `kubectl create
deployment` — not tracked anywhere. Two options:

**A. Keep it as a permanent canary** (recommended while there's no real
workload yet) — formalize it as a manifest so it survives cluster
rebuilds and isn't just floating state:
```bash
mkdir -p kubernetes/canary
kubectl get deployment test-nginx -o yaml > kubernetes/canary/test-nginx-deployment.yaml
kubectl get service test-nginx -o yaml > kubernetes/canary/test-nginx-service.yaml
```
Then trim the `status:`, `uid`, `resourceVersion`, and other
cluster-generated fields out of both files before committing — keep just
`apiVersion`, `kind`, `metadata.name`, `metadata.labels`, and `spec`.

**B. Delete it** once you have a real workload to deploy, so Autopilot can
scale nodes back to zero when nothing's running:
```bash
kubectl delete service test-nginx
kubectl delete deployment test-nginx
```


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
