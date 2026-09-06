terraform {
    required_providers {
        docker = {
        source  = "kreuzwerker/docker"
        version = "~> 3.0.0"
        }
    }
}

provider "docker" {}

resource "docker_network" "network" {
    name = "mass_simplifier"
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

resource "docker_image" "postgres" {
    name = "infra-playground/postgres-mod:latest"
    keep_locally = true
}

resource "docker_image" "worker" {
    name = "infra-playground/worker:latest"
    keep_locally = true
}

resource "docker_image" "interface" {
    name = "infra-playground/cli:latest"
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

resource "docker_container" "nginx" {
    image = docker_image.nginx.image_id
    name = "router"

    networks_advanced {
        name = docker_network.network.name
    }

    depends_on = [docker_container.worker]
}

resource "docker_container" "postgres" {
    image = docker_image.postgres.image_id
    name = "database"

    networks_advanced {
        name = docker_network.network.name
    }

    env = [
        "POSTGRES_DB=simplified_expressions",
        "POSTGRES_USER=${var.postgres_user}",
        "POSTGRES_PASSWORD=${var.postgres_password}"
    ]

    command = ["postgres", "-p", "${var.postgres_port}"]

    ports {
        internal = var.postgres_port
    }
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
        "USER=${var.postgres_user}"
    ]

    networks_advanced {
        name = docker_network.network.name
    }

    depends_on = [docker_container.postgres]
}

resource "docker_container" "interface" {
    image = docker_image.interface.image_id
    name = "user_interface"

    stdin_open = true
    tty = true

    env = [
        "NGINX_CONT_NAME=router",
        "NGINX_PORT=${var.nginx_port}"
    ]

    networks_advanced {
        name = docker_network.network.name
    }

    depends_on = [docker_container.nginx]
}