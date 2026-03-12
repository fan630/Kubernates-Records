const k8s = require('@kubernetes/client-node');
const fs = require('fs');

async function main() {
    console.log('🚀 開始呼叫 Kubernetes API...');
    
    try {
        // 創建 kubernetes client 配置
        const kc = new k8s.KubeConfig();
        
        // 在 Pod 內環境中載入 service account token
        kc.loadFromCluster();
        
        const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
        
        // 取得目標 namespace（從環境變數或預設為 'default'）
        const namespace = process.env.TARGET_NAMESPACE || 'default';
        
        console.log(`📋 正在取得 namespace '${namespace}' 內的 Pod 列表...`);
        
        // 呼叫 Kubernetes API 取得 Pod 列表
        const response = await k8sApi.listNamespacedPod(namespace);
        
        console.log(`\n=== Pod list in ${namespace} namespace ===\n`);
        
        if (response.body.items.length === 0) {
            console.log('❌ No pods found in this namespace.');
        } else {
            response.body.items.forEach((pod, index) => {
                const name = pod.metadata.name;
                const status = pod.status.phase;
                const ready = pod.status.conditions
                    ?.find(c => c.type === 'Ready')
                    ?.status === 'True' ? '✅' : '❌';
                
                console.log(`${index + 1}. ${name} (${status}) ${ready}`);
            });
        }
        
        console.log(`\n📊 Total: ${response.body.items.length} pod(s) found.\n`);
        
        // 額外顯示詳細資訊
        console.log('=== Detailed Pod Information ===');
        response.body.items.forEach(pod => {
            console.log(`Pod: ${pod.metadata.name}`);
            console.log(`  Status: ${pod.status.phase}`);
            console.log(`  Node: ${pod.spec.nodeName || 'N/A'}`);
            console.log(`  Created: ${pod.metadata.creationTimestamp}`);
            console.log(`  Labels: ${JSON.stringify(pod.metadata.labels || {}, null, 2)}`);
            console.log('---');
        });
        
    } catch (error) {
        console.error('❌ Error calling Kubernetes API:', error.message);
        
        // 顯示詳細錯誤資訊以便除錯
        if (error.response) {
            console.error('Response Status:', error.response.statusCode);
            console.error('Response Body:', error.response.body);
        }
        
        process.exit(1);
    }
}

// 每 30 秒執行一次，方便觀察
async function runPeriodically() {
    await main();
    
    console.log('⏰ 等待 30 秒後重新執行...\n');
    setTimeout(runPeriodically, 30000);
}

// 如果設定了 RUN_ONCE 環境變數，只執行一次
if (process.env.RUN_ONCE === 'true') {
    main();
} else {
    runPeriodically();
}