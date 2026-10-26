terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# Las credenciales se leen de ~/.aws/credentials (perfil "default"),
# que se rellena con el bloque "AWS CLI" de AWS Academy (AWS Details).
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Proyecto = "Almi-Chain Reto 1"
      Gestion  = "Terraform"
    }
  }
}
