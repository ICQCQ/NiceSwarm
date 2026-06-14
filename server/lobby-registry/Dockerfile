# NiceSwarm Lobby Registry — zero-dependency Node service.
# No `npm install` step: the app uses only the Node standard library.
FROM node:22-alpine

WORKDIR /app
COPY package.json ./
COPY src ./src

ENV PORT=8088
# Set TRUST_PROXY=1 when running behind a reverse proxy / Cloudflare Tunnel.
ENV TRUST_PROXY=0
EXPOSE 8088

# Run as the built-in non-root user.
USER node

CMD ["node", "src/server.js"]
