# variables.tf - Terraform 變數定義
# 允許自定義配置來適應不同環境和需求

variable "resource_group_name" {
  description = "Azure Resource Group 名稱"
  type        = string
  default     = "rg-aks-terraform-demo"
}

variable "location" {
  description = "Azure 區域位置"
  type        = string
  default     = "East Asia"

  validation {
    condition = contains([
      "East Asia", "Southeast Asia", "East US", "East US 2",
      "West US", "West US 2", "Central US", "West Europe",
      "North Europe"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

variable "cluster_name" {
  description = "AKS 集群名稱"
  type        = string
  default     = "aks-terraform-cluster"

  validation {
    condition     = length(var.cluster_name) <= 63 && can(regex("^[a-zA-Z0-9-]+$", var.cluster_name))
    error_message = "Cluster name must be 63 characters or less and contain only letters, numbers, and hyphens."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes 版本"
  type        = string
  default     = "1.35"
}

variable "node_count" {
  description = "Worker 節點數量"
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 10
    error_message = "Node count must be between 1 and 10."
  }
}

variable "node_vm_size" {
  description = "Worker 節點 VM 大小"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "enable_auto_scaling" {
  description = "是否啟用自動擴展"
  type        = bool
  default     = true
}

variable "min_count" {
  description = "自動擴展最小節點數"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "自動擴展最大節點數"
  type        = number
  default     = 5
}

variable "dns_prefix" {
  description = "AKS DNS 前綴"
  type        = string
  default     = "aks-terraform"
}

variable "tags" {
  description = "資源標籤"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "Kubernetes-Learning"
    CreatedBy   = "Terraform"
    Task        = "Task5-AKS-Demo"
  }
}
