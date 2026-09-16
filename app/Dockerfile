# ---- deps stage ----
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# ---- runtime stage ----
FROM node:20-alpine
RUN addgroup -S nimbus && adduser -S nimbus -G nimbus
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY server.js ./
COPY public ./public
COPY package*.json ./

ENV NODE_ENV=production \
    PORT=3000

USER nimbus
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode===200?0:1)).on('error', () => process.exit(1))"

CMD ["node", "server.js"]
