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

7. 嘗試分別使用 NodePort 及 port forward 的方式，嘗試在本機網路去 curl 該 Service，並且說明兩者的差異以及如果我們希望做到 Service 分流的效果，我們該用兩者之中哪個方法？

8. 嘗試使用 kubectl edit 更新 deployment 後，觀察 pod 的變化，並嘗試使用 rollback 退版及查看版本變化。

9. 嘗試自己 build 一個新的 nginx image，用它創建一個新的 deployment "web-server-new"，以及與之對應的 service，嘗試在 dockerfile 中，加入 nginx 設定檔的設定，讓其可以將流量轉發至 web-server。 並且提供您如何驗證是否有成功的做法。

10. 第九題流量順序應如以下： client -> web-server-service-new -> web-server-new -> web-server-service -> web-server