#!/bin/bash

# deploy.sh - 自動化部署 AKS 集群和應用程式
# 這個腳本會創建 AKS 集群並部署 nginx 應用程式

set -e  # 遇到錯誤時自動退出

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 腳本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_FILE="${SCRIPT_DIR}/kubeconfig"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}🚀 AKS Terraform 自動化部署腳本${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# 函數：檢查必要工具
check_prerequisites() {
    echo -e "${YELLOW}📋 檢查必要工具...${NC}"
    
    local missing_tools=()
    
    # 檢查 Terraform
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    # 檢查 Azure CLI
    if ! command -v az &> /dev/null; then
        missing_tools+=("azure-cli")
    fi
    
    # 檢查 kubectl
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl") 
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}❌ 缺少必要工具：${missing_tools[*]}${NC}"
        echo -e "${YELLOW}請先安裝這些工具：${NC}"
        echo "  - Terraform: https://www.terraform.io/downloads.html"
        echo "  - Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        echo "  - kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 所有必要工具已安裝${NC}"
}

# 函數：Azure 登錄檢查
check_azure_login() {
    echo -e "${YELLOW}🔐 檢查 Azure 登錄狀態...${NC}"
    
    if ! az account show &> /dev/null; then
        echo -e "${RED}❌ 未登錄 Azure${NC}"
        echo -e "${YELLOW}請執行: ${BLUE}az login${NC}"
        exit 1
    fi
    
    local account_name=$(az account show --query name -o tsv)
    local subscription_id=$(az account show --query id -o tsv)
    
    echo -e "${GREEN}✅ 已登錄 Azure${NC}"
    echo -e "   Account: ${BLUE}${account_name}${NC}"
    echo -e "   Subscription: ${BLUE}${subscription_id}${NC}"
}

# 函數：確認部署
confirm_deployment() {
    echo ""
    echo -e "${YELLOW}⚠️  這將會創建以下 Azure 資源：${NC}"
    echo "   • Resource Group"
    echo "   • AKS 集群 (2-5 個節點)"
    echo "   • Load Balancer"
    echo "   • 相關的網路和儲存資源"
    echo ""
    echo -e "${YELLOW}💰 預估費用：約 $100-200 USD/月${NC}"
    echo ""
    
    read -p "確定要繼續部署嗎？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}部署已取消${NC}"
        exit 0
    fi
}

# 函數：Terraform 初始化和部署
deploy_infrastructure() {
    echo ""
    echo -e "${BLUE}🏗️  開始部署基礎設施...${NC}"
    
    # Terraform 初始化
    echo -e "${YELLOW}Terraform 初始化...${NC}"
    terraform init
    
    # Terraform 計畫
    echo -e "${YELLOW}Terraform 計畫檢查...${NC}"
    terraform plan -out=tfplan
    
    # Terraform 應用
    echo -e "${YELLOW}Terraform 部署執行...${NC}"
    terraform apply tfplan
    
    echo -e "${GREEN}✅ 基礎設施部署完成${NC}"
}

# 函數：配置 kubectl
configure_kubectl() {
    echo ""
    echo -e "${YELLOW}⚙️  配置 kubectl...${NC}"
    
    # 獲取集群名稱和資源群組
    local cluster_name=$(terraform output -raw kubernetes_cluster_name)
    local resource_group=$(terraform output -raw resource_group_name)
    
    # 獲取 AKS 憑證
    az aks get-credentials \
        --resource-group "${resource_group}" \
        --name "${cluster_name}" \
        --overwrite-existing \
        --file "${KUBECONFIG_FILE}"
    
    # 設定 KUBECONFIG 環境變數
    export KUBECONFIG="${KUBECONFIG_FILE}"
    
    # 測試連接
    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}✅ kubectl 配置成功${NC}"
        kubectl get nodes
    else
        echo -e "${RED}❌ kubectl 配置失敗${NC}"
        exit 1
    fi
}

# 函數：部署應用程式
deploy_applications() {
    echo ""
    echo -e "${YELLOW}🚀 部署 nginx 應用程式...${NC}"
    
    # 設定 KUBECONFIG
    export KUBECONFIG="${KUBECONFIG_FILE}"
    
    # 部署 ConfigMap 和 Deployment
    echo -e "${BLUE}部署 Deployment...${NC}"
    kubectl apply -f deployment.yaml
    
    # 部署 Service
    echo -e "${BLUE}部署 LoadBalancer Service...${NC}"
    kubectl apply -f service.yaml
    
    # 等待 Deployment 就緒
    echo -e "${YELLOW}等待 Deployment 就緒...${NC}"
    kubectl wait --for=condition=available --timeout=300s deployment/web-server
    
    # 等待 Service 獲得外部 IP
    echo -e "${YELLOW}等待 LoadBalancer 獲得外部 IP（這可能需要幾分鐘）...${NC}"
    
    local external_ip=""
    local attempts=0
    local max_attempts=20
    
    while [ -z "$external_ip" ] && [ $attempts -lt $max_attempts ]; do
        external_ip=$(kubectl get service web-server-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [ -z "$external_ip" ] || [ "$external_ip" = "null" ]; then
            echo -e "${YELLOW}等待中... ($((attempts+1))/$max_attempts)${NC}"
            sleep 15
            ((attempts++))
        else
            break
        fi
    done
    
    if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
        echo -e "${GREEN}✅ LoadBalancer 已獲得外部 IP: ${BLUE}${external_ip}${NC}"
        echo -e "${GREEN}🌐 您可以通過以下網址存取應用程式：${NC}"
        echo -e "${BLUE}   http://${external_ip}${NC}"
    else
        echo -e "${YELLOW}⚠️  LoadBalancer 尚未獲得外部 IP，請稍後檢查${NC}"
    fi
    
    echo -e "${GREEN}✅ 應用程式部署完成${NC}"
}

# 函數：顯示部署資訊
show_deployment_info() {
    echo ""
    echo -e "${PURPLE}============================================${NC}"
    echo -e "${PURPLE}📊 部署資訊摘要${NC}"
    echo -e "${PURPLE}============================================${NC}"
    
    # 設定 KUBECONFIG
    export KUBECONFIG="${KUBECONFIG_FILE}"
    
    # Terraform 輸出
    echo -e "${YELLOW}🏗️  基礎設施資訊：${NC}"
    terraform output
    
    echo ""
    echo -e "${YELLOW}📋 Kubernetes 資源狀態：${NC}"
    kubectl get pods,svc,deploy -l app=nginx
    
    echo ""
    echo -e "${YELLOW}🔧 有用的指令：${NC}"
    echo "  查看 Pod 狀態: kubectl get pods -l app=nginx"
    echo "  查看 Service: kubectl get svc web-server-service"
    echo "  查看日誌: kubectl logs -l app=nginx"
    echo "  清理資源: ./cleanup.sh"
    
    echo ""
    echo -e "${YELLOW}📝 Kubeconfig 文件位置：${NC}"
    echo "  ${KUBECONFIG_FILE}"
    echo "  使用方式: export KUBECONFIG=${KUBECONFIG_FILE}"
}

# 主執行流程
main() {
    check_prerequisites
    check_azure_login
    confirm_deployment
    deploy_infrastructure
    configure_kubectl
    deploy_applications
    show_deployment_info
    
    echo ""
    echo -e "${GREEN}🎉 AKS Terraform 部署完成！${NC}"
    echo -e "${GREEN}您的 nginx 應用程式現在位於 Azure AKS 集群中${NC}"
}

# 錯誤處理
trap 'echo -e "${RED}❌ 部署過程中發生錯誤${NC}"; exit 1' ERR

# 執行主函數
main "$@"