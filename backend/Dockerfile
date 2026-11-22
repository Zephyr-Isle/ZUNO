# zuno-api 自托管镜像：把 Cloudflare Worker 代码原样跑在 Node 上
# （D1 → node:sqlite，见 selfhost/main.ts）。多阶段构建，最终镜像里只有
# 一个 server.mjs + node:24-alpine，不含源码和 node_modules。

# ---- 构建：esbuild 把 selfhost/main.ts 连同 src/ 打成单文件 ----
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
# devDeps 里的 esbuild 是构建工具，必须装。
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
COPY selfhost ./selfhost
COPY schema.sql ./
RUN npm run bundle:selfhost

# ---- 运行：非 root，仅暴露 8080，数据放 /data 卷 ----
FROM node:24-alpine
ENV NODE_ENV=production \
    PORT=8080 \
    DB_PATH=/data/zuno.db
WORKDIR /app
COPY --from=build /app/selfhost/dist/server.mjs ./server.mjs
RUN mkdir -p /data && chown node:node /data
USER node
VOLUME /data
EXPOSE 8080
CMD ["node", "server.mjs"]
