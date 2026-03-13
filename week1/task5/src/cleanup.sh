#!/bin/bash

# cleanup.sh - 自動清理 AKS 集群和相關資源
# 這個腳本會刪除所有通過 Terraform 創建的資源

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
echo -e "${BLUE}🧹 AKS Terraform 資源清理腳本${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# 函數：檢查 Terraform 狀態
check_terraform_state() {
    echo -e "${YELLOW}📋 檢查 Terraform 狀態...${NC}"
    
    if [ ! -f "terraform.tfstate" ]; then
        echo -e "${YELLOW}⚠️  找不到 terraform.tfstate 文件${NC}"
        echo -e "${YELLOW}可能沒有需要清理的資源，或資源已被清理${NC}"
        
        read -p "是否繼續清理可能存在的資源？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}清理已取消${NC}"
            exit 0
        fi
    fi
    
    # 檢查是否有資源
    if terraform show &> /dev/null; then
        echo -e "${GREEN}✅ 找到 Terraform 狀態${NC}"
        echo ""
        echo -e "${YELLOW}目前的資源：${NC}"
        terraform show -json | jq -r '.values.root_module.resources[]? | "\(.type): \(.values.name // .values.id // "unnamed")"' 2>/dev/null || terraform show
    else
        echo -e "${YELLOW}⚠️  無法讀取 Terraform 狀態${NC}"
    fi
}

# 函數：確認清理
confirm_cleanup() {
    echo ""
    echo -e "${RED}⚠️  警告：這將會刪除所有相關資源！${NC}"
    echo -e "${YELLOW}將被刪除的資源包括：${NC}"
    echo "   • AKS 集群（包括所有運行的工作負載）"
    echo "   • Resource Group（包括所有子資源）"
    echo "   • Load Balancer"
    echo "   • 虛擬機器"
    echo "   • 網路介面"
    echo "   • 儲存帳戶"
    echo "   • 所有相關的 Azure 資源"
    echo ""
    echo -e "${RED}💰 這些資源一旦刪除無法復原！${NC}"
    echo ""
    
    # 雙重確認
    read -p "您確定要刪除所有資源嗎？請輸入 'yes' 確認: " confirm
    if [ "$confirm" != "yes" ]; then
        echo -e "${YELLOW}清理已取消${NC}"
        exit 0
    fi
    
    echo ""
    read -p "最後確認：真的要刪除所有資源？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}清理已取消${NC}"
        exit 0
    fi
}

# 函數：清理 Kubernetes 資源（如果集群還在）
cleanup_k8s_resources() {
    echo -e "${YELLOW}🗑️  清理 Kubernetes 資源...${NC}"
    
    if [ -f "${KUBECONFIG_FILE}" ]; then
        export KUBECONFIG="${KUBECONFIG_FILE}"
        
        # 檢查集群是否還存在
        if kubectl cluster-info &> /dev/null; then
            echo -e "${BLUE}刪除應用程式資源...${NC}"
            
            # 刪除 Service（這會釋放 LoadBalancer）
            kubectl delete -f service.yaml --ignore-not-found=true || true
            
            # 等待 LoadBalancer 釋放
            echo -e "${YELLOW}等待 LoadBalancer 資源釋放...${NC}"
            sleep 30
            
            # 刪除 Deployment 和 ConfigMap
            kubectl delete -f deployment.yaml --ignore-not-found=true || true
            
            # 刪除其他可能的資源
            kubectl delete hpa nginx-hpa --ignore-not-found=true || true
            kubectl delete networkpolicy nginx-network-policy --ignore-not-found=true || true
            
            echo -e "${GREEN}✅ Kubernetes 資源清理完成${NC}"
        else
            echo -e "${YELLOW}⚠️  無法連接到集群，可能已被刪除${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  找不到 kubeconfig 文件${NC}"
    fi
}

# 函數：Terraform 清理
cleanup_terraform() {
    echo ""
    echo -e "${YELLOW}🏗️  開始 Terraform 資源清理...${NC}"
    
    # 嘗試 Terraform destroy
    echo -e "${BLUE}執行 terraform destroy...${NC}"
    
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo -e "${YELLOW}嘗試 #${attempt}/${max_attempts}...${NC}"
        
        if terraform destroy -auto-approve; then
            echo -e "${GREEN}✅ Terraform 資源清理成功${NC}"
            break
        else
            echo -e "${RED}❌ 嘗試 #${attempt} 失敗${NC}"
            
            if [ $attempt -lt $max_attempts ]; then
                echo -e "${YELLOW}等待 30 秒後重試...${NC}"
                sleep 30
            fi
            
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        echo -e "${RED}❌ Terraform destroy 失敗${NC}"
        echo -e "${YELLOW}可能需要手動清理一些資源${NC}"
        
        # 顯示剩餘資源
        echo -e "${YELLOW}檢查剩餘資源...${NC}"
        terraform show 2>/dev/null || echo "無法顯示剩餘資源"
        
        return 1
    fi
}

