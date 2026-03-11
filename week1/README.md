# 任務要求

### 實作題

1. 撰寫一個名為 deployment.yaml 的檔案，並用 kubectl 在本地 cluster 創建以下服務。 

類型： Deployment 
名稱： web-server 
副本數 (Replicas)： 3 
標籤 (Labels)： app: nginx 
映像檔： nginx:1.14.2 
容器埠號： 80

2. 使用 kubectl get pods -o wide 獲得這 3 個 Pod 的 IP 地址。

```
NAME                          READY   STATUS    RESTARTS   AGE     IP            NODE       NOMINATED NODE   READINESS GATES
web-server-7489fb554f-bf4b2   1/1     Running   0          3m27s   10.244.0.11   minikube   <none>           <none>
web-server-7489fb554f-bx8ck   1/1     Running   0          3m40s   10.244.0.10   minikube   <none>           <none>
web-server-7489fb554f-zsgc8   1/1     Running   0          3m26s   10.244.0.12   minikube   <none>           <none>
```

3. 嘗試用 jsonpath 抓出所有 Label 為 app: nginx 的 pod name，並用逗點分隔。

指令: 
```
kubectl get pods -l app=nginx -o jsonpath='{.items[*].metadata.name}' | tr ' ' ','
```

web-server-7489fb554f-bf4b2,web-server-7489fb554f-bx8ck,web-server-7489fb554f-zsgc8


4. 使用 kubectl exec 進入其中一個 Pod，使用指令驗證網路互通。

以下是進入 Pod 並驗證網路互通的步驟：

**1. 取得 Pod 名稱**
```bash
kubectl get pods -l app=nginx
```

**2. 進入其中一個 Pod**

```bash
kubectl exec -it <pod-name> -- /bin/bash
```
# 例如：
例如：
```bash
kubectl exec -it web-server-7489fb554f-bf4b2 -- /bin/bash
```

**3. 在 Pod 內驗證網路互通**

安裝工具（nginx:1.14.2 預設無 curl/ping，需先安裝）：
```bash
apt-get update && apt-get install -y curl iputils-ping
```

驗證本機 nginx 服務正常：
```bash
curl http://localhost:80
```

取得其他 Pod 的 IP 並測試互通：
```bash
# 先離開 Pod，查詢其他 Pod IP
kubectl get pods -l app=nginx -o wide

# 或用 curl 測試 HTTP
curl http://10.244.0.10:80
```

**4. 驗證 DNS 解析（Cluster 內部）**
```bash
curl http://web-server.<namespace>.svc.cluster.local
```

---

**預期結果：**
| 指令 | 預期輸出 |
|------|---------|
| `curl localhost:80` | nginx 歡迎頁面 HTML |
| `curl http://10.244.0.10:80` | nginx 歡迎頁面 HTML |

這樣可以確認 Pod 本身服務正常，以及 Pod 之間的網路互通（East-West traffic）皆無問題。

5. 手動刪除其中一個 Pod (kubectl delete pod )，觀察 Deployment 如何自動建立新 Pod。

6. 嘗試創建 service.yaml，套用並建立 service 負責該 pods 的服務轉發，使用 NodePort type 的 Service，創建完成後，嘗試另外創建 pod 去 curl ClusterIp 來驗證該 Service 有正確轉發流量以及觀察 Nginx Pods 上的 logs。

note
```
目的： 在 cluster 內部驗證 Service 有正確轉發流量到 nginx pods。

curl-test pod  -->  Service (ClusterIP)  -->  nginx pods (web-server)
ClusterIP 只在 cluster 內部 才能存取，從你的 Mac 直接 curl 是不通的。所以需要在 cluster 裡面另外起一個 pod，從這個 pod 去 curl Service 的 ClusterIP，確認 Service 有正確把流量導到後端的 nginx pods。
```

兩個不同的 pod 都出現了 access log，代表 Service 把請求分發到不同 pod 上了。如果 Service 沒有轉發，nginx pod 的 log 裡根本不會有任何 access record。

```
[pod/web-server-7489fb554f-qtqlq/nginx] /docker-entrypoint.sh: Configuration complete; ready for start up
[pod/web-server-7489fb554f-qtqlq/nginx] 2026/03/10 03:27:25 [notice] 1#1: using the "epoll" event method
[pod/web-server-7489fb554f-qtqlq/nginx] 2026/03/10 03:27:25 [notice] 1#1: nginx/1.27.5
[pod/web-server-7489fb554f-qtqlq/nginx] 2026/03/10 03:27:25 [notice] 1#1: built by gcc 12.2.0 (Debian 12.2.0-14) 
[pod/web-server-7489fb554f-qtqlq/nginx] 2026/03/10 03:27:25 [notice] 1#1: OS: Linux 6.10.14-linuxkit
[pod/web-server-7489fb554f-qtqlq/nginx] 2026/03/10 03:27:25 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
[pod/web-server-7489fb554f-qtqlq/nginx] 2026/03/10 03:27:25 [notice] 1#1: start worker processes
[pod/web-server-7489fb554f-qtqlq/nginx] 2026/03/10 03:27:25 [notice] 1#1: start worker process 29
[pod/web-server-7489fb554f-qtqlq/nginx] 2026/03/10 03:27:25 [notice] 1#1: start worker process 30
[pod/web-server-7489fb554f-qtqlq/nginx] 10.244.0.15 - - [10/Mar/2026:03:28:48 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/8.18.0" "-"
[pod/web-server-7489fb554f-z9krw/nginx] /docker-entrypoint.sh: Configuration complete; ready for start up
[pod/web-server-7489fb554f-z9krw/nginx] 2026/03/10 03:26:47 [notice] 1#1: using the "epoll" event method
[pod/web-server-7489fb554f-z9krw/nginx] 2026/03/10 03:26:47 [notice] 1#1: nginx/1.27.5
[pod/web-server-7489fb554f-z9krw/nginx] 2026/03/10 03:26:47 [notice] 1#1: built by gcc 12.2.0 (Debian 12.2.0-14) 
[pod/web-server-7489fb554f-z9krw/nginx] 2026/03/10 03:26:47 [notice] 1#1: OS: Linux 6.10.14-linuxkit
[pod/web-server-7489fb554f-z9krw/nginx] 2026/03/10 03:26:47 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
[pod/web-server-7489fb554f-z9krw/nginx] 2026/03/10 03:26:47 [notice] 1#1: start worker processes
[pod/web-server-7489fb554f-z9krw/nginx] 2026/03/10 03:26:47 [notice] 1#1: start worker process 29
[pod/web-server-7489fb554f-z9krw/nginx] 2026/03/10 03:26:47 [notice] 1#1: start worker process 30
[pod/web-server-7489fb554f-z9krw/nginx] 10.244.0.23 - - [10/Mar/2026:13:16:50 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/8.18.0" "-"
```

