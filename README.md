📋 PERN Task Manager — Full CI/CD Pipeline

![CI/CD](https://img.shields.io/badge/CI%2FCD-Jenkins-D24939?style=for-the-badge&logo=jenkins&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![AWS](https://img.shields.io/badge/AWS_EC2-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)

A full-stack PERN (PostgreSQL, Express, React, Node.js) task manager app deployed to AWS EC2 via a fully automated CI/CD pipeline using Jenkins, Docker, and Docker Hub.

> **Learning project** — built to practice containerisation, CI/CD pipeline design, and production deployment on cloud infrastructure.

---

## Architecture

<img width="1280" height="720" alt="Developer" src="https://github.com/user-attachments/assets/44b118ba-a6a3-4677-b096-dceefe4491e1" />

### Infrastructure

| Component | Technology |
|-----------|-----------|
| Source Control | GitLab |
| CI/CD Server | Jenkins on DigitalOcean Droplet |
| Image Registry | Docker Hub |
| Production Server | AWS EC2 (Amazon Linux 2023) |
| Database | PostgreSQL 16 (Docker) |
| Backend | Node.js + Express |
| Frontend | React + Nginx |

---

## Pipeline Stages

```
Checkout → Build Client → Build Server → Push Images → Deploy to EC2
```

1. **Checkout** — Jenkins pulls latest code from GitLab
2. **Build Client** — Builds React app Docker image, tags with build number and `:latest`
3. **Build Server** — Builds Node.js API Docker image, tags with build number and `:latest`
4. **Push Images** — Logs into Docker Hub, pushes both images
5. **Deploy to EC2** — SCPs `docker-compose.yaml` to EC2, SSHs in and runs `docker compose pull && docker compose up -d`

---

## Project Structure

```
task-manager-cicd-pipeline/
│
├── client/                         # React frontend
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   │   ├── InputTodo.js        # Add todo form
│   │   │   ├── ListTodos.js        # Todo list with delete
│   │   │   └── EditTodo.js         # Edit modal
│   │   └── App.js
│   ├── nginx.conf                  # Nginx config — proxies /api to backend
│   ├── Dockerfile                  # Multi-stage: node build → nginx serve
│   └── package.json
│
├── server/                         # Express backend
│   ├── index.js                    # API routes
│   ├── db.js                       # PostgreSQL connection pool
│   ├── database.sql                # Table initialisation script
│   ├── Dockerfile
│   └── package.json
│
├── docker-compose.yaml             # Production compose — uses pre-built images
├── Jenkinsfile                     # Full pipeline definition
└── README.md
```

---

## Key Technical Decisions

Nginx as reverse proxy in the frontend container
Rather than hardcoding an API URL into the React build, the frontend nginx proxies all /api/* requests to the backend container. This means the same Docker image works in any environment with zero config changes.
nginxlocation /api {
    proxy_pass http://todo-backend:5000;
}
Jenkins SCPs docker-compose.yaml on every deploy
The compose file lives in the repo and gets pushed to EC2 as part of the pipeline. The server never drifts out of sync with the codebase.
Build number tagging with pinned production tags
Every image is tagged with both the Jenkins build number and :latest during the build. The production docker-compose.yaml is updated by the pipeline to reference the exact build number tag — never :latest — so deployments are deterministic and rollback is as simple as reverting the tag to a previous build number.
Automatic database initialisation
The postgres container mounts server/database.sql into /docker-entrypoint-initdb.d/ so the todo table is created automatically on first run. No manual steps required on a fresh deployment.
yamldb:
  volumes:
    - db-data:/var/lib/postgresql/data
    - ./server/database.sql:/docker-entrypoint-initdb.d/init.sql
Health checks on all services
All three containers report their real status rather than just Up. The backend and frontend are checked via HTTP, the database via pg_isready. Dependent services wait for healthy status before starting.

```nginx
location /api {
    proxy_pass http://todo-backend:5000;
}
```

**Jenkins SCPs docker-compose.yaml on every deploy**
The compose file lives in the repo and gets pushed to EC2 as part of the pipeline. The server never drifts out of sync with the codebase.

**Build number tagging**
Every image is tagged with both the Jenkins build number and `:latest`, enabling instant rollback by referencing a previous build number.

---

## Setup

### Prerequisites
- Docker & Docker Compose
- Node.js 20+

### Run locally

```bash
# Clone the repo
git clone https://github.com/yourusername/task-manager-cicd-pipeline.git
cd task-manager-cicd-pipeline

# Create a .env file
cp .env.example .env

# Start everything
docker compose up --build
```

App will be available at `http://localhost`.

### Environment Variables

Create a `.env` file in the ./server directory:

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

## ⚙️ Jenkins Setup Requirements

To replicate this pipeline you will need:

- Jenkins running in Docker with the Docker socket mounted:
  ```bash
  docker run -d --name jenkins \
    -p 8080:8080 -p 50000:50000 \
    -v jenkins_home:/var/jenkins_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /usr/bin/docker:/usr/bin/docker \
    --group-add $(stat -c '%g' /var/run/docker.sock) \
    jenkins/jenkins:lts
  ```
- A `dockerhub-creds` credential configured in Jenkins (username + password)
- The EC2 private key copied into `/var/jenkins_home/.ssh/id_rsa`
- EC2 added to Jenkins `known_hosts` via `ssh-keyscan`

---

## 💡 Lessons Learned

This was my first end-to-end CI/CD deployment. A full breakdown of every bug encountered and how it was fixed is documented in [`LEARNING_JOURNAL.md`](./LEARNING_JOURNAL.md).

Key takeaways:

- Always build Docker images locally before pushing to CI
- Never hardcode credentials — duplicate JS object keys silently override env vars
- React runs in the browser, not the server — `localhost` in fetch calls breaks in production
- `docker compose ps` showing `Up` does not mean the app is working — add health checks
- Jenkins `Start of Pipeline / End of Pipeline` with no stages = Jenkinsfile not being read

---

## What I'd Improve Next

 Completed

- [x] Automate database table creation via docker-entrypoint-initdb.d/
- [x] Add Docker health checks to all services
- [x] Pin image tags in production compose instead of using :latest

## Up Next

- [ ] Migrate pipeline from Jenkins to GitHub Actions
- [ ] Set up HTTPS with Let's Encrypt + certbot
- [ ] Add Prometheus + Grafana for monitoring
- [ ] Provision infrastructure with Terraform instead of manually