# 函數：清理本地文件
cleanup_local_files() {
    echo ""
    echo -e "${YELLOW}🗑️  清理本地文件...${NC}"
    
    local files_to_remove=(
        "terraform.tfstate"
        "terraform.tfstate.backup"
        "tfplan"
        "kubeconfig"
        ".terraform"
        ".terraform.lock.hcl"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [ -e "$file" ]; then
            rm -rf "$file"
            echo -e "${GREEN}✅ 已刪除: ${file}${NC}"
        fi
    done
}

# 函數：手動清理指導（如果 Terraform 失敗）
manual_cleanup_guide() {
    echo ""
    echo -e "${YELLOW}📋 手動清理指導：${NC}"
    echo ""
    echo -e "${BLUE}如果自動清理失敗，您可以通過 Azure Portal 手動清理：${NC}"
    echo "1. 登入 Azure Portal (https://portal.azure.com)"
    echo "2. 搜尋並進入 Resource Groups"
    echo "3. 找到以 'rg-aks-terraform-demo' 開頭的資源群組"
    echo "4. 點選該資源群組並點選 'Delete resource group'"
    echo "5. 輸入資源群組名稱確認刪除"
    echo ""
    echo -e "${BLUE}或使用 Azure CLI：${NC}"
    
    if command -v az &> /dev/null; then
        local resource_groups=$(az group list --query "[?contains(name, 'rg-aks-terraform-demo')].name" -o tsv 2>/dev/null || echo "")
        if [ -n "$resource_groups" ]; then
            echo "發現的資源群組："
            echo "$resource_groups" | while read -r rg; do
                echo -e "${RED}  az group delete --name \"$rg\" --yes --no-wait${NC}"
            done
        else
            echo -e "${YELLOW}  未找到相關資源群組${NC}"
        fi
    fi
}

# 函數：驗證清理結果
verify_cleanup() {
    echo ""
    echo -e "${YELLOW}🔍 驗證清理結果...${NC}"
    
    # 檢查 Azure 資源 
    if command -v az &> /dev/null && az account show &> /dev/null; then
        local remaining_rgs=$(az group list --query "[?contains(name, 'rg-aks-terraform-demo')].name" -o tsv 2>/dev/null || echo "")
        
        if [ -n "$remaining_rgs" ]; then
            echo -e "${YELLOW}⚠️  發現剩餘的資源群組：${NC}"
            echo "$remaining_rgs"
        else
            echo -e "${GREEN}✅ 所有 Azure 資源群組已清理${NC}"
        fi
    fi
    
    # 檢查本地狀態
    local local_files_left=()
    if [ -f "terraform.tfstate" ]; then local_files_left+=("terraform.tfstate"); fi
    if [ -d ".terraform" ]; then local_files_left+=(".terraform/"); fi
    if [ -f "kubeconfig" ]; then local_files_left+=("kubeconfig"); fi
    
    if [ ${#local_files_left[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ 所有本地文件已清理${NC}"
    else
        echo -e "${YELLOW}⚠️  剩餘本地文件：${local_files_left[*]}${NC}"
    fi
}

# 主執行流程
main() {
    check_terraform_state
    confirm_cleanup
    cleanup_k8s_resources
    cleanup_terraform
    
    if [ $? -eq 0 ]; then
        cleanup_local_files
        verify_cleanup
        
        echo ""
        echo -e "${GREEN}🎉 資源清理完成！${NC}"
        echo -e "${GREEN}所有 Azure 資源和本地文件已被刪除${NC}"
    else
        manual_cleanup_guide
        
        echo ""
        echo -e "${YELLOW}⚠️  自動清理部分失敗${NC}"
        echo -e "${YELLOW}請參考上方的手動清理指導${NC}"
    fi
}

# 錯誤處理
trap 'echo -e "${RED}❌ 清理過程中發生錯誤${NC}"' ERR

# 執行主函數
main "$@"