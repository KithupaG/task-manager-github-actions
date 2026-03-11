# 📋 PERN Task Manager — GitHub Actions CI/CD Pipeline

![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![AWS](https://img.shields.io/badge/AWS_EC2-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)

A full-stack PERN (PostgreSQL, Express, React, Node.js) task manager app deployed to AWS EC2 via a fully automated CI/CD pipeline using GitHub Actions and Docker.

> **v2 of this project** — previously deployed with Jenkins. Migrated to GitHub Actions to remove the need for a separate CI server. See [task-manager-cicd-pipeline](https://github.com/kithupag/task-manager-cicd-pipeline) for the Jenkins version.

---

## 🏗️ Architecture

```
Developer → GitHub Push → GitHub Actions → Docker Hub → AWS EC2
                                ↓
                    Build & push Docker images
                    Pin exact build number tag in compose
                    SCP docker-compose.yaml to EC2
                    SSH into EC2 → docker compose up
```

### Infrastructure

| Component | Technology |
|-----------|------------|
| Source Control | GitHub |
| CI/CD | GitHub Actions |
| Image Registry | Docker Hub |
| Production Server | AWS EC2 (Amazon Linux 2023) |
| Database | PostgreSQL 16 (Docker) |
| Backend | Node.js + Express |
| Frontend | React + Nginx |

---

## 🚀 Pipeline Stages

```
build-and-push ──────────────────────────► deploy
   ├── Checkout code                          ├── Checkout code
   ├── Log in to Docker Hub                   ├── Pin image tags in compose
   ├── Build & push client image              ├── SCP compose file to EC2
   └── Build & push server image              └── SSH → docker compose up -d
```

The `deploy` job has `needs: build-and-push` — it only runs if the build succeeds. Both jobs run on fresh GitHub-hosted Ubuntu VMs.

---

## 📁 Project Structure

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
├── database.sql                    # Mounted into postgres on fresh deploy
├── docker-compose.yaml             # Production compose — image tags pinned by pipeline
└── README.md
```

---

## 🔧 Key Technical Decisions

**GitHub Actions over Jenkins**
Jenkins requires a dedicated server running 24/7. GitHub Actions runs on GitHub's infrastructure — no server to maintain, no Docker socket to mount, no SSH keys to manage inside a container. The pipeline logic is identical, the operational overhead is zero.

**Nginx reverse proxy in the frontend container**
React fetch calls use relative URLs (`/api/todos`) with no hardcoded host or port. Nginx forwards all `/api/*` traffic to the backend container internally. The same Docker image works in any environment with zero config changes.

```nginx
location /api {
    proxy_pass http://todo-backend:5000;
}
```

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

## 🔄 Comparison with Jenkins Version

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

## 🛠️ Local Development Setup

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

## 📡 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/todos` | Get all todos |
| `GET` | `/api/todos/:id` | Get a single todo |
| `POST` | `/api/todo` | Create a new todo |
| `PUT` | `/api/todos/:id` | Update a todo |
| `DELETE` | `/api/todos/:id` | Delete a todo |

---

## ⚙️ Replicating This Pipeline

### GitHub Secrets Required

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|--------|-------|
| `DOCKERHUB_USERNAME` | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token (not password) |
| `EC2_HOST` | EC2 public IP or Elastic IP |
| `EC2_USER` | `ec2-user` |
| `EC2_SSH_KEY` | Private key contents (PEM format) |

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

## 💡 Lessons Learned

**From migrating Jenkins → GitHub Actions:**
- Pipeline concepts are identical across tools — triggers, jobs, steps, secrets. Learning one makes the next trivial.
- GitHub Actions prebuilt actions (`docker/login-action`, `appleboy/ssh-action`) replace shell scripting boilerplate. Less code, fewer bugs.
- Not needing a CI server eliminates an entire category of infrastructure problems — no Docker socket mounts, no SSH key management inside containers, no server maintenance.
- `needs:` in GitHub Actions is more explicit than Jenkins stage ordering — you declare job dependencies intentionally.
- A running container might be from an old image — always verify the tag matches your latest build number before debugging.

**Carried over from Jenkins version:**
- Always use relative URLs in React — `localhost` in fetch calls breaks in production
- `docker compose ps` showing `Up` is not the same as healthy — always add health checks
- Env vars with duplicate keys in JS objects silently use the last value — never hardcode credentials

---

## 📌 Improvements

### ✅ Completed
- [x] Migrated from Jenkins to GitHub Actions
- [x] Automated database table creation via `docker-entrypoint-initdb.d/`
- [x] Docker health checks on all services
- [x] Pinned image tags — exact build number deployed, never `:latest`

### 🔜 Up Next
- [ ] Provision EC2 infrastructure with Terraform
- [ ] Add security scanning — Trivy, Snyk, Checkov
- [ ] Add Prometheus + Grafana monitoring
- [ ] Migrate to Kubernetes deployment

---

## 📄 License

MIT