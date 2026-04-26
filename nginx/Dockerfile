FROM nginx:alpine

# Install curl for healthcheck
RUN apk add --no-cache curl

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy dashboard UI
COPY dashboard.html /usr/share/nginx/html/dashboard.html

EXPOSE 80 8080

CMD ["nginx", "-g", "daemon off;"]
