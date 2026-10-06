terraform {
    required_providers {
        docker = {
            source  = "kreuzwerker/docker"
            version = "~> 3.0.0"
        }
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
        grafana = {
            source  = "grafana/grafana"
            version = ">= 2.9.0"
        }   
    }
}

provider "docker" {}

provider "grafana" {
    url = "http://localhost:3000"
    auth = "${var.grafana_user}:${var.grafana_pass}"
}

provider "aws" {
    region = "us-west-1"
    access_key = "mock_key"
    secret_key = "mock_secret"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    s3_use_path_style = true

    endpoints {
        s3 = "http://localhost:4566"
    }
}

resource "docker_network" "network" {
    name = "mass_simplifier"
}

resource "docker_volume" "container_logs" {
    name = "container_logs"
}

resource "docker_image" "aws" {
    name = "localstack/localstack:latest"
    keep_locally = true
}

resource "docker_image" "alpine" {
    name = "alpine:latest"
    keep_locally = true
}

resource "docker_image" "alloy" {
    name = "infra-playground/alloy-mod:latest"
    keep_locally = true
}

resource "docker_image" "grafana" {
    name = "infra-playground/grafana-mod:latest"
    keep_locally = true
}

resource "docker_image" "nginx" {
    name = "infra-playground/nginx-mod:latest"
    keep_locally = true

    triggers = {
        vars = sha256(jsonencode({
            worker_port = var.worker_port
            worker_count = var.worker_count
            nginx_port = var.nginx_port
        }))
        tmpl = filesha256("${path.module}/../nginx-config/nginx.conf.tftpl")
    }

    build {
        context = "${path.module}/../nginx-config"
        dockerfile = "dockerfile"
    }

    depends_on = [local_file.nginx_conf_template]
}

resource "docker_image" "nginx_node" {
    name = "nginx/nginx-prometheus-exporter:latest"
    keep_locally = true
}

resource "docker_image" "postgres" {
    name = "infra-playground/postgres-mod:latest"
    keep_locally = true
}

resource "docker_image" "postgres_node" {
    name = "prometheuscommunity/postgres-exporter:latest"
}

resource "docker_image" "worker" {
    name = "infra-playground/worker:latest"
    keep_locally = true
}

resource "docker_image" "interface" {
    name = "infra-playground/cli:latest"
    keep_locally = true
}

resource "docker_image" "backup_scheduler" {
    name = "infra-playground/backup-scheduler"
    keep_locally = true
}

resource "docker_image" "prometheus" {
    name = "prom/prometheus"
    keep_locally = true
}

resource "docker_image" "loki" {
    name = "grafana/loki"
    keep_locally = true
}

resource "local_file" "nginx_conf_template" {
    content = templatefile("${path.cwd}/../nginx-config/nginx.conf.tftpl", {
        worker_count = var.worker_count
        worker_port = var.worker_port
        nginx_port = var.nginx_port
    })
    filename = "${path.cwd}/../nginx-config/default.conf"
}

resource "docker_container" "aws" {
    image = docker_image.aws.image_id
    name  = "s3-emulator"

    networks_advanced {
        name = docker_network.network.name
    }

    command = [
        "sh", "-c",
        "docker-entrypoint.sh 2>&1 | tee -a /var/log/container_logs/s3-emulator/s3-emulator.log"
    ]

    volumes {
        volume_name = docker_volume.container_logs.name
        container_path = "/var/log/container_logs"
    }

    depends_on = [docker_container.alloy, time_sleep.init_sleep]

    env = [
        "DEBUG=1",
        "GATEWAY_LISTENER=0.0.0.0:4566",
        "LOCALSTACK_AUTH_TOKEN=${var.localstack_auth}"
    ]
}

resource "docker_container" "nginx" {
    image = docker_image.nginx.image_id
    name = "router"
    
    networks_advanced {
        name = docker_network.network.name
    }

    /*command = [
        "sh", "-c",
        "mkdir -p /var/log/cotainer_logs/router && exec nginx -g 'daemon off;'"
    ]*/

    volumes {
        volume_name = docker_volume.container_logs.name
        container_path = "/var/log/container_logs"
    }

    depends_on = [docker_container.worker, docker_container.alloy, time_sleep.init_sleep]
}

