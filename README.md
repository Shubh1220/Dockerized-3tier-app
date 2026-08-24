# Dockerized 3-Tier Application on AWS

A Flask + static-frontend app, containerized with Docker, fronted by an Nginx
reverse proxy, persisting data in MySQL — running locally with Docker Compose
and in production on AWS EC2 + RDS.

```
                     ┌────────────────────────────────────────┐
 User ──HTTP──▶      │   EC2 instance                          │
                     │                                          │
                     │  ┌────────────┐   /            ┌──────┐ │
                     │  │   Nginx    │──────────────▶ │Front- │ │
                     │  │  (reverse  │                 │end    │ │
                     │  │   proxy)   │   /api/*        │(nginx)│ │
                     │  │  :80       │──────────────▶ └──────┘ │
                     │  └─────┬──────┘                          │
                     │        │              ┌────────────┐     │
                     │        └─────────────▶│  Backend   │     │
                     │                       │ Flask API  │     │
                     │                       │  :5000     │     │
                     │                       └─────┬──────┘     │
                     └─────────────────────────────┼────────────┘
                                                     │  3306 (TLS)
                                                     ▼
                                          ┌───────────────────┐
                                          │   AWS RDS MySQL    │
                                          │ (private subnet)   │
                                          └───────────────────┘
```

- **Frontend container**: static HTML/JS/CSS served by nginx.
- **Backend container**: Flask API (gunicorn) talking to MySQL via PyMySQL.
- **Reverse-proxy container**: the only container exposed on port 80; routes
  `/` to the frontend and `/api/*` to the backend.
- **Database**: MySQL container (with a persistent volume) for local dev,
  AWS RDS MySQL for production.

## Project layout

```
three-tier-app/
├── backend/                         # Flask REST API
│   ├── app.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .dockerignore
│
├── frontend/                        # Static frontend
│   ├── index.html
│   ├── style.css
│   ├── app.js
│   ├── nginx.conf                   # Nginx config for frontend container
│   ├── Dockerfile
│   └── .dockerignore
│
├── nginx/                           # Reverse proxy
│   ├── nginx.conf                   # Routes frontend + backend traffic
│   └── Dockerfile
│
├── deploy/                          # EC2 deployment scripts
│   └── deploy.sh
│
├── docker-compose.yml               # Local development + MySQL
├── docker-compose.prod.yml          # Production + AWS RDS
│
├── .env.example                     # Environment variable template
├── .env                             # Local environment variables
├── .env.aws                          # AWS/production environment variables
├── .gitignore
├── README.md                         # Project documentation

```

## 1. Run it locally

```bash
cp .env.example .env          # edit passwords as you like
docker compose up -d --build
```

Visit `http://localhost/`. The stack:
- `mysql` — MySQL 8 with a named volume (`db_data`) so data survives
  `docker compose down` / restarts.
- `backend` — waits for MySQL's healthcheck, creates the `tasks` table if
  missing.
- `frontend` — static UI.
- `nginx` — the only port published to the host (`80`).

Check health: `curl http://localhost/api/health`

Tear down (keep data): `docker compose down`
Tear down (wipe data): `docker compose down -v`

## 2. AWS architecture for production

| Component | AWS Resource |
|---|---|
| Compute | EC2 instance running Docker + Docker Compose |
| Database | RDS for MySQL (Multi-AZ recommended), **not publicly accessible** |
| Networking | EC2 in a public subnet, RDS in private subnets, two security groups |
| Reverse proxy / TLS | Nginx container on EC2 (port 80/443); optionally put an ALB in front |

### Security groups

Two separate security groups, least privilege:

**`three-tier-ec2-sg`** (attached to the EC2 instance)
| Type | Port | Source |
|---|---|---|
| SSH | 22 | Your IP only (`x.x.x.x/32`) |
| HTTP | 80 | `0.0.0.0/0` |
| HTTPS | 443 | `0.0.0.0/0` |

