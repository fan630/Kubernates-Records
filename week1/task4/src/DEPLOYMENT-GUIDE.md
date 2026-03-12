# Task4 完整解決方案：Node.js + ServiceAccount + Projected Volume

## 🎯 任務目標
使用 Node.js 編寫程式呼叫 Kubernetes API 取得特定 namespace 內的 Pod 列表，並使用 **Projected Volume** 方式掛載 ServiceAccount token。

## 📁 文件結構
```
task4/src/
├── app.js                          # Node.js 主程式
├── package.json                    # Node.js 依賴配置
├── Dockerfile                      # Docker 容器化配置
├── serviceaccount.yaml             # ServiceAccount 配置
├── rbac.yaml                       # RBAC 權限配置
├── pod-with-projected-volume.yaml  # Pod 配置（使用 Projected Volume）
├── build-and-deploy.sh             # 自動化部署腳本
├── verify.sh                       # 驗證腳本
└── DEPLOYMENT-GUIDE.md             # 本說明文件
```

## 🚀 部署步驟

### 前置需求
- Docker 已安裝並登入 DockerHub
- kubectl 已設定並連接到 Kubernetes 集群
- 有 DockerHub 帳號

### 手動部署步驟

#### 1. 修改映像名稱
編輯 `build-and-deploy.sh` 和 `pod-with-projected-volume.yaml`：
```bash
# 將 'your-dockerhub-username' 替換為您的 DockerHub 用戶名
```

#### 2. 構建並推送 Docker 映像
```bash
# 構建映像
docker build -t your-dockerhub-username/k8s-pod-lister:latest .

# 登入 DockerHub（如尚未登入）
docker login

# 推送映像
docker push your-dockerhub-username/k8s-pod-lister:latest
```

#### 3. 部署 Kubernetes 資源
```bash
# 部署 ServiceAccount
kubectl apply -f serviceaccount.yaml

# 部署 RBAC 權限
kubectl apply -f rbac.yaml

# 部署 Pod（使用 Projected Volume）
kubectl apply -f pod-with-projected-volume.yaml
```

### 自動化部署
```bash
# 修改 build-and-deploy.sh 中的 DOCKERHUB_USERNAME
# 然後執行自動化腳本
./build-and-deploy.sh
```

## 🔍 驗證部署

### 使用驗證腳本
```bash
./verify.sh
```

### 手動驗證步驟

#### 1. 檢查 Pod 狀態
```bash
kubectl get pod k8s-pod-lister
```

#### 2. 查看 Pod 日誌
```bash
kubectl logs k8s-pod-lister -f
```

**期望輸出範例：**
```
🚀 開始呼叫 Kubernetes API...
📋 正在取得 namespace 'default' 內的 Pod 列表...

=== Pod list in default namespace ===

1. k8s-pod-lister (Running) ✅
2. web-server-5d6d4f65-8cx7g (Running) ✅
3. web-server-5d6d4f65-sddf2 (Running) ✅

📊 Total: 3 pod(s) found.
```

#### 3. 檢查 ServiceAccount Token 掛載
```bash
kubectl exec k8s-pod-lister -- ls -la /var/run/secrets/kubernetes.io/serviceaccount/
```

**期望輸出：**
```
total 12
drwxrwxrwt 3 root root  140 Mar 12 09:30 .
drwxr-xr-x 3 root root 4096 Mar 12 09:30 ..
-rw-r--r-- 1 root root 1090 Mar 12 09:30 ca.crt
-rw-r--r-- 1 root root    7 Mar 12 09:30 namespace
-rw-r--r-- 1 root root 1234 Mar 12 09:30 token
```

#### 4. 驗證 RBAC 權限
```bash
kubectl auth can-i get pods --as=system:serviceaccount:default:pod-reader-sa
kubectl auth can-i list pods --as=system:serviceaccount:default:pod-reader-sa
```

## 🔧 關鍵技術點

### 1. Projected Volume 配置
```yaml
volumes:
- name: service-account-token
  projected:
    sources:
    - serviceAccountToken:      # SA Token
        path: token
        expirationSeconds: 3600
    - configMap:               # CA 證書
        name: kube-root-ca.crt
        items:
        - key: ca.crt
          path: ca.crt
    - downwardAPI:             # Namespace 資訊
        items:
        - path: namespace
          fieldRef:
            fieldPath: metadata.namespace
```

### 2. Node.js Kubernetes Client 使用
```javascript
const kc = new k8s.KubeConfig();
kc.loadFromCluster();  // 從集群內環境載入配置
const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
```

### 3. RBAC 最小權限原則
- **Role**: 只允許 `get` 和 `list` pods
- **RoleBinding**: 只綁定到特定 ServiceAccount
- **Namespace 範圍**: 限制在 default namespace

## 🛠️ 故障排除

### Pod 無法啟動
```bash
kubectl describe pod k8s-pod-lister
kubectl logs k8s-pod-lister
```

### 權限錯誤
```bash
kubectl get role pod-reader-role
kubectl get rolebinding pod-reader-binding
kubectl describe rolebinding pod-reader-binding
```

### 映像拉取失敗
- 檢查 DockerHub 映像是否 public
- 確認映像名稱是否正確

## 🧹 清理資源
```bash
kubectl delete pod k8s-pod-lister
kubectl delete -f rbac.yaml
kubectl delete -f serviceaccount.yaml
```

## 💡 進階功能

### 環境變數配置
- `TARGET_NAMESPACE`: 設定要查詢的 namespace
- `RUN_ONCE`: 設為 'true' 只執行一次

### 安全性增強
- 使用非 root 用戶運行
- 資源限制設定
- Token 過期時間控制

## 🎉 任務完成檢查表

- ✅ Node.js 程式能成功呼叫 Kubernetes API
- ✅ 使用 Projected Volume 掛載 ServiceAccount token  
- ✅ RBAC 權限正確設定
- ✅ 能在 Pod 日誌中看到 Pod 列表
- ✅ 映像成功推送到 public DockerHub repository
- ✅ Pod 能持續運行並定期輸出結果