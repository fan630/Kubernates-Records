# main.tf - 主要 Terraform 配置文件
# 創建 Azure AKS 集群及相關資源

terraform {
  required_version = ">= 1.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# 配置 Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# 生成隨機 ID 用於唯一命名
resource "random_id" "suffix" {
  byte_length = 4
}

# 創建 Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.resource_group_name}-${random_id.suffix.hex}"
  location = var.location
  tags     = var.tags
}

# 創建 AKS 集群
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.cluster_name}-${random_id.suffix.hex}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.dns_prefix}-${random_id.suffix.hex}"
  kubernetes_version  = var.kubernetes_version

  # 預設節點池配置
  default_node_pool {
    name                = "system"
    node_count          = var.node_count
    vm_size            = var.node_vm_size
    type               = "VirtualMachineScaleSets"
    zones              = ["1", "2", "3"]  # 多可用區部署
    enable_auto_scaling = var.enable_auto_scaling
    min_count          = var.enable_auto_scaling ? var.min_count : null
    max_count          = var.enable_auto_scaling ? var.max_count : null
    
    # 節點標籤和污點
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = "demo"
      "nodepoolos"    = "linux"
    }
    
    # 啟用節點公共 IP（用於 LoadBalancer 服務）
    enable_node_public_ip = false
    
    # OS 配置
    os_disk_size_gb = 128
    os_disk_type    = "Managed"
    
    tags = var.tags
  }

  # Service Principal / Managed Identity 配置
  identity {
    type = "SystemAssigned"
  }

  # 網路配置
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
    
    # Pod 和 Service CIDR 配置
    pod_cidr       = "10.244.0.0/16"
    service_cidr   = "10.0.0.0/16"
    dns_service_ip = "10.0.0.10"
    
    # Docker bridge CIDR
    docker_bridge_cidr = "172.17.0.1/16"
  }

  # RBAC 配置
  role_based_access_control_enabled = true

  # Azure Policy 附加組件（可選）
  azure_policy_enabled = false

  # HTTP 應用程式路由（不建議生產使用）
  http_application_routing_enabled = false

  # 私有集群配置（設為 false 以便外部訪問）
  private_cluster_enabled = false

  # API Server 訪問配置
  api_server_access_profile {
    authorized_ip_ranges = ["0.0.0.0/0"]  # 允許所有 IP 訪問（僅用於測試）
  }

  # 自動升級配置
  automatic_channel_upgrade = "patch"

  # 維護視窗配置
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [22, 23]
    }
  }

  tags = var.tags

  # 生命週期管理
  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# 創建額外的工作節點池（可選）
resource "azurerm_kubernetes_cluster_node_pool" "worker" {
  name                  = "worker"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size              = "Standard_DS2_v2"
  node_count           = 1
  
  enable_auto_scaling = true
  min_count          = 1
  max_count          = 3
  
  # 節點標籤和污點
  node_labels = {
    "nodepool-type" = "worker"
    "environment"   = "demo"
  }
  
  # 污點配置（讓某些 Pod 只能調度到特定節點）
  # node_taints = ["workload=demo:NoSchedule"]
  
  zones = ["1", "2", "3"]
  
  tags = var.tags
}

# 獲取 AKS 集群的 kubeconfig
resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.main]
  filename   = "${path.module}/kubeconfig"
  content    = azurerm_kubernetes_cluster.main.kube_config_raw
  
  provisioner "local-exec" {
    command = "chmod 600 ${path.module}/kubeconfig"
  }
}