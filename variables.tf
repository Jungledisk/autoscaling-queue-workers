#

variable "ssh_keys_bucket" {
    default = "my_totes_bucket"
}

variable "ssh_keys_prefix" {
    default = "ssh_keys"
}

variable "ssh_keys_update_cron" {
    default = "*/5 * * * *"
}

variable "ansible_bucket" {
    default = "my_totes_bucket"
}

variable "ansible_prefix" {
    default = "ansible"
}

variable "ansible_vault_file" {
    default = "ansible_vaults/worker"
}

variable "region" {
    default = "us-west-2"
}

variable "environment" {
    default = "seppuku-servers"
}

variable "tags" {
    type = "map"
    default = {
        "Terraform" = "true"
        "Environment" = "seppuku-servers"
    }
}

variable "cidr" {
    default = "10.120.0.0/16"
}

variable "private_subnets" {
    default = []
}

variable "public_subnets" {
    default = ["10.120.101.0/24", "10.120.102.0/24"]
}

variable "azs" {
    default = ["us-west-2a", "us-west-2b"]
}

variable "aws_profile" {
    default = "default"
}

variable "worker_instance_type" {
    default = "t2.micro"
}