resource "docker_container" "nginx_node" {
    image = docker_image.nginx_node.image_id
    name = "router_node"

    command = [
        "--nginx.scrape-uri=http://router:8080/stub_status"
    ]

    networks_advanced {
        name = docker_network.network.name
    }

    depends_on = [docker_container.nginx]
}

resource "docker_container" "container_logs_init" {
    image = docker_image.alpine.image_id
    name = "container_logs_init"
    must_run = false

    networks_advanced {
        name = docker_network.network.name
    }

    volumes {
        volume_name = docker_volume.container_logs.name
        container_path = "/var/log/container_logs"
    }

    entrypoint = [
        "sh", "-c",
        "mkdir -p /var/log/container_logs/s3-emulator && mkdir -p /var/log/container_logs/router && mkdir -p /var/log/container_logs/database && mkdir -p /var/log/container_logs/worker && mkdir -p /var/log/container_logs/user_interface && mkdir -p /var/log/container_logs/backup-script && mkdir -p /var/log/container_logs/grafana && mkdir -p /var/log/container_logs/prometheus && chmod -R 777 /var/log/container_logs"
    ]
}

resource "time_sleep" "init_sleep" {
    depends_on = [docker_container.container_logs_init]
    create_duration = "3s"
}

resource "docker_container" "postgres" {
    image = docker_image.postgres.image_id
    name = "database"

    networks_advanced {
        name = docker_network.network.name
    }

    volumes {
        volume_name = docker_volume.container_logs.name
        container_path = "/var/log/container_logs"
    }

    depends_on = [docker_container.alloy, time_sleep.init_sleep]

    env = [
        "POSTGRES_DB=simplified_expressions",
        "POSTGRES_USER=${var.postgres_user}",
        "POSTGRES_PASSWORD=${var.postgres_password}"
    ]

    command = [
        "postgres",
        "-p", "${var.postgres_port}",
        "-c", "logging_collector=on",
        "-c", "log_directory=/var/log/container_logs/database",
        "-c", "log_filename=database.log",
        "-c", "log_statement=all",
        "-c", "log_destination=stderr",
        "-c", "log_truncate_on_rotation=off"
    ]

    ports {
        internal = var.postgres_port
    }
}

resource "docker_container" "postgres_node" {
    image = docker_image.postgres_node.image_id
    name = "database_node"

    env = ["DATA_SOURCE_NAME=postgresql://${var.postgres_user}:${var.postgres_password}@database:${var.postgres_port}/postgres?sslmode=disable"]

    networks_advanced {
        name = docker_network.network.name
    }

    depends_on = [docker_container.postgres]
}

resource "docker_container" "worker" {
    count = var.worker_count

    name  = "worker-${count.index}"
    image = docker_image.worker.image_id

    env = [
        "POSTGRES_CONT_NAME=database",
        "POSTGRES_PORT=${var.postgres_port}",
        "POSTGRES_PASSWORD=${var.postgres_password}",
        "PORT=${var.worker_port}",
        "USER=${var.postgres_user}",
        "WORKERID=${count.index}"
    ]

    command = ["sh", "-c", "exec python batch_runtime.py 2>&1 | tee -a /var/log/container_logs/worker/worker-$WORKERID.log"]

    networks_advanced {
        name = docker_network.network.name
    }

    volumes {
        volume_name = docker_volume.container_logs.name
        container_path = "/var/log/container_logs"
    }

    depends_on = [docker_container.postgres, docker_container.alloy, time_sleep.init_sleep]
}

resource "docker_container" "interface" {
    image = docker_image.interface.image_id
    name = "user_interface"

    stdin_open = true
    tty = true

    env = [
        "NGINX_CONT_NAME=router",
        "NGINX_PORT=${var.nginx_port}",
        "HEALTH_PORT=${var.interface_health_port}"
    ]

    networks_advanced {
        name = docker_network.network.name
    }

    volumes {
        volume_name = docker_volume.container_logs.name
        container_path = "/var/log/container_logs"
    }

    depends_on = [docker_container.nginx, docker_container.alloy, time_sleep.init_sleep]
}

