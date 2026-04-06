# 任務 7：Helm Chart 開發與部署

嘗試閱讀 https://helm.sh/docs/chart_template_guide/getting_started，以瞭解 Helm Chart 開發方式。

創建一個自己的 Helm Chart，至少需要有 /templates 及 values.yaml（可以簡單的創建一個 nginx deployment，values.yaml 可以放 replicas）。

請選擇任一個 hosted helm registry，
https://helm.sh/docs/topics/registries#use-hosted-registries
將你的 helm chart push 到該 registry 上，並以 public 存取的方式，在你的 local k8s 環境上 install 該 chart。

## Helm Chart 是什麼? 為什麼我們需要? 

Helm Chart 是 Kubernetes 的套件管理工具，類似於 Linux 的 apt 或 yum。它允許我們定義、安裝和升級 Kubernetes 應用程式。使用 Helm Chart 可以簡化應用程式的部署過程，並且可以輕鬆地管理應用程式的版本和配置。

把 Helm / Helm Chart 想成**食譜 App**：

---

**Helm** = 那個 App 本身（幫你管理食譜）

**Helm Chart** = 一份食譜（材料清單 + 步驟）

---

**沒有 Helm 的世界：**

你想在 Kubernetes 部署一個應用，要自己一個一個建立：
Deployment、Service、Ingress、ConfigMap、Secret...

> 就像你想煮義大利麵，要自己去找「麵要幾克」「水要幾度」「煮幾分鐘」，每次都從頭查

---

**有 Helm 的世界：**

```bash
helm install my-app stable/nginx
```

一行指令，全部搞定。

> 就像直接打開食譜 App，點「開始烹飪」，材料和步驟全幫你準備好了

---

**最大的好處是「可以調整」：**

同一份食譜，你可以說：
- 「我要做 2 人份」→ 材料自動減半
- 「我不吃辣」→ 去掉辣椒

Helm 也一樣，同一份 Chart，可以這樣用：
- dev 環境 → 1 個 replica
- prod 環境 → 10 個 replica

改個參數就好，不用重寫 YAML。

## 理解

templates裡面可以放deployment.yaml、service.yaml、ingress.yaml等K8s資源的模板，這些模板會根據values.yaml中的參數來生成最終的K8s資源定義。

那Chart.yaml則是定義這個Chart的基本資訊，例如名稱、版本、描述等。

## 實作

### Chart 結構

```
my-nginx-chart/
├── Chart.yaml          # Chart 基本資訊（名稱、版本）
├── values.yaml         # 預設參數值
└── templates/
    ├── _helpers.tpl    # 共用模板函數（fullname、labels）
    ├── deployment.yaml # Nginx Deployment
    └── service.yaml    # ClusterIP Service
```

### 關鍵設計

`values.yaml` 放可調整的參數：

```yaml
replicaCount: 2         # 可以在 install 時用 --set 覆蓋
image:
  repository: nginx
  tag: "1.27.0"
service:
  type: ClusterIP
  port: 80
```

`deployment.yaml` 用 `{{ .Values.replicaCount }}` 引用參數，同一份 Chart 可以輕鬆切換 dev/prod 設定。

### 打包 Chart

```bash
helm package my-nginx-chart -d ./
# 產生 my-nginx-chart-0.1.0.tgz
```

### 推到 GHCR

```bash
export GITHUB_TOKEN=<PAT>
echo $GITHUB_TOKEN | helm registry login ghcr.io -u fan630 --password-stdin
helm push my-nginx-chart-0.1.0.tgz oci://ghcr.io/fan630
```

推上去後可在 `https://github.com/users/fan630/packages` 看到。

### 從 GHCR 安裝到本地 K8s

```bash
helm install my-nginx oci://ghcr.io/fan630/my-nginx-chart --version 0.1.0
```

驗證：

```bash
kubectl get pods
kubectl get svc
```

