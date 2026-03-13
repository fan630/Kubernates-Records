
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
- 選擇語言（Python / Node.js 等）
- 程式邏輯：讀取掛載的 SA Token 與 CA 憑證，呼叫 K8s API `GET /api/v1/namespaces/{namespace}/pods`，將結果格式化成類似 `kubectl get pods` 的表格輸出

### 2. 打包成 Docker Image
- 撰寫 `Dockerfile`
- Build image：`docker build -t <dockerhub-user>/<image-name>:<tag> .`
- Push 到 DockerHub：`docker push <dockerhub-user>/<image-name>:<tag>`

### 3. 設定 RBAC 權限
- 建立 `ServiceAccount`
- 建立 `Role`（允許 `get`、`list` pods）
- 建立 `RoleBinding`（將 Role 綁定到 ServiceAccount）

### 4. 建立 Pod（使用 Projected Volume 掛載 SA Token）
- 撰寫 Pod YAML
- 使用 `projected volume` 將以下三項掛載進 Pod：
  - ServiceAccount Token（`serviceAccountToken`）
  - CA 憑證（`configMap: kube-root-ca.crt`）
  - Namespace 資訊（`downwardAPI`）
- 指定使用剛建立的 ServiceAccount

### 5. 驗證結果
- `kubectl logs <pod-name>`
- 確認 log 中出現類似以下格式的輸出：

```
NAME              READY   STATUS    RESTARTS   AGE
pod-a             1/1     Running   0          10m
pod-b             2/2     Running   1          5m
```

---

