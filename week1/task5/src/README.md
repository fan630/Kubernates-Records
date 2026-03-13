# Task5: Azure AKS + Terraform 完整解決方案

## 🎯 任務目標

使用 **Terraform** 創建 Azure Kubernetes Service (AKS) 集群，並部署指定的 nginx 應用程式：

- **類型**: Deployment 
- **名稱**: web-server 
- **副本數**: 3 
- **標籤**: app: nginx 
- **映像檔**: nginx:1.14.2 
- **容器埠號**: 80
- **Service**: LoadBalancer

## 📁 專案結構

```
task5/src/
├── README.MD                    # 本說明文件
├── variables.tf                 # Terraform 變數定義
├── main.tf                     # 主要 Terraform 配置（AKS 集群）
├── outputs.tf                  # Terraform 輸出定義
├── deployment.yaml             # Kubernetes Deployment 配置
├── service.yaml               # LoadBalancer Service 配置
├── deploy.sh                  # 🚀 自動部署腳本
├── cleanup.sh                 # 🧹 自動清理腳本
└── check-status.sh            # 📊 狀態檢查腳本
```

## 🚀 快速開始

### 前置需求

1. **Azure 帳號**：有效的 Azure 訂閱
2. **工具安裝**：
   ```bash
   # macOS (使用 Homebrew)
   brew install terraform azure-cli kubectl jq
   
   # 直接下載
   # Terraform: https://www.terraform.io/downloads.html
   # Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli
   # kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/
   ```

3. **Azure 登錄**：
   ```bash
   az login
   ```

### 一鍵部署（推薦）

```bash
# 執行自動部署腳本
./deploy.sh
```

該腳本將會：
- ✅ 檢查必要工具是否安裝
- ✅ 驗證 Azure 登錄狀態  
- ✅ 確認部署並顯示成本估算
- ✅ 使用 Terraform 創建 AKS 集群
- ✅ 配置 kubectl 並部署應用程式
- ✅ 等待 LoadBalancer 獲得外部 IP
- ✅ 顯示存取網址和管理指令

### 手動部署步驟

如果您想要逐步控制部署過程：

#### 1. Terraform 初始化和部署
```bash
# 初始化 Terraform
terraform init

# 檢查執行計畫
terraform plan

# 執行部署
terraform apply
```

#### 2. 配置 kubectl
```bash
# 獲取集群憑證
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw kubernetes_cluster_name) \
  --overwrite-existing
```

#### 3. 部署應用程式
```bash
# 部署 Deployment 和 ConfigMap
kubectl apply -f deployment.yaml

# 部署 LoadBalancer Service
kubectl apply -f service.yaml
```

#### 4. 檢查狀態
```bash
# 檢查 Pod 狀態
kubectl get pods -l app=nginx

# 檢查 Service 狀態（等待外部 IP）
kubectl get svc web-server-service -w
```

## 📊 部署後檢查

### 使用狀態檢查腳本
```bash
./check-status.sh
```

### 手動檢查指令
```bash
# 檢查集群狀態
kubectl cluster-info
kubectl get nodes

# 檢查應用程式
kubectl get pods,svc,deploy -l app=nginx

# 獲取外部 IP
kubectl get svc web-server-service

# 測試應用程式
curl http://EXTERNAL_IP
```

## 🌐 存取應用程式

部署完成後，您可以通過以下方式存取 nginx 應用程式：

1. **獲取外部 IP**：
   ```bash
   kubectl get svc web-server-service
   ```

2. **瀏覽器存取**：
   ```
   http://EXTERNAL_IP
   ```

3. **命令列測試**：
   ```bash
   curl http://EXTERNAL_IP
   ```

您應該會看到一個自定義的歡迎頁面，顯示部署資訊和狀態。

## 🔧 管理和監控

### 擴展應用程式
```bash
# 手動擴展到 5 個副本
kubectl scale deployment web-server --replicas=5

# 查看 HPA 狀態（如果啟用）
kubectl get hpa nginx-hpa
```

### 查看日誌
```bash
# 查看所有 Pod 日誌
kubectl logs -l app=nginx

# 即時監控日誌
kubectl logs -l app=nginx -f
```

