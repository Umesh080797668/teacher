# Use the official Flutter image as base
FROM cirrusci/flutter:latest

# Set working directory
WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.* ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the code
COPY . .

# Build for web
RUN flutter build web --release

# Expose port (though for static, not needed)
EXPOSE 8080

# For Render static site, the build output is in build/web
# This Dockerfile is for building, Render will serve the static files