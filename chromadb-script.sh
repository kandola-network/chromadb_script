#!/bin/bash

# Check if username and password are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

# Variables
CHROMA_DIR="./chromadb"
PASSWORD_FILE="./server.htpasswd"
USERNAME="$1"
PASSWORD="$2"

# Create a directory for ChromaDB if it doesn't exist
mkdir -p "$CHROMA_DIR"

# Generate password file with bcrypt hashed password
echo "Generating password file..."
docker run --rm --entrypoint htpasswd httpd:2 -Bbn "$USERNAME" "$PASSWORD" > "$PASSWORD_FILE"

# Verify the password file
echo "Verifying password file..."
docker run --rm -v "$PASSWORD_FILE":/server.htpasswd --entrypoint htpasswd httpd:2 -vb /server.htpasswd "$USERNAME" "$PASSWORD"

# Create docker-compose.yaml
echo "Creating docker-compose.yaml..."
cat <<EOF > docker-compose.yaml
version: '3.8'

networks:
  net:
    driver: bridge

services:
  chromadb:
    image: chromadb/chroma:0.5.16
    volumes:
      - $CHROMA_DIR:/chroma/chroma
      - $PASSWORD_FILE:/chroma/server.htpasswd
    environment:
      - IS_PERSISTENT=TRUE
      - PERSIST_DIRECTORY=/chroma/chroma # this is the default path, change it as needed
      - ANONYMIZED_TELEMETRY=\${ANONYMIZED_TELEMETRY:-TRUE}
      - CHROMA_SERVER_AUTHN_CREDENTIALS_FILE=server.htpasswd
      - CHROMA_SERVER_AUTHN_PROVIDER=chromadb.auth.basic_authn.BasicAuthenticationServerProvider
    ports:
      - 8000:8000
    networks:
      - net
EOF

# Run the Chroma server
echo "Starting ChromaDB server with authentication..."
docker compose -f docker-compose.yaml up -d

echo "ChromaDB setup complete. The server is running on port 8000."
