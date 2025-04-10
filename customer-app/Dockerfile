FROM ubuntu:20.04 AS build-env

# Set noninteractive installation to avoid timezone prompt
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-8-jdk \
    wget \
    sudo

# Create a non-root user
RUN useradd -ms /bin/bash flutteruser
RUN mkdir -p /home/flutteruser/.pub-cache && chown -R flutteruser:flutteruser /home/flutteruser

# Set up Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter
RUN chown -R flutteruser:flutteruser /flutter
ENV PATH="/flutter/bin:${PATH}"

# Switch to non-root user for Flutter operations
USER flutteruser
RUN flutter channel stable
RUN flutter upgrade
RUN flutter config --enable-web

# Copy app files
WORKDIR /app
USER root
COPY --chown=flutteruser:flutteruser . .

# Switch back to non-root user for Flutter operations
USER flutteruser

# Get dependencies
RUN flutter pub get

# Build web app
RUN flutter build web --release

# Intermediate stage to copy files from build/web to web
USER root
RUN cp /app/build/web/main.dart.js /app/web/ && \
    cp /app/build/web/flutter_service_worker.js /app/web/ && \
    cp -r /app/build/web/canvaskit /app/web/ && \
    cp -r /app/build/web/assets /app/web/ && \
    cp /app/build/web/version.json /app/web/ && \
    cp /app/build/web/favicon.png /app/web/ && \
    cp -r /app/build/web/icons /app/web/

# Serve the app with Nginx
FROM nginx:1.21.1-alpine
COPY --from=build-env /app/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
