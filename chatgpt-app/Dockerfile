FROM node:20-slim

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source
COPY tsconfig.json ./
COPY src ./src
COPY public ./public

# Build TypeScript
RUN npm run build

# Expose port
EXPOSE 8080

# Set environment
ENV NODE_ENV=production
ENV PORT=8080

# Start server
CMD ["node", "dist/server.js"]
