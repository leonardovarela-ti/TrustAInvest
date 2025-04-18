# Build stage
FROM debian:bullseye-slim AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /opt/flutter -b stable
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter doctor
RUN flutter config --enable-web

# Set up the app
WORKDIR /app
COPY . .
RUN rm -f assets/config/config.json  # Remove the config file before building
RUN flutter clean
RUN flutter pub get
RUN flutter build web --profile

# Serve stage
FROM nginx:alpine

# Copy the built app
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create necessary directories
RUN mkdir -p /usr/share/nginx/html/assets/config

# Copy and set up entrypoint script
COPY entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Create necessary directories and files for nginx
RUN mkdir -p /var/log/nginx /var/cache/nginx /var/run \
    && touch /var/run/nginx.pid

# Expose port
EXPOSE 8080

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
