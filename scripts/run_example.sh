#!/bin/bash
# SPDX-FileCopyrightText: 2024 ESP32-MicroCSI Contributors
# SPDX-License-Identifier: MIT
#
# Helper script to run CSI examples with WiFi credentials

if [ $# -lt 2 ]; then
    echo "Usage: ./script/run_example.sh <SSID> <PASSWORD>"
    echo ""
    echo "Example:"
    echo "  ./script/run_example.sh MyWiFi MyPassword"
    exit 1
fi

SSID="$1"
PASSWORD="$2"
SCRIPT="example_csi_analysis" # Change this to "example_csi_basic" to run the basic example

# Create temporary wifi_config.py
cat > examples/wifi_config.py << EOF
# Auto-generated WiFi configuration (temporary)
WIFI_SSID = "$SSID"
WIFI_PASSWORD = "$PASSWORD"
EOF

# Run the example
mpremote connect /dev/cu.usbmodem5ABA0685451 fs cp examples/wifi_config.py :wifi_config.py + run examples/"$SCRIPT".py

echo ""
echo "Done!"
