# PERN Task Manager — GitHub Actions CI/CD Pipeline

![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![AWS EKS](https://img.shields.io/badge/AWS_EKS-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)

A full-stack PERN (PostgreSQL, Express, React, Node.js) task manager app with three deployment modes — Docker Compose on EC2, Kubernetes via kind/k3s, and Kubernetes on AWS EKS provisioned entirely with Terraform — all automated through GitHub Actions.

> **v2 of this project** — previously deployed with Jenkins. Migrated to GitHub Actions and extended with Kubernetes support. See [task-manager-cicd-pipeline](https://github.com/yourusername/task-manager-cicd-pipeline) for the Jenkins version.

---

### Infrastructure

| Component | Technology |
|-----------|------------|
| Source Control | GitHub |
| CI/CD | GitHub Actions |
| Image Registry | Docker Hub |
| Infrastructure as Code | Terraform |
| Cloud | AWS (VPC, EKS, S3, DynamoDB) |
| Container Orchestration | Kubernetes (kind, k3s, EKS) |
| Database | PostgreSQL 16 |
| Backend | Node.js + Express |
| Frontend | React + Nginx |

---

## Pipeline Stages

### Mode 1 — Docker Compose (EC2)
```
build-and-push ──────────────────────────► deploy
   ├── Checkout code                          ├── Checkout code
   ├── Log in to Docker Hub                   ├── Pin image tags in compose
   ├── Build & push client image              ├── SCP compose file to EC2
   └── Build & push server image              └── SSH → docker compose up -d
```

### Mode 2 — Kubernetes (kind)
```
build-and-push ──────────────────────────► deploy
   ├── Checkout code                          ├── Checkout code
   ├── Log in to Docker Hub                   ├── Create kind cluster
   ├── Build & push client image              ├── Update image tags
   └── Build & push server image              ├── kubectl apply all manifests
                                              ├── Wait for postgres ready
                                              ├── Create database table
                                              ├── Wait for backend + frontend
                                              └── Run API smoke tests
```

### Mode 3 — Terraform + EKS
```
build-and-push ──► provision ──────────────────────► deploy
   ├── Checkout      ├── Checkout                      ├── Checkout
   ├── Login         ├── Configure AWS credentials      ├── Configure AWS credentials  
   ├── Build client  ├── Setup Terraform               ├── Setup kubectl
   └── Build server  ├── terraform init                ├── aws eks update-kubeconfig
                     ├── terraform plan                ├── Update image tags
                     └── terraform apply               ├── kubectl apply manifests
                          (VPC + EKS + node groups)    └── kubectl rollout status
```

The `provision` job only runs when files in `infra/` change — app deployments skip straight to `deploy`. The `deploy` job uses `aws eks update-kubeconfig` instead of a stored kubeconfig secret.

The `deploy` job has `needs: build-and-push` — it only runs if the build succeeds. Both jobs run on fresh GitHub-hosted Ubuntu VMs.

---

## Project Structure

```
task-manager-github-actions/
│
├── .github/
│   └── workflows/
│       └── deploy.yml              # Full pipeline definition
│
├── client/                         # React frontend
│   ├── src/
│   │   ├── components/
│   │   │   ├── InputTodo.js        # Add todo — uses relative /api/todo
│   │   │   ├── ListTodos.js        # List + delete — uses relative /api/todos
│   │   │   └── EditTodo.js         # Edit modal — uses relative /api/todos/:id
│   │   └── App.js
│   ├── nginx.conf                  # Proxies /api/* to backend container
│   ├── Dockerfile                  # Multi-stage: node build → nginx serve
│   └── package.json
│
├── server/                         # Express backend
│   ├── index.js                    # REST API routes — all prefixed /api
│   ├── db.js                       # PostgreSQL connection with retry logic
│   ├── database.sql                # Table init script
│   ├── Dockerfile
│   └── package.json
│
├── k8s/                            # Kubernetes manifests
│   ├── postgres/
│   │   ├── deployment.yaml         # Postgres Deployment + Service + PVC
│   │   └── secret.yaml             # DB credentials as k8s Secret
│   ├── backend/
│   │   └── deployment.yaml         # Backend Deployment + Service
│   └── frontend/
│       └── deployment.yaml         # Frontend Deployment + NodePort Service
│
├── infra/                          # Terraform infrastructure as code
│   ├── bootstrap/
│   │   └── main.tf                 # One-time: creates S3 state bucket + DynamoDB lock
│   ├── main.tf                     # VPC, subnets, EKS cluster, security groups
│   ├── variables.tf                # Input variables
│   ├── outputs.tf                  # Cluster name, endpoint
│   └── backend.tf                  # Remote state in S3
│
├── database.sql                    # Mounted into postgres on fresh deploy
├── docker-compose.yaml             # Local dev + EC2 compose deployment
└── README.md
```

---

## Key Technical Decisions

**GitHub Actions over Jenkins**
Jenkins requires a dedicated server running 24/7. GitHub Actions runs on GitHub's infrastructure — no server to maintain, no Docker socket to mount, no SSH keys to manage inside a container. The pipeline logic is identical, the operational overhead is zero.

**Nginx reverse proxy in the frontend container**
React fetch calls use relative URLs (`/api/todos`) with no hardcoded host or port. Nginx forwards all `/api/*` traffic to the backend container internally. The same Docker image works in any environment with zero config changes.

```nginx
location /api {
    proxy_pass http://todo-backend:5000;
}
```

**Terraform provisions all AWS infrastructure**
The entire AWS environment — VPC, subnets, internet gateway, route tables, security groups, IAM roles, and the EKS cluster — is defined as code in `infra/main.tf`. A fresh AWS account can go from zero to a running EKS cluster with a single `terraform apply`. `terraform destroy` removes everything with no manual cleanup.

**Remote state with S3 + DynamoDB locking**
Terraform state lives in S3 so both local machines and GitHub Actions runners read and write the same state. DynamoDB provides state locking — prevents two pipeline runs from modifying infrastructure simultaneously and corrupting state.

```hcl
terraform {
  backend "s3" {
    bucket         = "myapp-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Bootstrap pattern for state infrastructure**
The S3 bucket and DynamoDB table can't be managed by the same Terraform config that uses them — a chicken-and-egg problem. A separate `infra/bootstrap/` config creates them once manually. Everything else is managed by CI/CD.

**Terraform only runs when infrastructure changes**
The `provision` job uses a path filter — it only triggers when files in `infra/` are modified. Pushing app code changes skips Terraform entirely and goes straight to deployment. This prevents unnecessary EKS reprovisioning on every commit.

**Build number pinning**
The pipeline uses `sed` to replace image tags in `docker-compose.yaml` with the exact GitHub run number before deploying. Every production deployment references a specific immutable image — never `:latest`. Rollback is changing one number.

```yaml
- name: Pin image tags in compose file
  run: |
    sed -i "s|image: .../server:.*|image: .../server:${{ github.run_number }}|" docker-compose.yaml
    sed -i "s|image: .../client:.*|image: .../client:${{ github.run_number }}|" docker-compose.yaml
```

**Automatic database initialisation**
`database.sql` is SCP'd to EC2 alongside `docker-compose.yaml` and mounted into the postgres container via `docker-entrypoint-initdb.d/`. On a completely fresh deployment the table is created automatically — no manual steps.

**Health checks on all services**
All three containers report real status. Backend and frontend are checked via HTTP, database via `pg_isready`. Dependent services wait for healthy status before starting — the backend won't attempt DB connections until postgres is confirmed ready.

---

## Comparison with Jenkins Version

| | Jenkins Version | GitHub Actions Version |
|--|----------------|----------------------|
| CI Server | Jenkins on DigitalOcean droplet | GitHub hosted runners |
| Server cost | ~$6/month droplet | Free |
| Pipeline file | `Jenkinsfile` (Groovy) | `deploy.yml` (YAML) |
| Credentials | Jenkins credential store | GitHub Secrets |
| Docker access | Socket mount required | Built into runner |
| SSH to EC2 | Manual key setup in container | `appleboy/ssh-action` |
| Image tagging | `BUILD_NUMBER` | `github.run_number` |
| Trigger | GitLab webhook | GitHub push event |

---

## Local Development Setup

### Prerequisites
- Docker & Docker Compose
- Node.js 20+

### Run locally

```bash
# Clone the repo
git clone https://github.com/yourusername/task-manager-github-actions.git
cd task-manager-github-actions

# Create a .env file
cp .env.example .env
# Fill in your values

# Start everything
docker compose up --build
```

App available at `http://localhost`.

### Environment Variables

```env
DB_HOST=db
DB_USER=postgres
DB_PASSWORD=yourpassword
DB_NAME=todo_db
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/todos` | Get all todos |
| `GET` | `/api/todos/:id` | Get a single todo |
| `POST` | `/api/todo` | Create a new todo |
| `PUT` | `/api/todos/:id` | Update a todo |
| `DELETE` | `/api/todos/:id` | Delete a todo |

---

## Replicating This Pipeline

### GitHub Secrets Required

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|--------|-------|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `EC2_HOST` | EC2 public IP (docker compose mode) |
| `EC2_USER` | `ec2-user` (docker compose mode) |
| `EC2_SSH_KEY` | Private key PEM (docker compose mode) |
| `AWS_ACCESS_KEY_ID` | IAM user access key (Terraform + EKS mode) |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key (Terraform + EKS mode) |
| `AWS_REGION` | e.g. `ap-southeast-1` |
| `EKS_CLUSTER_NAME` | `myapp-eks-cluster` |

### EC2 Requirements

```bash
# Install Docker
sudo yum update -y && sudo yum install -y docker
sudo systemctl start docker && sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Install Docker Compose plugin
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Create deploy directory
mkdir -p ~/task-manager
```

### Security Group Inbound Rules

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 22 | TCP | 0.0.0.0/0 | GitHub Actions SSH |
| 80 | TCP | 0.0.0.0/0 | App access |

---

## Kubernetes Concepts Used

**Deployment** — manages desired pod state. If a pod crashes Kubernetes automatically replaces it.

**Service** — provides stable DNS names (, , ) so pods can reach each other regardless of their changing IPs.

**PersistentVolumeClaim** — requests persistent storage for postgres so data survives pod restarts.

**Secret** — stores database credentials as base64-encoded values injected as environment variables — never hardcoded in manifests.

**NodePort Service** — exposes the frontend on port 30080 on every node, accessible from outside the cluster.

**Readiness + Liveness Probes** — readiness controls when traffic is sent to a pod, liveness restarts pods that stop responding. Both use HTTP checks.

---

## Lessons Learned

**From migrating Jenkins → GitHub Actions:**
- Pipeline concepts are identical across tools — triggers, jobs, steps, secrets. Learning one makes the next trivial.
- GitHub Actions prebuilt actions (`docker/login-action`, `appleboy/ssh-action`) replace shell scripting boilerplate. Less code, fewer bugs.
- Not needing a CI server eliminates an entire category of infrastructure problems — no Docker socket mounts, no SSH key management inside containers, no server maintenance.
- `needs:` in GitHub Actions is more explicit than Jenkins stage ordering — you declare job dependencies intentionally.
- A running container might be from an old image — always verify the tag matches your latest build number before debugging.

**From migrating to Kubernetes:**
- `kubectl apply` succeeds even if the pod crashes seconds later — always verify with `kubectl wait`
- Pod ready does not mean application ready — use `pg_isready` not just Kubernetes readiness probes
- `-it` flags don't work in CI pipelines — no TTY available, always remove from `kubectl exec` in automation
- Kubernetes service names are DNS — containers reach each other by service name, not IP
- `kubectl describe pod` is more useful than `kubectl logs` when a pod won't start

**From adding Terraform + EKS:**
- Terraform state is not optional in CI/CD — GitHub Actions runners are ephemeral, state must live in S3
- You cannot downgrade Kubernetes versions — AWS only allows upgrades. Always pin to a stable tested version, not the latest
- EKS node groups fail silently — `NodeCreationFailure` can mean anything from wrong subnet tags to instance type capacity issues to a known bug in a new K8s version
- The bootstrap pattern exists for a reason — you can't use Terraform to create the bucket that stores Terraform's own state
- `terraform plan` in CI on feature branches, `terraform apply` only on main — never apply blindly without reviewing the plan
- Terraform and application deployments have different lifecycles — keep them in separate jobs with separate triggers

**Carried over from Jenkins version:**
- Always use relative URLs in React — `localhost` in fetch calls breaks in production
- `docker compose ps` showing `Up` is not the same as healthy — always add health checks
- Env vars with duplicate keys in JS objects silently use the last value — never hardcode credentials

---

## Improvements

### Completed
- [x] Migrated from Jenkins to GitHub Actions — zero CI server overhead
- [x] Automated database table creation via `docker-entrypoint-initdb.d/`
- [x] Docker health checks on all services
- [x] Pinned image tags — exact build number deployed, never `:latest`
- [x] Kubernetes manifests for all three services
- [x] CI pipeline deploys to real kind cluster on every push
- [x] Readiness and liveness probes on all pods
- [x] Secrets management via Kubernetes Secrets
- [x] Persistent storage for database via PVC
- [x] Automated API smoke tests after deployment
- [x] Terraform provisions full AWS infrastructure — VPC, subnets, EKS cluster
- [x] Remote Terraform state in S3 with DynamoDB locking
- [x] Bootstrap pattern for state infrastructure
- [x] Terraform only runs on infra changes — app deploys skip provisioning

### Up Next
- [ ] Helm charts — package manifests with configurable values
- [ ] Multiple environments — dev, staging, production namespaces
- [ ] Horizontal Pod Autoscaler
- [ ] Add security scanning — Trivy, Snyk, Checkov
- [ ] Set up Prometheus + Grafana monitoring
- [ ] HTTPS with cert-manager and Let's Encrypt on EKS

---

## 📄 License

MIT
