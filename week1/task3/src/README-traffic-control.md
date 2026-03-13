# 使用 Readiness Probe 控制單個 Pod 流量

## 🎯 創意解決方案原理

這個解決方案使用 **Readiness Probe** + **流量開關文件** 的方式來控制 Pod 流量：

- **Readiness Probe 檢查**：容器內的 `/tmp/traffic-enabled` 文件
- **文件存在** → Pod 接收流量（在 Service 中）
- **文件不存在** → Pod 不接收流量（從 Service 中移除），但 Pod 和 Nginx 服務依然運行

---

## 📝 部署步驟

### 1. 更新現有 Task1 Deployment
```bash
# 套用更新後的 task1 配置（已添加 Readiness Probe）
kubectl apply -f ../task1/src/deployment.yaml

# 等待滾動更新完成
kubectl rollout status deployment/web-server

# 檢查 Pod 狀態
kubectl get pods -l app=nginx
```

### 2. 部署 Service（如果尚未部署）
```bash
kubectl apply -f service.yaml
```

---

## 🚦 流量控制操作

### 停止特定 Pod 的流量

1. **查看目前的 Pod**
```bash
kubectl get pods -l app=nginx
```

2. **選擇要停止流量的 Pod（例如：web-server-xxx-001）**
```bash
# 進入 Pod
kubectl exec -it <pod-name> -- /bin/bash

# 刪除流量開關文件
rm /tmp/traffic-enabled

# 退出 Pod
exit
```

3. **確認 Pod 狀態**
```bash
# 觀察 Pod 的 READY 狀態會變成 0/1
kubectl get pods -l app=nginx

# 檢查 Service endpoints（該 Pod IP 會被移除）
kubectl get endpoints web-server-svc
```

### 恢復 Pod 流量

```bash
# 進入之前停止流量的 Pod
kubectl exec -it <pod-name> -- /bin/bash

# 重新創建流量開關文件
echo "ready" > /tmp/traffic-enabled

# 退出 Pod
exit
```

幾秒後，該 Pod 會重新出現在 Service endpoints 中，開始接收流量。

---

## 🔍 驗證方法

### 1. 檢查 Readiness Probe 狀態
```bash
# 查看 Pod 詳細資訊
kubectl describe pod <pod-name>

# 查找 Readiness 相關事件
kubectl describe pod <pod-name> | grep -i readiness
```

### 2. 查看 Service Endpoints
```bash
# 查看哪些 Pod 正在接收流量
kubectl get endpoints web-server-svc

# 實時監控 endpoints 變化
kubectl get endpoints web-server-svc -w
```

### 3. 測試流量分發
```bash
# 如果有設定 NodePort 或 LoadBalancer
# 重複請求查看是否該 Pod 不再接收請求
for i in {1..10}; do curl <service-url>; echo "---"; done
```

---

