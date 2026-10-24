# Ohara API — production image.
#
#   docker build -t reem-api backend
#   docker run --env-file backend/.env.production -p 3000:3000 reem-api
#
# Portable on purpose: the same image runs on Render, Fly.io, Railway or a
# VPS. Nothing here names a host.
#
# Three stages. `build` compiles with dev dependencies; `prod-deps` installs
# only what runs; the final image copies the two together and runs as the
# unprivileged `node` user. The Prisma client is generated in `build` and
# copied across — it is generated code tied to this schema and this platform,
# not something `npm ci --omit=dev` produces.

# The Node the lock file was written with (npm 11). npm 10, on Node 20/22,
# rejects this lock in `npm ci` over optional peer entries it expects.
ARG NODE_VERSION=24

# ── build ────────────────────────────────────────────────────────────────────
FROM node:${NODE_VERSION}-bookworm-slim AS build
WORKDIR /app
# Prisma's engine links against OpenSSL; slim images do not ship it.
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY . .
RUN npx prisma generate && npm run build

# ── production dependencies ─────────────────────────────────────────────────
FROM node:${NODE_VERSION}-bookworm-slim AS prod-deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

# ── runtime ──────────────────────────────────────────────────────────────────
FROM node:${NODE_VERSION}-bookworm-slim AS runtime
WORKDIR /app
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# No PORT here: the platform provides it (Render sets PORT, 10000 by default)
# and the API binds to it on every interface (HOST=0.0.0.0). Only a bare
# `docker run` without -e PORT falls back to the code's default, 3000.
#
# NODE_OPTIONS leaves V8 headroom under a 512 MB instance: sharp decodes
# photographs outside the V8 heap, and an instance killed for memory drops
# every WebSocket at once.
ENV NODE_ENV=production \
    HOST=0.0.0.0 \
    LOG_FORMAT=json \
    NODE_OPTIONS=--max-old-space-size=384

COPY --from=prod-deps --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=build --chown=node:node /app/dist ./dist
# The schema, migrations and the Supabase CA: `sslcert=./certs/…` in
# DATABASE_URL resolves against prisma/, and `migrate-pooled.mjs` reads
# migrations from here.
COPY --from=build --chown=node:node /app/prisma ./prisma
COPY --from=build --chown=node:node /app/scripts/migrate-pooled.mjs ./scripts/migrate-pooled.mjs
COPY --chown=node:node package.json ./

USER node
# Documentation only — the API listens on $PORT.
EXPOSE 10000

# Liveness only: whether the process answers. Readiness (the database) is the
# platform's health check on /health/ready; see docs/DEPLOYMENT.md.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health/live').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Node receives SIGTERM directly (no shell in between), and Nest's shutdown
# hooks close sockets, finish running jobs and release their leases.
CMD ["node", "dist/main.js"]
