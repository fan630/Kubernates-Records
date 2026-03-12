
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