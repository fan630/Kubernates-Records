# 任務說明

使用 ConfigMap 掛載 Volume 的方式，將 Nginx 設定檔掛載進 Container，讓你不需自行 Build image 也能調整 Nginx 設定。

請部署一個 Nginx Deployment，Nginx 需將請求反向代理到你自己寫的 Web Service Pod（Deployment）。

你要驗證 Web Service 能否透過 Headless Service 連線到 Redis（如 redis-0 pod），並存取資料。

請在 Cluster 內測試 DNS 解析，說明如何確保能存取第一個 Pod，並解釋 Headless 與 ClusterIP 的差異。

嘗試用 Secret 定義 redis 使用者資料，讓 Web Service Pod 透過 ENV 取得連線資訊。

---

# Task6 - Nginx ConfigMap 反向代理 + Redis StatefulSet

## Part 1 - Nginx ConfigMap 掛載反向代理

### 架構

```
你寫的 nginx.conf
      │
      │ 存進 ConfigMap
      ▼
ConfigMap `nginx-config`
      │
      │ 掛載成 Volume 到 /etc/nginx/conf.d/
      ▼
Nginx Pod（nginx-proxy Deployment，官方 image）
      │
      │ 讀取這個 conf 做 proxy_pass
      ▼
Web Service Pod（web-service Deployment）
```

### 資源說明

| 檔案             | 資源                        | 說明                                   |
|------------------|-----------------------------|----------------------------------------|
| nginx.yaml       | ConfigMap `nginx-config`    | 存放 `default.conf`，設定 proxy_pass   |
| nginx.yaml       | Deployment `nginx-proxy`    | 官方 nginx image，掛載 ConfigMap       |
| nginx.yaml       | Service `nginx-proxy-service` | LoadBalancer，對外暴露 port 80      |
| web-service.yaml | Deployment `web-service`    | 實際處理請求的 HTTP 後端 Pod           |
| web-service.yaml | Service `web-service`       | ClusterIP，供 Nginx 存取 Web Service   |

> **為什麼還需要 web-service 這個 Service？**  
> Nginx 需透過 Kubernetes Service 存取 Web Service Pod，才能實現負載均衡與服務發現。直接寫 Pod IP 會因 Pod 重建導致 IP 改變而失效。Service 提供穩定入口，確保 Nginx 能正確轉發流量給後端 Pod。

### 部署

```bash
kubectl apply -f web-service.yaml
kubectl apply -f nginx.yaml
```

### 驗證

```bash
# 確認 ConfigMap 掛載內容
kubectl exec -it <nginx-proxy-pod> -- cat /etc/nginx/conf.d/default.conf

# minikube 開隧道測試
minikube service nginx-proxy-service
# 預期回應: Hello from Web Service Pod!
```

---

## Part 2 - Redis StatefulSet with PersistentVolume

使用 Redis Image 部署一個 Redis StatefulSet（2 replicas），並掛載 PV 確保狀態持久性。

你需驗證 Web Service 能否透過 Headless Service 連線到 Redis（如 redis-0 pod），並存取資料。

### 什麼是 Headless Service？

Headless Service 是一種 `clusterIP: None` 的 Service，不分配虛擬 IP，DNS 查詢會直接解析為後端 Pod 的實際 IP。適合需要直接存取單一 Pod 的場景（如 StatefulSet、資料庫主從架構等）。

**DNS 解析差異：**

| 服務類型            | DNS 回應                  | 存取方式與特性                                 |
|---------------------|---------------------------|------------------------------------------------|
| ClusterIP Service   | 回傳 Service 虛擬 IP      | 流量經由 Service 負載均衡到後端 Pod            |
| Headless Service    | 回傳所有 Pod 的實際 IP    | 可直接連線到單一 Pod，適合 StatefulSet 等場景   |

**範例：**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
spec:
  clusterIP: None
  selector:
    app: redis
  ports:
    - port: 6379
```
這樣設定後，`redis-0.redis.default.svc.cluster.local` 會對應到 redis-0 Pod 的 IP。

### 架構

```
redis-0 (Pod)          redis-1 (Pod)
    │                       │
    │ mountPath: /data      │ mountPath: /data
    ▼                       ▼
PVC: redis-data-redis-0   PVC: redis-data-redis-1
    │                       │
    ▼                       ▼
PV (自動佈建)              PV (自動佈建)
```

### 為什麼用 StatefulSet 而不是 Deployment

|                | Deployment           | StatefulSet                |
|----------------|---------------------|----------------------------|
| Pod 名稱       | 隨機                 | 固定且有序（redis-0, 1）   |
| PVC            | 共用同一個           | 每個 Pod 有自己的 PVC      |
| 啟動順序       | 同時啟動             | 依序啟動                   |
| 適合場景       | 無狀態服務           | 有狀態服務（DB、Cache）     |

**適用場景：**  
需要固定 Pod 名稱、獨立持久化儲存、有序操作等有狀態應用。

### 資源說明

| 檔案                  | 資源                        | 說明                                  |
|-----------------------|-----------------------------|---------------------------------------|
| redis-statefulset.yaml| Service `redis` (Headless)  | clusterIP: None，Pod 有獨立 DNS       |
| redis-statefulset.yaml| StatefulSet `redis`         | 2 replicas，啟用 AOF 持久化            |
| redis-statefulset.yaml| volumeClaimTemplates        | 每個 Pod 自動建立專屬 PVC             |

### 部署

```bash
kubectl apply -f redis-statefulset.yaml
```

### 驗證

```bash
# 確認 Pod（名稱固定為 redis-0, redis-1）
kubectl get pods -l app=redis

