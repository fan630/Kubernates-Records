# outputs.tf - Terraform 輸出定義
# 顯示創建完成後的重要資訊

output "resource_group_name" {
  description = "Resource Group 名稱"
  value       = azurerm_resource_group.main.name
}

output "kubernetes_cluster_name" {
  description = "AKS 集群名稱"
  value       = azurerm_kubernetes_cluster.main.name
}

output "kubernetes_cluster_id" {
  description = "AKS 集群 ID"
  value       = azurerm_kubernetes_cluster.main.id
}

output "location" {
  description = "Azure 區域位置"
  value       = azurerm_resource_group.main.location
}

output "kubernetes_version" {
  description = "Kubernetes 版本"
  value       = azurerm_kubernetes_cluster.main.kubernetes_version
}

output "node_resource_group" {
  description = "節點 Resource Group 名稱"
  value       = azurerm_kubernetes_cluster.main.node_resource_group
}

output "fqdn" {
  description = "AKS 集群 FQDN"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "kube_config_raw" {
  description = "Kubernetes 配置文件內容"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "client_certificate" {
  description = "Kubernetes 客戶端證書"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Kubernetes 客戶端私鑰"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "集群 CA 證書"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "host" {
  description = "Kubernetes API 服務器地址"
  value       = azurerm_kubernetes_cluster.main.kube_config[0].host
  sensitive   = true
}

# 連接指令
output "connect_command" {
  description = "連接到集群的指令"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name} --overwrite-existing"
}

# 清理指令
output "cleanup_command" {
  description = "清理資源的指令"
  value       = "terraform destroy -auto-approve"
}

# 成本估算提示
output "cost_estimate_info" {
  description = "成本估算資訊"
  value = {
    node_count    = var.node_count
    vm_size       = var.node_vm_size
    estimated_monthly_cost = "約 $100-200 USD (取決於使用量和區域)"
    cost_saving_tips = [
      "使用 spot instances 可節省成本",
      "啟用自動擴展避免過度配置",
      "定期檢查和刪除不需要的資源",
      "考慮使用較小的 VM 規格進行測試"
    ]
  }
}