**`three-tier-rds-sg`** (attached to the RDS instance)
| Type | Port | Source |
|---|---|---|
| MySQL | 3306 | `three-tier-ec2-sg` (by security-group reference, **not** an IP range) |

RDS should have "Publicly accessible" set to **No** — only the EC2 security
group can reach it.

Create both with the provided script:

```bash
VPC_ID=vpc-xxxxxxxx MY_IP=$(curl -s ifconfig.me)/32 ./deploy/create_security_groups.sh
```

### Create the RDS instance

```bash
RDS_SG_ID=sg-xxxx SUBNET_GROUP=my-db-subnet-group DB_PASSWORD='StrongPassw0rd!' \
  ./deploy/create_rds.sh
```

Wait for it to become `available`, then grab the endpoint:

```bash
aws rds describe-db-instances --db-instance-identifier three-tier-mysql \
  --query 'DBInstances[0].Endpoint.Address' --output text
```

### Launch EC2 and deploy

1. Launch an EC2 instance (Amazon Linux 2023 or Ubuntu 22.04+, `t3.micro`/`t3.small`
   is enough for a demo) in a public subnet, attached to `three-tier-ec2-sg`,
   with a key pair for SSH.
2. SSH in, then either:
   - clone the repo yourself and copy `.env.example` to `.env`, filling in
     `DB_HOST` with the RDS endpoint, `DB_USER`/`DB_PASSWORD` matching what
     you set in `create_rds.sh`, and `DB_NAME`; or
   - let `deploy.sh` clone it for you (see below) and then create `.env`.
3. Run the deploy script:

   ```bash
   curl -O https://raw.githubusercontent.com/<you>/<repo>/main/deploy/deploy.sh
   chmod +x deploy.sh
   REPO_URL="https://github.com/<you>/<repo>.git" ./deploy.sh
   ```

   The script installs Docker + the Compose plugin if needed, clones/pulls the
   repo into `/opt/three-tier-app`, and runs
   `docker compose -f docker-compose.prod.yml up -d --build`.

4. Visit `http://<ec2-public-ip>/`.

### Redeploying after a `git push`

Re-run the same script (or just `deploy.sh` again) — it pulls the latest
commit and rebuilds/restarts the containers:

```bash
ssh -i mykey.pem ec2-user@<ec2-ip> 'cd /opt/three-tier-app && ./deploy/deploy.sh'
```

For real CI/CD, wire this into a GitHub Actions workflow that SSHes in and
runs `deploy.sh` on every push to `main`.

## 3. Environment variables

| Variable | Used by | Notes |
|---|---|---|
| `DB_HOST` | backend | `mysql` locally, RDS endpoint in prod |
| `DB_PORT` | backend | default `3306` |
| `DB_NAME` | backend, mysql (dev) | schema name |
| `DB_USER` | backend, mysql (dev) | app-level DB user (not root) |
| `DB_PASSWORD` | backend, mysql (dev) | keep out of Git — set only in `.env` |
| `MYSQL_ROOT_PASSWORD` | mysql (dev only) | not used against RDS |
| `FLASK_SECRET_KEY` | backend | random string |
| `PUBLIC_PORT` | nginx (dev) | defaults to `80` |

`.env` is git-ignored; only `.env.example` (with placeholder values) is
committed.

## 4. Persistence

- **Local dev**: the `db_data` named Docker volume persists MySQL's data
  directory across container restarts and `docker compose down` (not
  `down -v`).
- **Production**: RDS handles persistence, automated backups (7-day retention
  in `create_rds.sh`), and optional Multi-AZ failover — the EC2/Docker layer
  is stateless and can be rebuilt at any time without losing data.

## 5. GitHub workflow

```
git init
git remote add origin https://github.com/<you>/<repo>.git
git add .
git commit -m "Initial 3-tier app"
git push -u origin main
```

Then on EC2, `deploy.sh` (or your CI/CD) pulls from `origin/main` and rebuilds.
