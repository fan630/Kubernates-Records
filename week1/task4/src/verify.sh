#!/bin/bash

# 快速驗證腳本 - 檢查部署狀態和功能
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== 🔍 Task4 驗證檢查 ===${NC}"
echo ""

# 檢查 ServiceAccount
echo -e "${YELLOW}1. 檢查 ServiceAccount...${NC}"
kubectl get serviceaccount pod-reader-sa
echo ""

# 檢查 RBAC
echo -e "${YELLOW}2. 檢查 RBAC 設定...${NC}"
kubectl get role pod-reader-role
kubectl get rolebinding pod-reader-binding
echo ""

# 檢查 Pod 狀態
echo -e "${YELLOW}3. 檢查 Pod 狀態...${NC}"
kubectl get pod k8s-pod-lister
echo ""

# 檢查 Pod 詳細資訊
echo -e "${YELLOW}4. Pod 詳細資訊...${NC}"
kubectl describe pod k8s-pod-lister | grep -A 10 -E "(Status:|Volumes:|Mounts:)"
echo ""

# 檢查 Projected Volume 掛載
echo -e "${YELLOW}5. 檢查 ServiceAccount Token 掛載...${NC}"
kubectl exec k8s-pod-lister -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/ 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ ServiceAccount Token 成功掛載${NC}"
else
    echo -e "${RED}❌ ServiceAccount Token 掛載檢查失敗${NC}"
fi
echo ""

# 檢查程式是否正常運行
echo -e "${YELLOW}6. 檢查應用程式輸出（最近 20 行）...${NC}"
kubectl logs k8s-pod-lister --tail=20
echo ""

echo -e "${BLUE}=== 驗證完成 ===${NC}"
echo -e "${YELLOW}若要查看即時日誌：${NC} kubectl logs k8s-pod-lister -f"
echo -e "${YELLOW}若要清理資源：${NC} kubectl delete pod k8s-pod-lister && kubectl delete -f rbac.yaml && kubectl delete -f serviceaccount.yaml"