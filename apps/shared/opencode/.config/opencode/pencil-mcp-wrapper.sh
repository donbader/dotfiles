#!/bin/bash

# Find the port Pencil is listening on (IPv6 localhost)
PORT=$(lsof -iTCP -sTCP:LISTEN -n -P | grep Pencil | grep '\[::1\]:' | sed -n 's/.*\[::1\]:\([0-9]*\).*/\1/p' | head -1)

# If no port found, exit with error
if [ -z "$PORT" ]; then
    echo "Error: Could not find Pencil listening port. Is Pencil running?" >&2
    exit 1
fi

# Launch the MCP server with the discovered port
exec /Applications/Pencil.app/Contents/Resources/app.asar.unpacked/out/mcp-server-darwin-arm64 --ws-port "$PORT"
