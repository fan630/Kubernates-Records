#!/bin/bash

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== 🎭 Task1 Deployment Readiness Probe 流量控制演示 ===${NC}"
echo ""
echo -e "${GREEN}📋 本演示基於現有的 Task1 Deployment，透過滾動更新添加 Readiness Probe 功能${NC}"
echo ""

# 檢查 kubectl 是否可用
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl 未安裝或不可用${NC}"
    exit 1
fi

# 檢查集群連接
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ 無法連接到 Kubernetes 集群${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kubernetes 集群連接正常${NC}"
echo ""

# 1. 更新現有的 deployment（添加 Readiness Probe）
echo -e "${YELLOW}📦 更新現有 Deployment 添加 Readiness Probe...${NC}"
echo -e "${BLUE}使用 task1 的現有 Deployment 配置${NC}"

# 套用 task1 的更新配置
kubectl apply -f ../../../task1/src/deployment.yaml

# 等待滾動更新完成
echo -e "${YELLOW}⏱️  等待滾動更新完成...${NC}"
kubectl rollout status deployment/web-server

# 等待滾動更新完成
echo -e "${YELLOW}⏱️  等待滾動更新完成...${NC}"
kubectl rollout status deployment/web-server

# 等待新 Pod 就緒
echo -e "${YELLOW}⏱️  等待新 Pod 就緒...${NC}"
kubectl wait --for=condition=ready pod -l app=nginx --timeout=120s

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Pod 啟動超時，請檢查配置${NC}"
    exit 1
fi

# 2. 檢查 Service 是否存在，如果不存在則創建
if ! kubectl get svc web-server-svc &> /dev/null; then
    echo -e "${YELLOW}📋 創建 Service...${NC}"
    cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-server-svc
  labels:
    app: nginx
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
EOF
else
    echo -e "${GREEN}✅ Service 已存在${NC}"
fi

echo ""
echo -e "${BLUE}=== 📊 初始狀態 ===${NC}"
echo -e "${YELLOW}Pod 狀態：${NC}"
kubectl get pods -l app=nginx

echo ""
echo -e "${YELLOW}Service Endpoints：${NC}"
kubectl get endpoints web-server-svc

# 獲取第一個 Pod 名稱
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$POD_NAME" ]; then
    echo -e "${RED}❌ 找不到可用的 Pod${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}=== 🚫 停止流量測試 ===${NC}"
echo -e "${YELLOW}停止 Pod ${POD_NAME} 的流量...${NC}"

# 停止 Pod 流量
kubectl exec $POD_NAME -- rm -f /tmp/traffic-enabled 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 成功刪除流量開關文件${NC}"
else
    echo -e "${RED}❌ 無法刪除流量開關文件，請手動檢查${NC}"
fi

# 等待 readiness probe 檢查
echo -e "${YELLOW}⏱️  等待 Readiness Probe 檢查 (10秒)...${NC}"
sleep 10

echo ""
echo -e "${BLUE}=== 📊 停止流量後狀態 ===${NC}"
echo -e "${YELLOW}Pod 狀態 (注意 READY 欄位)：${NC}"
kubectl get pods -l app=nginx

echo ""
echo -e "${YELLOW}Service Endpoints (該 Pod 應該被移除)：${NC}"
kubectl get endpoints web-server-svc

echo ""
echo -e "${BLUE}=== ✅ 恢復流量測試 ===${NC}"
echo -e "${YELLOW}恢復 Pod ${POD_NAME} 的流量...${NC}"

# 恢復 Pod 流量
kubectl exec $POD_NAME -- sh -c 'echo "ready" > /tmp/traffic-enabled' 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 成功創建流量開關文件${NC}"
else
    echo -e "${RED}❌ 無法創建流量開關文件，請手動檢查${NC}"
fi

# 等待 readiness probe 檢查
echo -e "${YELLOW}⏱️  等待 Readiness Probe 檢查 (10秒)...${NC}"
sleep 10

echo ""
echo -e "${BLUE}=== 📊 恢復流量後狀態 ===${NC}"
echo -e "${YELLOW}Pod 狀態：${NC}"
kubectl get pods -l app=nginx

echo ""
echo -e "${YELLOW}Service Endpoints：${NC}"
kubectl get endpoints web-server-svc

echo ""
echo -e "${GREEN}🎉 演示完成！${NC}"
echo ""
echo -e "${BLUE}=== 🔍 手動測試指令 ===${NC}"
echo -e "${YELLOW}停止流量：${NC}"
echo "  kubectl exec $POD_NAME -- rm -f /tmp/traffic-enabled"
echo ""
echo -e "${YELLOW}恢復流量：${NC}"
echo "  kubectl exec $POD_NAME -- sh -c 'echo \"ready\" > /tmp/traffic-enabled'"
echo ""
echo -e "${YELLOW}查看狀態：${NC}"
echo "  kubectl get pods -l app=nginx"
echo "  kubectl get endpoints web-server-svc"