# 確認每個 Pod 各有一個 PVC
kubectl get pvc

# 進到 Web Service Pod 裡面，用 redis-cli 連到 redis-0 並存取資料
kubectl get pods -l app=web-service
kubectl exec -it <web-service-pod> -- sh
redis-cli -h redis-0.redis.default.svc.cluster.local
set foo bar
get foo
```

也可連到 redis-1：
```bash
redis-cli -h redis-1.redis.default.svc.cluster.local
set foo bar
get foo
```

---

## Part 3 - DNS 解析與 Headless/ClusterIP 差異

你可以進入 web-service Pod，直接測試 DNS 解析與連線：

```bash
kubectl exec -it <web-service-pod> -- sh
# 測試 DNS 解析
getent hosts redis-0.redis.default.svc.cluster.local
# 或
python3 -c "import socket; print(socket.gethostbyname('redis-0.redis.default.svc.cluster.local'))"

# 連線到 redis-0
redis-cli -h redis-0.redis.default.svc.cluster.local
```

這樣可確保能存取第一個 Pod（redis-0），因 Headless Service 會為每個 Pod 產生獨立 DNS 名稱。

**Headless Service 與 ClusterIP 差異：**

| 服務類型            | DNS 回應                         | 存取方式與特性                                                                 |
|---------------------|----------------------------------|-------------------------------------------------------------------------------|
| ClusterIP Service   | 回傳 Service 虛擬 IP              | 流量經由 Service 負載均衡到後端 Pod，無法直接指定特定 Pod，適合無狀態服務           |
| Headless Service    | 回傳所有 Pod 的實際 IP，或 `<pod-name>.<service-name>.<namespace>.svc.cluster.local` 解析到特定 Pod | 可直接連線到單一 Pod，適合 StatefulSet、有狀態服務、需要節點親和性的場景           |

**總結：**  
Headless Service 讓每個 Pod 都有獨立且可預期的 DNS 名稱（如 `redis-0.redis.default.svc.cluster.local`），適合分散式資料庫、主從架構、分片集群等場景，應用程式可直接連線到特定節點，實現資料分片、主從同步或節點健康檢查等功能。

---

## Part 4 - Secret 定義 Redis 使用者資料

嘗試用 Secret 定義 redis 使用者資料，讓 Web Service Pod 透過 ENV 取得連線資訊。

### 為什麼要用 Secret？

密碼不能直接寫在 YAML 裡，否則上傳到 Git 就等於公開密碼。Secret 讓敏感資料與設定分離，Pod 啟動時再從 Secret 取得。

### Secret 內容

`redis-secret.yaml` 定義了三個欄位：

```yaml
stringData:
  REDIS_HOST: "redis-0.redis.default.svc.cluster.local"
  REDIS_PORT: "6379"
  REDIS_PASSWORD: "myRedisP@ssw0rd"
```

> `stringData` 允許直接寫明文，不需要自己 base64 encode。若改用 `data` 屬性，則必須先自行 encode 再填入。兩者最終都以 base64 存進 etcd。

### StatefulSet 如何使用 Secret

`redis-statefulset.yaml` 的 Pod spec 中，透過 `secretKeyRef` 將 Secret 的值注入為環境變數：

```yaml
env:
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: redis-secret
      key: REDIS_PASSWORD
```

啟動指令再引用這個環境變數：

```yaml
command:
- redis-server
- "--requirepass"
- "$(REDIS_PASSWORD)"
```

這樣密碼完全不出現在 YAML 裡，只在執行時由 K8s 注入。

### 部署順序

Secret 必須比 StatefulSet 先建立，否則 Pod 啟動時找不到 Secret 會失敗：

```bash
kubectl apply -f redis-secret.yaml
kubectl apply -f redis-statefulset.yaml
```

### 驗證

```bash
# 確認 Secret 已建立
kubectl get secret redis-secret

# 確認 Pod 的環境變數有正確注入（不會顯示明文，但可確認 key 存在）
kubectl exec -it redis-0 -- env | grep REDIS
```

結過驗證後，Web Service Pod 就能透過環境變數取得 Redis 連線資訊，並成功連線到 Redis。

```
REDIS_PASSWORD=myRedisP@ssw0rd
REDIS_VERSION=7.4.8
REDIS_DOWNLOAD_URL=http://download.redis.io/releases/redis-7.4.8.tar.gz
REDIS_DOWNLOAD_SHA=f6773cb7d63be236c59c2917a82f1f08e47b77d89b2f0c9f53becb22b8ea4172
```