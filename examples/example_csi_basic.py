# SPDX-FileCopyrightText: 2024 ESP32-MicroCSI Contributors
# SPDX-License-Identifier: MIT

"""
MicroPython ESP32 CSI Module - Basic Example

This example demonstrates basic CSI capture and display.
"""

import network
import time

# Import WiFi credentials
try:
    from wifi_config import WIFI_SSID, WIFI_PASSWORD
except ImportError:
    print("Error: wifi_config.py not found!")
    print("Please run this script using: ./scripts/run_example.sh <SSID> <PASSWORD>")
    raise

def main():
    # Initialize WiFi in station mode
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    
    print("WiFi initialized")
    mac = wlan.config('mac')
    print("MAC address: " + ':'.join('%02x' % b for b in mac))
    
    # Configure WiFi BEFORE connecting (critical for ESP32-C6 CSI)
    print("Configuring WiFi for CSI...")
    wlan.config(pm=wlan.PM_NONE)  # Disable power save
    # Note: protocol and bandwidth are set automatically by MicroPython
    
    # Connect to WiFi (REQUIRED for CSI)
    print("Connecting to WiFi...")
    wlan.connect(WIFI_SSID, WIFI_PASSWORD)
    
    # Wait for connection
    timeout = 10
    while not wlan.isconnected() and timeout > 0:
        time.sleep(0.5)
        timeout -= 0.5
    
    if not wlan.isconnected():
        print("ERROR: Failed to connect to WiFi!")
        print("CSI requires WiFi connection to work.")
        return
    
    print("WiFi connected to: " + WIFI_SSID)
    print()
    
    # Wait for WiFi to be fully ready (critical for ESP32-C6)
    print("Waiting for WiFi to stabilize...")
    time.sleep(2)
    
    # Configure CSI - use minimal config for ESP32-C6 compatibility
    print("Configuring CSI...")
    try:
        wlan.csi.config(buffer_size=64)
        print("CSI configured (minimal config)")
    except Exception as e:
        print("Error configuring CSI: " + str(e))
        return
    
    # Enable CSI
    print("Enabling CSI...")
    try:
        wlan.csi.enable()
        print("CSI enabled successfully!")
    except OSError as e:
        print("ERROR: Failed to enable CSI")
        print("Error code: " + str(e))
        return
    print("CSI enabled - waiting for frames...")
    print()
    
    frame_count = 0
    
    try:
        while True:
            # Read CSI frame (non-blocking)
            frame = wlan.csi.read()
            
            if frame:
                frame_count += 1
                
                # Display frame information
                print("Frame #" + str(frame_count))
                print("  RSSI:      " + str(frame['rssi']) + " dBm")
                print("  Rate:      " + str(frame['rate']))
                print("  MCS:       " + str(frame['mcs']))
                print("  Channel:   " + str(frame['channel']))
                print("  Bandwidth: " + ("40MHz" if frame['cwb'] else "20MHz"))
                mac_str = ':'.join('%02x' % b for b in frame['mac'])
                print("  MAC:       " + mac_str)
                print("  CSI len:   " + str(len(frame['data'])) + " samples")
                print("  Timestamp: " + str(frame['timestamp']) + " µs")
                
                # Show buffer status
                available = wlan.csi.available()
                dropped = wlan.csi.dropped()
                print("  Buffer:    " + str(available) + " available, " + str(dropped) + " dropped")
                print()
                
            else:
                # No frame available, sleep briefly
                time.sleep(0.01)
                
    except KeyboardInterrupt:
        print("\nStopping...")
    
    finally:
        # Cleanup
        wlan.csi.disable()
        print("\nTotal frames captured: " + str(frame_count))
        print("Total frames dropped: " + str(wlan.csi.dropped()))
        print("CSI disabled")

if __name__ == "__main__":
    main()
