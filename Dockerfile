# Stage 1: Build the Flutter Web App
FROM fischerscode/flutter:3.24.1 as build-env
WORKDIR /app

# Set user to root to avoid permission denied errors
USER root

# Fix Git dubious ownership error for Flutter SDK
RUN git config --global --add safe.directory /home/flutter/flutter-sdk

# Copy dependency files and get packages
COPY pubspec.yaml ./

RUN flutter pub get

# Copy the rest of the application
COPY . .

# Build the app for the web. We use standard web output since this will be static hosting via nginx
RUN flutter build web --release

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
