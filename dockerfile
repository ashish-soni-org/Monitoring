# 1. Base Image
# Replace 'alpine:latest' with your required base (e.g., node:18, python:3.9, grafana/grafana)
FROM grafana/grafana

# =========================================================
# CONFIGURATION: ADAPT TO DEPLOYMENT TOOL
# =========================================================

# The tool strictly requires the application to listen on Port 5000.
# We set this as an environment variable so your app can use it.
ENV PORT=5000

# We expose it so Docker knows about it.
EXPOSE 5000

# =========================================================
# APPLICATION LOGIC (FILL THIS IN)
# =========================================================

# Example: Create a directory for your app
WORKDIR /app

# Example: Copy your source code
# COPY . .

# Example: Command to start your application
# Make sure your app uses the $PORT variable or hardcodes port 5000
CMD ["echo", "This is a blank container. Replace this CMD with your application start command."]