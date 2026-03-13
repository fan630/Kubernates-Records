const https = require('https'); // 內建模組，用來發 HTTPS 請求
const fs = require('fs');       // 內建模組，用來讀取檔案

// 讀取 projected volume 掛載進來的 SA token（Pod 的身份憑證，用來向 api-server 證明自己是誰）
const token = fs.readFileSync('/var/run/secrets/kubernetes.io/serviceaccount/token', 'utf8').trim();

// 讀取 CA 憑證（用來驗證 api-server 的 TLS 憑證是合法的，避免連到假的 server）
const ca = fs.readFileSync('/var/run/secrets/kubernetes.io/serviceaccount/ca.crt');

// 讀取當前 Pod 所在的 namespace（由 projected volume 的 downwardAPI 注入）
const namespace = fs.readFileSync('/var/run/secrets/kubernetes.io/serviceaccount/namespace', 'utf8').trim();

// 發送 HTTPS GET 請求給 api-server
const req = https.request({
  hostname: 'kubernetes.default.svc',              // api-server 在 cluster 內的固定 DNS 名稱
  path: `/api/v1/namespaces/${namespace}/pods`,     // K8s API 路徑：列出指定 namespace 的 pods
  headers: { Authorization: `Bearer ${token}` },   // 把 SA token 放進 header，api-server 用這個驗證身份
  ca,                                               // 告訴 Node.js 信任這個 CA 憑證
}, (res) => {
  let data = '';
  res.on('data', chunk => data += chunk); // 收到回應資料時，持續累加（因為大量資料會分批傳）
  res.on('end', () => {                   // 所有資料接收完畢後執行
    const body = JSON.parse(data);        // 把 JSON 字串轉成物件
    if (!body.items) {                    // 如果沒有 items，代表 api-server 回傳錯誤（例如 403 權限不足）
      console.error('API error:', JSON.stringify(body, null, 2));
      process.exit(1);                    // 印出錯誤後結束程式
    }
    console.log(`pod list in ${namespace} namespace:\n`); // 印出標題
    body.items.forEach(p => console.log(p.metadata.name)); // 逐一印出每個 pod 的名稱
  });
});

// 如果網路連線本身發生錯誤（例如 DNS 解析失敗），印出錯誤並結束
req.on('error', err => { console.error(err.message); process.exit(1); });

req.end(); // 送出請求
