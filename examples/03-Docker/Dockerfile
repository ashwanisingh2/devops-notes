# Stage 1: Build environment
FROM node:18-alpine AS builder

WORKDIR /app
# Cache optimization: Copy package.json first
COPY package*.json ./
RUN npm ci

# Copy the rest of the source code
COPY . .

# Stage 2: Production environment
FROM node:18-alpine

WORKDIR /app

# Security: Set up a non-root user
USER node

# Copy only necessary files from builder stage
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --from=builder --chown=node:node /app/index.js ./

# Set standard node environment variables
ENV NODE_ENV=production
ENV PORT=8080

EXPOSE 8080

CMD ["node", "index.js"]
