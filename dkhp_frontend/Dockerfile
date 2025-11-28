## Build stage
FROM node:16-alpine as build-stage
WORKDIR /app

# Install packages
COPY package*.json ./
RUN npm install

# Copy source and build
COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine as production-stage

# Copy nginx.conf, create-env.sh and built folder
COPY  --from=build-stage /app/nginx.conf /etc/nginx/conf.d/default.conf
COPY  --from=build-stage /app/create-env.sh /usr/share/nginx/create-env.sh
COPY  --from=build-stage /app/build /usr/share/nginx/html

# Export env variables
RUN chmod +x /usr/share/nginx/create-env.sh
ENTRYPOINT ["/usr/share/nginx/create-env.sh"]

# Start Nginx App
CMD ["nginx", "-g", "daemon off;"]