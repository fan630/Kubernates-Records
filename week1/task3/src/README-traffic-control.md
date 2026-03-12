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

## 🎭 Demo 腳本

一鍵演示流量控制：

```bash
#!/bin/bash
echo "=== 演示：Readiness Probe 流量控制 ==="

# 1. 查看初始狀態
echo "📊 初始狀態："
kubectl get pods -l app=nginx
kubectl get endpoints web-server-svc

# 2. 選擇第一個 Pod 並停止其流量
POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')
echo "🚫 停止 Pod $POD_NAME 的流量..."
kubectl exec $POD_NAME -- rm -f /tmp/traffic-enabled

# 等待 readiness probe 檢查
echo "⏱️  等待 Readiness Probe 檢查..."
sleep 10

# 3. 查看結果
echo "📊 停止流量後狀態："
kubectl get pods -l app=nginx
kubectl get endpoints web-server-svc

# 4. 恢復流量
echo "✅ 恢復 Pod $POD_NAME 的流量..."
kubectl exec $POD_NAME -- sh -c 'echo "ready" > /tmp/traffic-enabled'

# 等待 readiness probe 檢查
echo "⏱️  等待 Readiness Probe 檢查..."
sleep 10

# 5. 查看最終結果
echo "📊 恢復流量後狀態："
kubectl get pods -l app=nginx
kubectl get endpoints web-server-svc

echo "🎉 演示完成！"
```

---

## 💡 優點

1. **細粒度控制**：可以精確控制單個 Pod 的流量
2. **非破壞性**：Pod 和應用服務繼續運行，只是不接收新請求
3. **即時性**：流量切換速度快（5秒內生效）
4. **可逆性**：隨時可以恢復流量
5. **監控友好**：透過 kubectl 可以清楚看到狀態變化

---

## 🔧 進階配置

### 自定義檢查頻率
修改 readinessProbe 參數：
```yaml
readinessProbe:
  periodSeconds: 2      # 2秒檢查一次（更快響應）
  failureThreshold: 2   # 失敗2次才移除流量（減少誤判）
```

### 使用 HTTP 端點而非文件
```yaml
readinessProbe:
  httpGet:
    path: /health/ready  # 自定義健康檢查端點
    port: 80
```

這樣您的應用可以通過返回不同的 HTTP 狀態碼來控制流量！