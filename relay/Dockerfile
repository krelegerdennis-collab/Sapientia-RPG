# SAPIENTIA relay. Bouwen vanuit relay/:  docker build -t sapientia-relay .
FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund
COPY server.js ./
COPY src ./src
USER node
EXPOSE 8080
ENV PORT=8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- "http://127.0.0.1:${PORT}/healthz" || exit 1
CMD ["node", "server.js"]
