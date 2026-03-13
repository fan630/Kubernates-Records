#!/bin/bash

# check-status.sh - 檢查 AKS 集群和應用程式狀態
# 用於檢查部署狀態、健康狀況和獲取存取資訊

set -e

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

# 腳本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_FILE="${SCRIPT_DIR}/kubeconfig"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}📊 AKS 集群狀態檢查${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# 檢查 Terraform 狀態
check_terraform() {
    echo -e "${YELLOW}🏗️  Terraform 資源狀態：${NC}"
    
    if [ -f "terraform.tfstate" ]; then
        echo -e "${GREEN}✅ Terraform 狀態文件存在${NC}"
        
        # 顯示主要輸出
        if terraform output &> /dev/null; then
            echo ""
            terraform output
        else
            echo -e "${YELLOW}⚠️  無法讀取 Terraform 輸出${NC}"
        fi
    else
        echo -e "${RED}❌ 找不到 Terraform 狀態文件${NC}"
        echo -e "${YELLOW}   集群可能尚未部署或已被清理${NC}"
        return 1
    fi
}

# 檢查 kubectl 連接
check_kubectl() {
    echo ""
    echo -e "${YELLOW}⚙️  Kubernetes 連接狀態：${NC}"
    
    if [ -f "${KUBECONFIG_FILE}" ]; then
        export KUBECONFIG="${KUBECONFIG_FILE}"
        
        if kubectl cluster-info &> /dev/null; then
            echo -e "${GREEN}✅ 成功連接到 AKS 集群${NC}"
            
            # 顯示集群資訊
            echo ""
            echo -e "${BLUE}集群資訊：${NC}"
            kubectl cluster-info
            
            echo ""
            echo -e "${BLUE}節點狀態：${NC}"
            kubectl get nodes -o wide
            
        else
            echo -e "${RED}❌ 無法連接到 Kubernetes 集群${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ 找不到 kubeconfig 文件${NC}"
        return 1
    fi
}

