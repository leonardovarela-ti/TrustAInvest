# Builder stage
FROM debian:bullseye-slim AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Set up Flutter
ENV FLUTTER_HOME=/opt/flutter
ENV PATH=$FLUTTER_HOME/bin:$PATH

# Download and install Flutter
RUN git clone https://github.com/flutter/flutter.git $FLUTTER_HOME -b stable
RUN flutter doctor
RUN flutter config --enable-web

# Set up non-root user
RUN groupadd -r flutter && useradd -r -g flutter -m -d /home/flutter flutter
RUN mkdir -p /app && chown -R flutter:flutter /app $FLUTTER_HOME
USER flutter

# Set working directory
WORKDIR /app

# Copy pubspec files
COPY --chown=flutter:flutter pubspec.yaml pubspec.lock* ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application
COPY --chown=flutter:flutter . .

# Build the web app
RUN flutter build web --release

# Final stage
FROM nginx:alpine

# Create a non-root user for nginx
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy the built web app from the builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy the nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create a directory for environment variables
RUN mkdir -p /usr/share/nginx/html/assets/config

# Copy the entrypoint script
COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Make sure the non-root user owns the files and has proper permissions
RUN chown -R appuser:appgroup /usr/share/nginx/html /var/cache/nginx /var/log/nginx /etc/nginx/conf.d /usr/local/bin/docker-entrypoint.sh && \
    chmod 755 /usr/local/bin/docker-entrypoint.sh && \
    chmod -R 755 /usr/local/bin

# Update permissions for nginx to run as non-root
RUN touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid

# Switch to non-root user
USER appuser

# Expose the web server port
EXPOSE 80

# Start nginx with the entrypoint script
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
