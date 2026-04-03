# 任務說明


使用 ConfigMap 掛載 Volume 的方式，將 Nginx 設定檔掛載進 Container 當中，如此一來，你不需要自己 Build image 便可以調整 Nginx 的設定。

請部署一個 Nginx deployment，Nginx 將請求轉發至你自己寫的 Web Service Pod（Deployment）。

您需要驗證你的 Web Service 能夠使用 Headless Service 連線到 Redis 上（例如 redis-0 pod），並存取資料。

你可以嘗試在 Cluster 內做 DNS 解析的測試，說明你要怎麼確保你可以存取第一個 Pod，以及 Headless 跟 ClusterIP 有何差別，請說明。

嘗試使用 Secret 定義 redis 使用者資料，讓 Web Service Pod 可以透過掛載 ENV 去取得連線資訊。

# Task6 - Nginx ConfigMap 反向代理 + Redis StatefulSet

## Part 1 - Nginx ConfigMap 掛載反向代理

### 架構

```
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

| 檔案 | 資源 | 說明 |
|------|------|------|
| 檔案 | 資源 | 說明 |
|------|------|------|
| nginx.yaml | ConfigMap `nginx-config` | 存放 `default.conf`，設定 proxy_pass |
| nginx.yaml | Deployment `nginx-proxy` | 官方 nginx image，掛載 ConfigMap |
| nginx.yaml | Service `nginx-proxy-service` | LoadBalancer，對外暴露 port 80 |
| web-service.yaml | Deployment `web-service` | 實際處理請求的 HTTP 後端 Pod |
| web-service.yaml | Service `web-service` | 提供 ClusterIP，讓 Nginx 透過叢集網路存取 Web Service Pod |

> 為什麼還需要 web-service 這個 Service？
>
> 雖然已經有 web-service 的 Deployment，但 Nginx 需要透過 Kubernetes Service 來存取 Web Service Pod，這樣才能實現負載均衡與服務發現。如果直接寫 Pod IP，會因為 Pod 可能重建導致 IP 改變而失效。Service 提供穩定的存取入口，確保 Nginx 能正確轉發流量給後端 Pod。
>
> 架構上，外部請求會先進入對外暴露的 nginx-proxy-service（LoadBalancer），再由 Nginx 反向代理轉發到 web-service 這個 ClusterIP Service，最後流量才會到實際的 Web Service Pod。這樣設計可以讓 Nginx 集中處理流量與代理，web-service Service 則負責將流量分配給多個後端 Pod，確保彈性與高可用性。

### 部署

```bash
kubectl apply -f web-service.yaml
kubectl apply -f nginx.yaml
```

### 驗證

```bash
# 確認 ConfigMap 掛載內容
<!--
此命令用於進入正在運行的 nginx-proxy Pod，並查看其 Nginx 配置文件（/etc/nginx/conf.d/default.conf）的內容。這有助於調試或確認 Nginx 的實際配置。
-->
kubectl exec -it <nginx-proxy-pod> -- cat /etc/nginx/conf.d/default.conf

# minikube 開隧道測試
minikube service nginx-proxy-service
# 預期回應: Hello from Web Service Pod!
```

---

## Part 2 - Redis StatefulSet with PersistentVolume

另外，使用 Redis Image 部署一個 Redis StatefulSet(2 replicas)，並且掛載 PV 確保其狀態持久性。

您需要驗證你的 Web Service 能夠使用 Headless Service 連線到 Redis 上（例如 redis-0 pod），並存取資料。

### 什麼是 Headless Service？

Headless Service 是一種特殊的 Kubernetes Service，其 `clusterIP` 設為 `None`。這種 Service 不會分配一個虛擬 IP（ClusterIP），而是直接將 DNS 查詢解析為後端 Pod 的實際 IP 位址。這讓用戶端可以直接與特定 Pod 通訊，而不是經過 Service 負載均衡。

**用途：**
- 適合需要直接存取單一 Pod（如 StatefulSet、資料庫主從架構、分散式系統等）。
- 支援 Pod 之間的點對點通訊，或讓應用程式能辨識每個 Pod 的獨立性。

**DNS 解析差異：**
- **ClusterIP Service**：DNS 只會回傳 Service 的虛擬 IP，流量由 Service 負責負載均衡到後端 Pod。
- **Headless Service**：DNS 會回傳所有符合 selector 的 Pod IP（A/AAAA 記錄），用戶端可直接選擇要連線的 Pod。

**範例：**
```yaml
apiVersion: v1
kind: Service
metadata:
      name: redis
spec:
      clusterIP: None  # 這就是 Headless Service
      selector:
            app: redis
      ports:
            - port: 6379
```
這樣設定後，`redis-0.redis.default.svc.cluster.local` 會直接對應到 redis-0 Pod 的 IP，方便 StatefulSet 內部彼此通訊。

### 架構

```
redis-0 (Pod)          redis-1 (Pod)
    │                       │
    │ mountPath: /data       │ mountPath: /data
    ▼                       ▼
PVC: redis-data-redis-0   PVC: redis-data-redis-1
    │                       │
    ▼                       ▼