# 檢查應用程式狀態
check_applications() {
    echo ""
    echo -e "${YELLOW}🎯 應用程式狀態：${NC}"
    
    export KUBECONFIG="${KUBECONFIG_FILE}"
    
    # 檢查 Deployment
    echo -e "${BLUE}Deployment 狀態：${NC}"
    if kubectl get deployment web-server &> /dev/null; then
        kubectl get deployment web-server
        
        # 檢查副本狀態
        local ready_replicas=$(kubectl get deployment web-server -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        local desired_replicas=$(kubectl get deployment web-server -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
        
        if [ "$ready_replicas" = "$desired_replicas" ] && [ "$ready_replicas" != "0" ]; then
            echo -e "${GREEN}✅ Deployment 狀態正常 ($ready_replicas/$desired_replicas 副本就緒)${NC}"
        else
            echo -e "${YELLOW}⚠️  Deployment 狀態異常 ($ready_replicas/$desired_replicas 副本就緒)${NC}"
        fi
    else
        echo -e "${RED}❌ 找不到 web-server deployment${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Pod 狀態：${NC}"
    kubectl get pods -l app=nginx -o wide
    
    echo ""
    echo -e "${BLUE}Service 狀態：${NC}"
    kubectl get svc web-server-service
}

# 檢查 LoadBalancer 和存取資訊
check_loadbalancer() {
    echo ""
    echo -e "${YELLOW}🌐 LoadBalancer 狀態：${NC}"
    
    export KUBECONFIG="${KUBECONFIG_FILE}"
    
    local external_ip=$(kubectl get svc web-server-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -n "$external_ip" ] && [ "$external_ip" != "null" ]; then
        echo -e "${GREEN}✅ LoadBalancer 已獲得外部 IP: ${BLUE}${external_ip}${NC}"
        echo ""
        echo -e "${GREEN}🔗 存取網址：${NC}"
        echo -e "${BLUE}   http://${external_ip}${NC}"
        echo -e "${BLUE}   https://${external_ip}${NC}"
        
        # 測試 HTTP 連接
        echo ""
        echo -e "${YELLOW}🧪 測試 HTTP 連接：${NC}"
        if curl -s --connect-timeout 5 "http://${external_ip}" > /dev/null; then
            echo -e "${GREEN}✅ HTTP 服務正常回應${NC}"
        else
            echo -e "${YELLOW}⚠️  HTTP 服務無法連接（可能還在啟動中）${NC}"
        fi
        
    else
        echo -e "${YELLOW}⚠️  LoadBalancer 尚未獲得外部 IP${NC}"
        echo -e "${YELLOW}   這可能需要幾分鐘時間${NC}"
        
        # 顯示 Service 詳細資訊
        kubectl describe svc web-server-service | grep -E "(LoadBalancer|Events)" -A 5
    fi
}

# 檢查資源使用情況
check_resources() {
    echo ""
    echo -e "${YELLOW}📈 資源使用情況：${NC}"
    
    export KUBECONFIG="${KUBECONFIG_FILE}"
    
    # 節點資源使用
    echo -e "${BLUE}節點資源使用：${NC}"
    kubectl top nodes 2>/dev/null || echo "需要 metrics-server 來顯示資源使用情況"
    
    echo ""
    echo -e "${BLUE}Pod 資源使用：${NC}"
    kubectl top pods -l app=nginx 2>/dev/null || echo "需要 metrics-server 來顯示資源使用情況"
    
    # HPA 狀態（如果啟用）
    echo ""
    echo -e "${BLUE}自動擴展狀態：${NC}"
    if kubectl get hpa nginx-hpa &> /dev/null; then
        kubectl get hpa nginx-hpa
    else
        echo "未啟用 HPA"
    fi
}

# 顯示有用的指令
show_useful_commands() {
    echo ""
    echo -e "${PURPLE}============================================${NC}"
    echo -e "${PURPLE}🔧 有用的管理指令${NC}"
    echo -e "${PURPLE}============================================${NC}"
    
    local external_ip=$(kubectl get svc web-server-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "EXTERNAL_IP")
    
    echo -e "${YELLOW}📋 狀態檢查：${NC}"
    echo "  kubectl get pods,svc,deploy -l app=nginx"
    echo "  kubectl describe pod -l app=nginx"
    echo "  kubectl logs -l app=nginx -f"
    
    echo ""
    echo -e "${YELLOW}🌐 網路測試：${NC}"
    echo "  curl http://${external_ip}"
    echo "  curl -I http://${external_ip}"
    
    echo ""
    echo -e "${YELLOW}📊 監控：${NC}"
    echo "  kubectl top nodes"
    echo "  kubectl top pods -l app=nginx"
    echo "  kubectl get events --sort-by=.metadata.creationTimestamp"
    
    echo ""
    echo -e "${YELLOW}🛠️  管理：${NC}"
    echo "  kubectl scale deployment web-server --replicas=5"
    echo "  kubectl rollout restart deployment web-server"
    echo "  kubectl port-forward svc/web-server-service 8080:80"
    
    echo ""
    echo -e "${YELLOW}🧹 清理：${NC}"
    echo "  ./cleanup.sh"
}

# 主執行流程
main() {
    local error_count=0
    
    check_terraform || ((error_count++))
    check_kubectl || ((error_count++))
    
    if [ $error_count -eq 0 ]; then
        check_applications
        check_loadbalancer
        check_resources
        show_useful_commands
        
        echo ""
        echo -e "${GREEN}🎉 狀態檢查完成！${NC}"
        
        if [ -n "$(kubectl get svc web-server-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)" ]; then
            echo -e "${GREEN}您的 nginx 應用程式正在 AKS 集群中運行 🚀${NC}"
        fi
    else
        echo ""
        echo -e "${RED}❌ 檢查過程中發現 $error_count 個問題${NC}"
        echo -e "${YELLOW}請先運行 ./deploy.sh 部署集群${NC}"
    fi
}

# 執行主函數
main "$@"