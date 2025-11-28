#!/bin/sh

# Create a JavaScript file with environment variables
echo "window.env = { 'API_ENDPOINT': '$API_ENDPOINT' };" > /usr/share/nginx/html/env.js

# Exec additional commands
exec "$@"
