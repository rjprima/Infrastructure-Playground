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

Observability layer: Promtail → Loki → Grafana
```

| Component | Role |
|---|---|
| Ingest container | Accepts and validates input files |
| Nginx | Load balances requests across worker containers |
| Worker containers | Process calculation batches |
| Postgres | Data persistence |
| LocalStack S3 | Simulates AWS S3 for session backups |
| Loki / Promtail / Grafana | Centralized logging and monitoring |

## Tech Stack

* **Containerization:** Docker / Docker Compose
* **Load Balancing:** Nginx
* **Database:** PostgreSQL
* **Cloud Emulation:** LocalStack (S3)
* **Infrastructure as Code:** Terraform
* **Configuration Management:** Ansible
* **CI/CD:** GitHub Actions
* **Observability:** Loki, Promtail, Grafana
* **Application Layer:** Python

## Roadmap

- [x] Core application logic (ingest → route → process → persist)
- [ ] Terraform provisioning
- [ ] Ansible configuration management
- [ ] LocalStack S3 backup integration
- [ ] GitHub Actions CI/CD (builds, registry push, linting)
- [ ] Observability stack (Promtail, Loki, Grafana)
- [ ] Automated teardown and rebuild testing (`terraform destroy` / `terraform apply`)

## Key Objectives

* **Infrastructure as Code:** Define, provision, and destroy the full environment reproducibly using Terraform.
* **Configuration Management:** Automate post-provisioning setup with Ansible.
* **Networking & Load Balancing:** Implement service discovery and traffic management via Nginx.
* **CI/CD:** Automate container builds, registry pushes, and checks with GitHub Actions.
* **Observability:** Aggregate and visualize logs across all services using Loki, Promtail, and Grafana.
* **Local Cloud Emulation:** Test cloud integrations locally with LocalStack S3.

*(Complete IaC launch instructions will be added once Terraform and Ansible configurations are finalized.)*

---

**Contact:** [Your Name] · [LinkedIn] · [Email]
