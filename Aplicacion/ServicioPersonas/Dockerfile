FROM node:22-alpine
WORKDIR /aplicacion
COPY --chown=node:node package.json ./
RUN npm install --omit=dev
COPY --chown=node:node src ./src
ENV PUERTO=3001
USER node
EXPOSE 3001
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD wget -qO- http://127.0.0.1:3001/personas/salud || exit 1
CMD ["node", "src/Servidor.js"]
