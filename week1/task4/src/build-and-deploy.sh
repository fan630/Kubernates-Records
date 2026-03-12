#!/bin/bash

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 設定變數（請修改為您的 DockerHub 用戶名）
DOCKERHUB_USERNAME="norriswu2666"
IMAGE_NAME="k8s-pod-lister"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="$DOCKERHUB_USERNAME/$IMAGE_NAME:$IMAGE_TAG"

echo -e "${BLUE}=== 🚀 K8s Pod Lister 部署腳本 ===${NC}"
echo ""

# DockerHub 用戶名已設定為 norriswu2666
echo -e "${GREEN}✅ 使用 DockerHub 用戶名: $DOCKERHUB_USERNAME${NC}"

# 函數：詢問用戶是否繼續
ask_continue() {
    read -p "是否繼續？(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}操作已取消${NC}"
        exit 1
    fi
}

echo -e "${YELLOW}步驟 1: 構建 Docker 映像${NC}"
echo -e "映像名稱: ${FULL_IMAGE_NAME}"
ask_continue

# 構建 Docker 映像
echo -e "${BLUE}正在構建 Docker 映像...${NC}"
docker build -t $FULL_IMAGE_NAME .

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Docker 映像構建失敗${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Docker 映像構建成功${NC}"
echo ""

echo -e "${YELLOW}步驟 2: 推送映像到 DockerHub${NC}"
echo -e "請確保已登入 DockerHub: ${BLUE}docker login${NC}"
ask_continue

# 推送映像到 DockerHub
echo -e "${BLUE}正在推送映像到 DockerHub...${NC}"
docker push $FULL_IMAGE_NAME

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 映像推送失敗，請檢查 Docker 登入狀態${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 映像成功推送到 DockerHub${NC}"
echo ""

echo -e "${YELLOW}步驟 3: 部署 Kubernetes 資源${NC}"
ask_continue

# 更新 Pod 配置中的映像名稱
echo -e "${BLUE}正在更新 Pod 配置文件...${NC}"
sed -i.bak "s/your-dockerhub-username/$DOCKERHUB_USERNAME/g" pod-with-projected-volume.yaml

# 部署 ServiceAccount
echo -e "${BLUE}正在部署 ServiceAccount...${NC}"
kubectl apply -f serviceaccount.yaml

# 部署 RBAC
echo -e "${BLUE}正在部署 RBAC 權限...${NC}"
kubectl apply -f rbac.yaml

# 等待一下讓 ServiceAccount 完全創建
sleep 2

# 部署 Pod
echo -e "${BLUE}正在部署 Pod...${NC}"
kubectl apply -f pod-with-projected-volume.yaml

echo ""
echo -e "${GREEN}🎉 部署完成！${NC}"
echo ""

echo -e "${YELLOW}步驟 4: 驗證部署${NC}"
echo -e "${BLUE}查看 Pod 狀態：${NC}"
kubectl get pod k8s-pod-lister

echo ""
echo -e "${BLUE}等待 Pod 啟動...${NC}"
kubectl wait --for=condition=ready pod/k8s-pod-lister --timeout=60s

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Pod 已就緒！${NC}"
    echo ""
    echo -e "${YELLOW}查看 Pod 日誌：${NC}"
    echo -e "${BLUE}kubectl logs k8s-pod-lister -f${NC}"
    echo ""
    echo -e "${YELLOW}有用的指令：${NC}"
    echo -e "查看即時日誌: ${BLUE}kubectl logs k8s-pod-lister -f${NC}"
    echo -e "檢查 Pod 詳情: ${BLUE}kubectl describe pod k8s-pod-lister${NC}"
    echo -e "進入 Pod 檢查: ${BLUE}kubectl exec -it k8s-pod-lister -- sh${NC}"
    echo -e "查看掛載的 SA token: ${BLUE}kubectl exec k8s-pod-lister -- ls -la /var/run/secrets/kubernetes.io/serviceaccount${NC}"
    echo ""
    echo -e "${GREEN}🎯 Task4 完成！您應該能在日誌中看到 Pod 列表輸出了。${NC}"
else
    echo -e "${RED}❌ Pod 啟動失敗，請檢查日誌：${NC}"
    echo -e "${BLUE}kubectl logs k8s-pod-lister${NC}"
    echo -e "${BLUE}kubectl describe pod k8s-pod-lister${NC}"
fi