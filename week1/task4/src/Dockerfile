# 使用官方 Node.js 16 Alpine 映像檔（體積小）
FROM node:16-alpine

# 設定工作目錄
WORKDIR /app

# 複製 package.json 和 package-lock.json（如果存在）
COPY package*.json ./

# 安裝依賴項
RUN npm install --production

# 複製應用程式代碼
COPY app.js .

# 創建非 root 使用者以增強安全性
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodeuser -u 1001

# 更改應用程式目錄的擁有者
RUN chown -R nodeuser:nodejs /app
USER nodeuser

# 暴露埠（雖然這個應用不需要，但作為最佳實踐）
EXPOSE 3000

# 設定環境變數
ENV NODE_ENV=production
ENV TARGET_NAMESPACE=default

# 健康檢查（檢查程序是否還在運行）
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD pgrep -f "node app.js" || exit 1

# 啟動應用程式
CMD ["npm", "start"]