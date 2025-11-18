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
    
    # Configure CSI with default settings
    wlan.csi.config(
        lltf_en=True,
        htltf_en=True,
        stbc_htltf2_en=True,
        ltf_merge_en=True,
        channel_filter_en=True,
        buffer_size=64
    )
    print("CSI configured")
    
    # Enable CSI
    wlan.csi.enable()
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
