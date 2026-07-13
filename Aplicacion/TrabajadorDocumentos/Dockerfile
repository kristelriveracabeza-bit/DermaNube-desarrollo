FROM node:22-alpine
WORKDIR /aplicacion
COPY --chown=node:node package.json ./
RUN npm install --omit=dev
COPY --chown=node:node src ./src
USER node
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD node -e "process.kill(1,0)" || exit 1
CMD ["node", "src/Trabajador.js"]
