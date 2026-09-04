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
  name = "nginx:latest"
  keep_locally = true
}

resource "docker_image" "postgres" {
    name = "postgres:latest"
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

resource "docker_container" "nginx" {
    image = docker_image.ngninx.image_id
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
        "POSTGRES_USER=super",
        "POSTGRES_PASSWORD=${postgres_password}"
    ]

    command = ["postgres", "-p", "${postgres_port}"]

    ports {
        internal = postgres_port
    }
}

resource "docker_container" "worker" {
    count = worker_count

    name  = "worker-${count.index}"
    image = docker_image.worker.image_id

    env = [
        "POSTGRES_CONT_NAME=database",
        "POSTGRES_PORT=${postgres_port}",
        "POSTGRESS_PASSWORD=${postgres_password}",
        "PORT=${worker_port}"
    ]

    networks_advanced {
        name = docker_network.network.name
    }

    depends_on = [docker_container.postgres]
}

resource "docker_container" "interface" {
    image = docker_image.interface.image_id
    name = "user_interface"

    env = [
        "NGINX_CONT_NAME=router",
        "NGINX_PORT=${nginx_port}"
    ]

    networks_advanced {
        name = docker_network.network.name
    }

    depends_on = [docker_container.nginx]
}