# syntax=docker/dockerfile:1

# Imagen base oficial de Node.js (LTS) sobre Alpine Linux: ligera y adecuada
# para producción. Next.js 16 requiere Node.js >= 20.9, por eso no se usa node:18.
ARG NODE_VERSION=22-alpine

# ---------------------------------------------------------------------------
# Etapa 1: deps — instala las dependencias a partir del lockfile
# ---------------------------------------------------------------------------
FROM node:${NODE_VERSION} AS deps
# libc6-compat: compatibilidad con binarios nativos compilados para glibc
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copiar solo los manifiestos permite reutilizar esta capa en caché
# mientras package.json / package-lock.json no cambien.
COPY package.json package-lock.json ./
RUN npm ci

# ---------------------------------------------------------------------------
# Etapa 2: builder — compila la aplicación (next build)
# ---------------------------------------------------------------------------
FROM node:${NODE_VERSION} AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# ---------------------------------------------------------------------------
# Etapa 3: runner — imagen final de producción, solo con lo necesario
# ---------------------------------------------------------------------------
FROM node:${NODE_VERSION} AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# Ejecutar como usuario sin privilegios (no root)
RUN addgroup --system --gid 1001 nodejs \
 && adduser --system --uid 1001 --ingroup nodejs nextjs

# Archivos estáticos públicos
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
# Salida standalone: server.js + node_modules mínimos
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
# Assets estáticos generados por el build (JS/CSS)
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:3000/ || exit 1

# Comando de inicio. Con output: "standalone", server.js es el servidor de
# producción equivalente a `next start` (Next.js no admite `next start`
# con la salida standalone).
CMD ["node", "server.js"]
