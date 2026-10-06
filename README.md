# infrastructure-playground

A multi-container sandbox for practicing core DevOps fundamentals: infrastructure as code, configuration management, container orchestration, CI/CD, and observability.

**Status:** Actively in progress — see [Roadmap](#roadmap) for current build status.

The application logic in this repository is intentionally minimal. Simply a thin, input-validated wrapper meant to generate realistic traffic. The focus of the project is the surrounding infrastructure: provisioning, networking, configuration, deployment, monitoring, and teardown.

---

## System Overview

A small multi-container system (ingest → load balancer → worker pool → database → backup storage) serves as the environment for infrastructure testing. 

```
[Ingest Container] → [Nginx (load balancer)] → [Worker Containers (batch processing)] → [Postgres]
                                                                                              ↓
                                                                                   [LocalStack S3 (session backups)]
                           → Prometheus ↓
Observability layer: Alloy → Loki → Grafana
```

## Tech Stack

* **Containerization:** Docker
* **Load Balancing:** Nginx
* **Database:** PostgreSQL
* **Cloud Emulation:** LocalStack (S3)
* **Infrastructure as Code:** Terraform
* **CI/CD:** GitHub Actions
* **Observability:** Alloy, Prometheus, Loki, Grafana
* **Application Layer:** Python

## Roadmap

- [x] Core application logic (ingest → route → process → persist)
- [x] Terraform provisioning
- [x] GitHub Actions CI/CD (builds, registry push, linting)
- [x] LocalStack S3 backup integration
- [x] Observability stack (Alloy, Prometheus, Loki, Grafana)

## Key Objectives

* **Infrastructure as Code:** Define, provision, and destroy the full environment reproducibly using Terraform.
* **Networking & Load Balancing:** Implement service discovery and traffic management via Nginx.
* **CI/CD:** Automate container builds, registry pushes, and checks with GitHub Actions.
* **Observability:** Aggregate and visualize logs across all services using Alloy, Prometheus, Loki, and Grafana.
* **Local Cloud Emulation:** Test cloud integrations locally with LocalStack S3.
* **Portability** Maintain strict host-agnosticism for true reproducibility and to make a hypothetical refactor for cloud deployment a painless process.

## launch instructions:

### Prerequisites
-Terraform
-Docker
-Git

1. clone repo

`git clone https://github.com/rjprima/Infrastructure-Playground`

2. enter the project directory

`cd Infrastructure-Playground`

3. build docker images
```bash
docker build -t infra-playground/worker ./core/backend
docker build -t infra-playground/cli ./core/frontend
docker build -t infra-playground/nginx-mod ./nginx-config
docker build -t infra-playground/postgres-mod ./postgres-config
```

4. enter terraform module

`cd terraform`

5. run terraform commands
```bash
terraform init
terraform plan
terraform apply
```

6. when ready, stop the system with

`terraform destroy`

### Usage Instructions (once launched)

1. return to project directory

`cd ..`

2. copy your chosen test file in to container
```bash
docker cp core/testing/<input test file here> user_interface:/
docker attach user_interface
```

3. enter 1

4. enter file path

`/<input test file here>`

5. enter database container
in another command line, or exiting the container command line: 

`docker exec -it database psql -U <input chosen username here> -d simplified_expressions -p <input chosen port here>`

6. view entered processed data

`SELECT expr, simplified FROM solved LIMIT 100;`

---