PV (自動佈建)              PV (自動佈建)
```

### 為什麼用 StatefulSet 而不是 Deployment

| | Deployment | StatefulSet |
|---|---|---|
| Pod 名稱 | 隨機 (redis-7d9f-xxx) | 固定且有序 (redis-0, redis-1) |
| PVC | 共用同一個 | 每個 Pod 有自己的 PVC |
| 啟動順序 | 同時啟動 | 依序啟動 (redis-0 → redis-1) |
| 適合場景 | 無狀態服務 | 有狀態服務（DB、Cache） |

### 什麼時候需要用到 StatefulSet？

StatefulSet 適用於需要「有狀態」特性的應用場景，主要包括：

- **需要穩定且唯一的網路標識（Pod 名稱、DNS）**  
      例如分散式資料庫（如 Redis、MongoDB、Cassandra）、ZooKeeper、Kafka 等，每個節點都需要固定的名稱和網路位址來進行彼此通訊或資料同步。

- **每個 Pod 需要專屬的持久化儲存（PVC）**  
      像資料庫、快取等服務，每個 Pod 都有自己的資料卷，重啟或重建時能保留原本的資料。

- **需要有序部署、縮放、升級或終止**  
      某些應用（如主從架構、分片集群）需要依序啟動或關閉 Pod，確保服務正確運作。

- **Pod 之間有狀態依賴或需要穩定身份識別**  
      例如主從複製、分片、叢集選舉等場景。

總結：只要你的應用需要「固定 Pod 名稱」、「獨立持久化儲存」或「有序操作」，就應該選擇 StatefulSet，而不是 Deployment。


### 資源說明



| 檔案 | 資源 | 說明 |
|------|------|------|
| redis-statefulset.yaml | Service `redis` (Headless) | clusterIP: None，讓每個 Pod 有獨立 DNS |
| redis-statefulset.yaml | StatefulSet `redis` | 2 replicas，啟用 AOF 持久化 |
| redis-statefulset.yaml | volumeClaimTemplates | 每個 Pod 自動建立專屬 PVC |

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
# 進到 Web Service Pod 裡面，用 redis-cli 連到 redis-0 並存取資料：

<!--
<!--
說明：
直接透過 Headless Service 連線到指定的 Redis Pod（如 redis-0），是為了讓 Web Service 可以與特定的 Redis 節點進行通訊，而非經由傳統的負載均衡（如 nginx）。這樣做的原因包括：

1. 節點親和性（Node Affinity）：某些應用場景下，資料可能已經分片（sharding）儲存在特定的 Redis 節點上，直接連線可以確保資料一致性與效能。
2. 減少延遲：跳過負載均衡器可減少網路跳數，降低存取延遲。
3. 特殊需求：有些操作（如 Redis Sentinel、主從複寫等）需要直接與特定節點互動，無法透過負載均衡器完成。

因此，這種方式適用於需要直接控制資料流向、提升效能或滿足特殊架構需求的情境。
-->
本段說明驗證 Web Service Pod 是否能夠透過 Headless Service 直接連線到指定的 Redis Pod（如 redis-0），並進行資料存取。這種方式跳過了傳統經由 nginx 等負載均衡器的流量分配，讓服務可以直接與特定 Redis 節點通訊，適用於需要節點親和性或特殊資料分片的場景。
-->
這裡的目的是驗證 Web Service Pod 是否能夠透過 Headless Service 正確連線到特定的 Redis Pod（例如 redis-0），並進行資料存取。這樣可以確保你的服務能直接與指定的 Redis 節點通訊，而不是經過負載均衡。

步驟如下：

```bash
# 1. 取得 Web Service Pod 名稱
kubectl get pods -l app=web-service

# 2. 進入 Web Service Pod（將 <pod-name> 替換為實際名稱）
kubectl exec -it <pod-name> -- sh

# 3. 在 Pod 內使用 redis-cli 連線到 redis-0
redis-cli -h redis-0.redis.default.svc.cluster.local

# 4. 測試資料存取
set foo bar
get foo
```

這樣可以確認 Web Service Pod 能夠直接連到 redis-0，並成功存取資料。

# 進去後
redis-cli -h redis-1.redis.default.svc.cluster.local
redis-1.redis.default.svc.cluster.local:6379> set foo bar
OK
```

### part 3 

是的，你可以進入 web-service 的 Pod，直接測試 DNS 解析與連線：

```bash
kubectl exec -it <web-service-pod> -- sh
# 測試 DNS 解析
# python3 -c "import socket; print(socket.gethostbyname('redis-0.redis.default.svc.cluster.local'))"
-> 10.244.0.12
# 或
getent hosts redis-0.redis.default.svc.cluster.local

# 連線到 redis-0
redis-cli -h redis-0.redis.default.svc.cluster.local
```

這樣可以確保你能存取第一個 Pod（redis-0），因為 Headless Service 會為每個 Pod 產生獨立的 DNS 名稱（如 redis-0.redis.default.svc.cluster.local），直接對應到該 Pod 的 IP。

**Headless Service 與 ClusterIP 差別說明：**

| 服務類型            | DNS 回應                         | 存取方式與特性                                                                 |
|---------------------|----------------------------------|-------------------------------------------------------------------------------|
| **ClusterIP Service** | 回傳 Service 虛擬 IP              | 流量經由 Service 負載均衡到後端 Pod，無法直接指定特定 Pod，適合無狀態服務           |
| **Headless Service**  | 回傳所有 Pod 的實際 IP，或可用 `<pod-name>.<service-name>.<namespace>.svc.cluster.local` 解析到特定 Pod | 可直接連線到單一 Pod，適合 StatefulSet、有狀態服務、需要節點親和性的場景           |

總結：使用 Headless Service，可以透過 DNS 直接存取特定 Pod，這對於有狀態服務或需要節點親和性的應用非常重要。  
進一步來說，Headless Service 讓每個 Pod 都有獨立且可預期的 DNS 名稱（如 `redis-0.redis.default.svc.cluster.local`），這對於分散式資料庫、主從架構、分片集群等場景非常有用。應用程式可以根據需求直接連線到特定節點，實現資料分片、主從同步或節點健康檢查等功能。此外，這種設計也方便進行故障排查與維護，因為每個 Pod 的網路身份都是固定且可追蹤的。  
總之，Headless Service 提供了更細緻的流量控制與服務發現能力，是設計有狀態應用時不可或缺的工具。

