# Stage 1: Build the Flutter Web App
FROM ghcr.io/cirruslabs/flutter:3.27.0 as build-env

# Setup directory with proper permissions
USER root
RUN mkdir -p /app && chown -R cirrus:cirrus /app

# Switch to the default non-root cirrus user
USER cirrus
WORKDIR /app

# Fix Git dubious ownership error (just in case)
RUN git config --global --add safe.directory '*'

# Copy dependency files and get packages
COPY --chown=cirrus:cirrus pubspec.yaml ./
RUN flutter pub get

# Copy the rest of the application
COPY --chown=cirrus:cirrus . .

# Build the app for the web with verbose logging to debug build termination
RUN flutter build web -v --release

# Stage 2: Serve the app with Nginx
FROM nginx:alpine
WORKDIR /usr/share/nginx/html

# Clear the default nginx html files
RUN rm -rf ./*

# Copy the build output from the builder stage
COPY --from=build-env /app/build/web .

# Copy our custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port (Cloud Run defaults to 8080)
EXPOSE 8080

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