### 監控資源使用
```bash
# 查看節點資源使用
kubectl top nodes

# 查看 Pod 資源使用  
kubectl top pods -l app=nginx
```

## 🧹 清理資源

### 自動清理（推薦）
```bash
./cleanup.sh
```

### 手動清理
```bash
# 刪除 Kubernetes 資源
kubectl delete -f service.yaml
kubectl delete -f deployment.yaml

# 刪除 Azure 資源
terraform destroy
```

**⚠️ 重要**：請務必清理資源以避免不必要的費用！

## 💰 成本估算

### 預估月費用
- **AKS 控制平面**：免費
- **工作節點 (2x Standard_DS2_v2)**：約 $100-150 USD
- **LoadBalancer**：約 $20-30 USD
- **網路流量**：根據使用量

**總計**：約 $120-200 USD/月

### 節省成本的建議
- 使用 Spot 實例
- 啟用自動擴展
- 定期清理不需要的資源
- 考慮較小的 VM 規格

## 🔒 安全配置

本解決方案包含以下安全功能：

- **RBAC**：啟用角色基礎存取控制
- **Network Policy**：Pod 間網路隔離
- **Resource Limits**：容器資源限制
- **Security Context**：Pod 安全上下文
- **Multi-AZ 部署**：高可用性配置

## 🏗️ 架構概覽

```
┌─────────────────┐    ┌──────────────────┐
│   Azure Portal  │    │    Terraform     │
│                 │    │   Configuration  │
└─────────────────┘    └──────────────────┘
         │                        │
         ▼                        ▼
┌─────────────────────────────────────────────┐
│              Azure AKS Cluster             │
│  ┌─────────────┐  ┌─────────────┐         │
│  │  Node Pool  │  │  Node Pool  │         │
│  │  (System)   │  │  (Worker)   │         │
│  └─────────────┘  └─────────────┘         │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │        Kubernetes Resources         │   │
│  │  - Deployment (nginx:1.14.2)       │   │
│  │  - Service (LoadBalancer)           │   │
│  │  - ConfigMap                        │   │
│  │  - HPA                              │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  LoadBalancer   │ ──── 外部存取
│  (Public IP)    │      http://IP
└─────────────────┘
```

## 🛠️ 故障排除

### 常見問題

1. **Terraform 權限不足**
   ```bash
   # 確認 Azure 登錄狀態
   az account show
   
   # 檢查權限
   az role assignment list --assignee $(az account show --query user.name -o tsv)
   ```

2. **Pod 無法啟動**
   ```bash
   # 檢查 Pod 詳細資訊
   kubectl describe pod -l app=nginx
   
   # 查看事件
   kubectl get events --sort-by=.metadata.creationTimestamp
   ```

3. **LoadBalancer 無法獲得外部 IP**
   ```bash
   # 檢查 Service 詳細資訊
   kubectl describe svc web-server-service
   
   # 檢查 Azure 配額
   az vm list-usage --location "East Asia" -o table
   ```

4. **連接超時**
   ```bash
   # 檢查安全群組規則
   az network nsg list --resource-group MC_*
   
   # 檢查網路連通性
   kubectl run test-pod --image=busybox --rm -it -- wget -qO- web-server-service
   ```

## 📚 參考文檔

- [Azure AKS 官方文檔](https://docs.microsoft.com/azure/aks/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest)
- [Kubernetes 官方文檔](https://kubernetes.io/docs/)
- [Azure CLI 命令參考](https://docs.microsoft.com/cli/azure/)

## 🎉 完成確認清單

部署完成後，您應該能夠：

- ✅ 通過外部 IP 存取 nginx 應用程式
- ✅ 看到 3 個 nginx Pod 正在運行
- ✅ LoadBalancer 顯示 Azure 分配的公共 IP
- ✅ 自定義歡迎頁面正常顯示
- ✅ 能夠擴展應用程式副本數
- ✅ 監控集群和應用程式狀態
- ✅ 成功清理所有資源

**🎉 恭喜！您已成功掌握了 Terraform + Azure AKS 的完整工作流程！**