#!/bin/bash
# SPDX-FileCopyrightText: 2024 ESP32-MicroCSI Contributors
# SPDX-License-Identifier: MIT
#
# Helper script to run CSI examples with WiFi credentials

if [ $# -lt 2 ]; then
    echo "Usage: ./scripts/run_example.sh <SSID> <PASSWORD>"
    echo ""
    echo "Example:"
    echo "  ./scripts/run_example.sh MyWiFi MyPassword"
    exit 1
fi

SSID="$1"
PASSWORD="$2"
SCRIPT="example_csi_analysis" # Change this to "example_csi_basic" to run the basic example

# Detect ESP32 port automatically
echo "Detecting ESP32 device..."
PORT=""

# Try common macOS USB serial ports
for p in /dev/cu.usbmodem* /dev/cu.usbserial-* /dev/cu.SLAB_USBtoUART*; do
    if [ -e "$p" ]; then
        # Check if port is not in use
        if ! lsof "$p" >/dev/null 2>&1; then
        PORT="$p"
            echo "Found available ESP32 on: $PORT"
        break
        else
            echo "Port $p is in use, trying next..."
        fi
    fi
done

if [ -z "$PORT" ]; then
    echo "Error: No available ESP32 device found."
    echo ""
    echo "Available ports:"
    ls -la /dev/cu.* 2>/dev/null || echo "No USB devices found"
    echo ""
    echo "If a port is in use, close any programs using it (e.g., screen, minicom, Arduino IDE)"
    exit 1
fi

# Create temporary wifi_config.py
cat > examples/wifi_config.py << EOF
# Auto-generated WiFi configuration (temporary)
WIFI_SSID = "$SSID"
WIFI_PASSWORD = "$PASSWORD"
EOF

# Copy files to device and run
echo "Copying files to device..."
mpremote connect "$PORT" fs cp examples/wifi_config.py :wifi_config.py

echo "Copying example script to device..."
mpremote connect "$PORT" fs cp examples/"$SCRIPT".py :"$SCRIPT".py

echo "Running example on $PORT..."
mpremote connect "$PORT" exec "exec(open('$SCRIPT.py').read())"