7. 嘗試分別使用 NodePort 及 port forward 的方式，嘗試在本機網路去 curl 該 Service，並且說明兩者的差異以及如果我們希望做到 Service 分流的效果，我們該用兩者之中哪個方法？

NodePort 和 port forward 都是 Kubernetes 中用來讓外部流量訪問 cluster 內部服務的方法，但它們的使用場景和工作原理有所不同：

	| 項目       | NodePort         | Port Forward           |
	|------------|------------------|------------------------|
	| 用途       | 正式對外服務     | 本機開發/debug         |
	| 對外開放   | 是               | 否（只有 localhost）   |
	| 持久性     | 永久             | 只在指令執行期間       |

Port forward 最常見的情境是：你想臨時看一下某個 pod 或 service 的內容，不想正式對外開放，直接 port forward 到 localhost 就好。

做到分流以NodePort為主

- Port forward 只是你的 terminal session 到 cluster 的一條隧道，流量只過你一台 Mac，沒有辦法分流。
- NodePort 背後走的是 kube-proxy，它會把進來的流量透過 iptables 規則分散到所有符合 selector 的 pods，這才是真正的 load balancing。

8. 嘗試使用 kubectl edit 更新 deployment 後，觀察 pod 的變化，並嘗試使用 rollback 退版及查看版本變化。

1. 確認目前版本 kubectl describe deployment web-server | grep Image -> nginx:1.14.2

2. 更新 image 並記錄

```
kubectl set image deployment/web-server nginx=nginx:1.27.5
kubectl annotate deployment/web-server kubernetes.io/change-cause="upgrade to nginx:1.27.5" --overwrite
```

3. 觀察 pod 變化（rolling update）

kubectl get pods -w -> 會看到舊 pod Terminating，新 pod ContainerCreating -> Running

4. 確認更新完成

```
kubectl rollout status deployment/web-server
kubectl describe deployment web-server | grep Image -> nginx:1.27.5
```

5. 查看版本歷史

```
kubectl rollout history deployment/web-server
# REVISION  CHANGE-CAUSE
# 1         <none>
# 2         upgrade to nginx:1.27.5
```

6. Rollback 並記錄

```
kubectl rollout undo deployment/web-server
kubectl annotate deployment/web-server kubernetes.io/change-cause="rollback to nginx:1.14.2" --overwrite
```
7. 確認退版


kubectl describe deployment web-server | grep Image -> nginx:1.14.2

```
kubectl rollout history deployment/web-server
# REVISION  CHANGE-CAUSE
# 2         upgrade to nginx:1.27.5
# 3         rollback to nginx:1.14.2
s
```

9. 嘗試自己 build 一個新的 nginx image，用它創建一個新的 deployment "web-server-new"，以及與之對應的 service，嘗試在 dockerfile 中，加入 nginx 設定檔的設定，讓其可以將流量轉發至 web-server。 並且提供您如何驗證是否有成功的做法。

驗證方式：從 cluster 內部 curl web-server-service-new，然後觀察 web-server pods 的 log 有沒有收到請求。

Step 1：curl web-server-service-new

kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl http://web-server-service-new:80
如果回傳 nginx 歡迎頁面，代表 web-server-new 有正常啟動。

Step 2：觀察 web-server pods 的 log


kubectl logs -l app=nginx --prefix --tail=10
如果 web-server pods 的 log 出現 access record，代表流量確實從 web-server-new 透過 web-server-svc 轉發過來了，整條鏈路驗證成功：


client -> web-server-service-new -> web-server-new -> web-server-svc -> web-server pods

整個流程就是：

1. nginx.conf      ← 寫轉發規則（proxy_pass 到 web-server-svc）
       ↓
2. Dockerfile      ← 把 nginx.conf 打包進 nginx image
       ↓
3. docker build    ← 產生自訂 image (web-server-new:v1)
       ↓
4. deployment.yaml ← 用這個 image 創建 pods (web-server-new)
       ↓
5. service-new.yaml← 對外暴露這些 pods (web-server-service-new)
最終流量路徑：


client
  → web-server-service-new (你的 NodePort service)
  → web-server-new pods (跑你自訂的 nginx，裡面有 proxy_pass)
  → web-server-svc (原本的 service)
  → web-server pods (原本的 nginx)

10. 第九題流量順序應如以下： client -> web-server-service-new -> web-server-new -> web-server-service -> web-server