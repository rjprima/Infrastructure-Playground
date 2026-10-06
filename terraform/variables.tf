variable "worker_count" {
    type = number
}

variable "worker_port" {
    type = number
}

variable "interface_health_port" {
    type = number
}

variable "postgres_port" {
    type = number
}

variable "postgres_password" {
    type = string
}

variable "postgres_user" {
    type = string
}

variable "nginx_port" {
    type = number
}

variable "localstack_auth" {
    type = string
    sensitive = true
}

variable "grafana_user" {
    type = string
    sensitive = true
}

variable "grafana_pass" {
    type = string
    sensitive = true
}