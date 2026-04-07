1. 嘗試使用 Helm Chart 安裝任一開源服務，例如：
https://artifacthub.io/packages/helm/bitnami/ghost

2. 並且，使用 Nginx Ingress（https://github.com/kubernetes/ingress-nginx），作為Ingress 將外部流量導向該開源服務。

該 ingress 需根據 hostname(網址) 作為規則，去轉發該流量（可使用 Host Header 去驗證請求）。

3. 並且你可以創建 Loadbalancer Service 允許外部流量進入 Ingress，流量路徑如下（亦可參考下圖）：

Client -> loadbalancer(created by "loadbalancer service") -> ClusterIP of "loadbalancer service" -> Service of Ingress -> Pods of Ingress(Nginx) -> Ghost Service -> Ghost Pod

4. （進階題）嘗試使用 Gateway API 取代 Ingress，Gateway API 實作部分，可以參考https://gateway.envoyproxy.io/

---

## 實作說明

### 安裝的開源服務：Gitea（開源 Git 服務）

> 注意：原本選用 bitnami/ghost，但 Bitnami 映像在 2025 年 8 月後需訂閱付費，
> 故改用 Gitea（官方免費映像 docker.gitea.com/gitea）。

### 架構

```
Client
  └─► LoadBalancer Service (ingress-nginx-controller, port 80)
        └─► ClusterIP of ingress-nginx-controller
              └─► Nginx Ingress Controller Pod
                    └─► (路由規則: Host: gitea.local)
                          └─► gitea-http Service (ClusterIP, port 3000)
                                └─► Gitea Pod
```

### 安裝步驟

#### 1. 加入 Helm Repo

```bash
# Gitea 官方 chart
helm repo add gitea-charts https://dl.gitea.com/charts/

# Nginx Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm repo update
```

#### 2. 建立 namespace

```bash
kubectl create namespace task8
```

#### 3. 安裝 Gitea

```bash
helm install gitea gitea-charts/gitea \
  -n task8 \
  -f gitea-values.yaml
```

`gitea-values.yaml` 重點設定：
- `service.http.type: ClusterIP`：讓流量透過 Ingress 進入，而非直接對外
- `ingress.enabled: false`：關閉內建 Ingress，改用我們自己建的
- `gitea.config.database.DB_TYPE: sqlite3`：使用 SQLite，不需額外 DB

#### 4. 安裝 Nginx Ingress Controller（含 LoadBalancer Service）

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer
```

此指令會同時建立：
- Nginx Ingress Controller Pod
- **LoadBalancer Service**（`ingress-nginx-controller`），負責接收外部流量

#### 5. 建立 Ingress 資源（hostname 路由規則）

```bash
kubectl apply -f ingress.yaml
```

`ingress.yaml` 的路由規則：
- `ingressClassName: nginx`：指定使用 Nginx Ingress
- `host: gitea.local`：只有 `Host: gitea.local` 的請求才轉發給 Gitea
- backend: `gitea-http:3000`

#### 6. 對外存取（minikube 環境）

```bash
# 取得 LoadBalancer External IP（需要 sudo）
minikube tunnel

# 透過 Host Header 驗證 Ingress 路由
curl -H "Host: gitea.local" http://127.0.0.1/

# 或加入 /etc/hosts
echo "127.0.0.1 gitea.local" | sudo tee -a /etc/hosts
open http://gitea.local
```

登入資訊：
- URL: http://gitea.local
- 帳號: admin
- 密碼: Admin1234!

### 驗證指令

```bash
# 查看所有資源狀態
kubectl get pods,svc,ingress -n task8
kubectl get svc -n ingress-nginx

# 從 Ingress Controller 內部驗證 Host Header 路由
NGINX_POD=$(kubectl get pod -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ingress-nginx $NGINX_POD -- curl -si -H "Host: gitea.local" http://localhost/
# → HTTP/1.1 200 OK ✓

# 直接存取 Gitea（port-forward）
kubectl port-forward -n task8 svc/gitea-http 8080:3000
curl http://127.0.0.1:8080/
```

### 檔案列表

| 檔案 | 說明 |
|------|------|
| `gitea-values.yaml` | Gitea Helm Chart 設定值 |
| `ingress.yaml` | Ingress 資源（hostname 路由規則） |
