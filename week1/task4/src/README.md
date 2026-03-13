
# 任務
在某些狀況下，你會希望 Pod 可以透過跟 api-server 溝通，存取其他資源或是進行一些特別的操作。
預設情況下，Pod 並不具備這些權限。

這時候你就會需要 ServiceAccount(SA)，service account 就類似給 Pod 一個虛擬身份的概念，透過 RBAC 的方式綁定權限後，Pod 可以藉此取得臨時甚至永久憑證，來進行 k8s api 的呼叫。

嘗試參考 https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/ 及 https://kubernetes.io/docs/concepts/security/service-accounts/
使用任何程式語言（Python、Node.js...）編寫程式，該程式嘗試呼叫 k8s api，取得特定 namespace 內的 Pod 列表。將該程式打包成 Image，並 push 到 public 的 dockerhub registry。
使用該 image 創建 Pod，並使用 Projected Volume 的方式，將 SA token 掛載到 Pod 中。
最終，你應該要能在 Pod 的 log 中查看到類似 kubectl get pod 的這種列表內容。
範例輸出（不用一樣沒關係）：
－－－
pod list in default namespace:

pod-abc
nginx
xxx

## 任務目標
在 Kubernetes Pod 內，透過掛載的 ServiceAccount Token，呼叫 K8s API 取得特定 namespace 的 Pod 列表，並在 log 中顯示出來。

---

## 步驟拆解

### 1. 撰寫程式
- 使用 Node.js（`app.js`）
- 讀取 projected volume 掛載的三個檔案：
  - `/var/run/secrets/kubernetes.io/serviceaccount/token` — SA token（身份憑證）
  - `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt` — CA 憑證（驗證 api-server）
  - `/var/run/secrets/kubernetes.io/serviceaccount/namespace` — 當前 namespace
- 用 token 打 `https://kubernetes.default.svc/api/v1/namespaces/{namespace}/pods`
- 印出所有 pod 名稱

### 2. 打包成 Docker Image
- 撰寫 `Dockerfile`，base image 使用 `node:18-alpine`
```bash
docker build -t norriswu2666/norris-test:latest .
docker push norriswu2666/norris-test:latest
```

### 3. 設定 RBAC 權限
- 在 `rbac.yaml` 中定義三個資源：
  - `ServiceAccount`：名稱 `pod-lister`
  - `Role`：允許 `get`、`list` pods
  - `RoleBinding`：將 Role 綁定到 `pod-lister` ServiceAccount
```bash
kubectl apply -f rbac.yaml
```

### 4. 建立 Pod（使用 Projected Volume 掛載 SA Token）
- 在 `pod-with-projected-volume.yaml` 中，使用 `projected volume` 將以下三項掛載進 Pod：
  - ServiceAccount Token（`serviceAccountToken`）
  - CA 憑證（`configMap: kube-root-ca.crt`）
  - Namespace 資訊（`downwardAPI`）
- 指定 `serviceAccountName: pod-lister`
```bash
kubectl apply -f pod-with-projected-volume.yaml
```

### 5. 驗證結果
```bash
kubectl logs pod-lister
```

實際輸出：
```
pod list in default namespace:

k8s-pod-lister
pod-lister
web-server-5d6d4f65-8cx7g
web-server-5d6d4f65-sddf2
web-server-5d6d4f65-xfhkv
```

---