resource "docker_container" "backup_scheduler" {
    image = docker_image.backup_scheduler.image_id
    name = "backup-script"

    networks_advanced {
        name = docker_network.network.name
    }

    volumes {
        volume_name = docker_volume.container_logs.name
        container_path = "/var/log/container_logs"
    }

    depends_on = [docker_container.postgres, docker_container.aws, docker_container.alloy, time_sleep.init_sleep]

    env = [
        "postgres_user=${var.postgres_user}",
        "postgres_port=${var.postgres_port}",
        "PGPASSWORD=${var.postgres_password}",
        "worker_count=${var.worker_count}",
        "worker_port=${var.worker_port}"
    ]
}

resource "docker_container" "grafana" {
    image = docker_image.grafana.image_id
    name = "grafana"

    networks_advanced {
        name = docker_network.network.name
    }

    upload {
        content = file("${path.module}/../Grafana-configs/Grafana-config/dashboard.json")
        file = "/var/lib/grafana/dashboards/dashboard.json"
    }

    upload {
        content = file("${path.module}/../Grafana-configs/Grafana-config/dashboards.yaml")
        file = "/etc/grafana/provisioning/dashboards/dashboards.yaml"
    }

    env = [
        "GF_LOG_MODE=console file",
        "GF_LOG_FILE_PATH=/var/log/container_logs/grafana/grafana.log"
    ]

    volumes {
        volume_name = docker_volume.container_logs.name
        container_path = "/var/log/container_logs"
    }

    depends_on = [docker_container.prometheus, docker_container.loki, docker_container.alloy, time_sleep.init_sleep]

    ports {
        internal = 3000
        external = 3000
    }
}

resource "docker_container" "prometheus" {
    image = docker_image.prometheus.image_id
    name = "prometheus"

    networks_advanced {
        name = docker_network.network.name
    }

    entrypoint = ["sh", "-c"]
    command = [
        "mkdir -p /var/log/container_logs/prometheus && /bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --web.enable-remote-write-receiver 2>&1 | tee -a /var/log/container_logs/prometheus/prometheus.log"
    ]

    volumes {
        volume_name = docker_volume.container_logs.name
        container_path = "/var/log/container_logs"
    }

    depends_on = [docker_container.alloy, time_sleep.init_sleep]
}

resource "docker_container" "loki" {
    image = docker_image.loki.image_id
    name = "loki"

    networks_advanced {
        name = docker_network.network.name
    }

    upload {
        content = file("${path.module}/../Grafana-configs/Loki-config/loki-config.yaml")
        file    = "/etc/loki/loki-config.yaml"
    }

    command = [
        "-config.file=/etc/loki/loki-config.yaml",
    ]

    depends_on = [docker_container.alloy, time_sleep.init_sleep]
}

resource "docker_container" "alloy" {
    image = docker_image.alloy.image_id
    name = "alloy"

    networks_advanced {
        name = docker_network.network.name
    }

    volumes {
        volume_name = docker_volume.container_logs.name
        container_path = "/var/log/container_logs"
        read_only = true
    }

    ports {
        internal = 5140
        external = 5140
        ip = "127.0.0.1"
    }

    depends_on = [time_sleep.init_sleep]
}

resource "grafana_data_source" "prometheus" {
    type = "prometheus"
    name = "Prometheus"
    url = "http://prometheus:9090"
    is_default = true
    uid = "Prometheus"

    json_data_encoded = jsonencode({
        httpMethod        = "POST"
        timeInterval      = "15s"
        prometheusVersion = "2.45.0"
    })

    depends_on = [time_sleep.wait_for_grafana]
}

resource "grafana_data_source" "loki" {
    type = "loki"
    name = "Loki"
    url = "http://loki:3100"
    uid = "Loki"

    json_data_encoded = jsonencode({
        maxLines = 1000
    })

    depends_on = [time_sleep.wait_for_grafana]
}

resource "time_sleep" "wait_for_grafana" {
    depends_on = [docker_container.grafana]
    create_duration = "15s"
}