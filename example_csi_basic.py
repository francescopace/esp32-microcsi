"""
MicroPython ESP32 CSI Module - Basic Example

This example demonstrates basic CSI capture and display.
"""

import network
import time

def main():
    # Initialize WiFi in station mode
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    
    print("WiFi initialized")
    print(f"MAC address: {wlan.config('mac').hex(':')}")
    
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
                print(f"Frame #{frame_count}")
                print(f"  RSSI:      {frame['rssi']:3d} dBm")
                print(f"  Rate:      {frame['rate']:2d}")
                print(f"  MCS:       {frame['mcs']:2d}")
                print(f"  Channel:   {frame['channel']:2d}")
                print(f"  Bandwidth: {'40MHz' if frame['cwb'] else '20MHz'}")
                print(f"  MAC:       {frame['mac'].hex(':')}")
                print(f"  CSI len:   {len(frame['data'])} samples")
                print(f"  Timestamp: {frame['timestamp']} µs")
                
                # Show buffer status
                available = wlan.csi.available()
                dropped = wlan.csi.dropped()
                print(f"  Buffer:    {available} available, {dropped} dropped")
                print()
                
            else:
                # No frame available, sleep briefly
                time.sleep(0.01)
                
    except KeyboardInterrupt:
        print("\nStopping...")
    
    finally:
        # Cleanup
        wlan.csi.disable()
        print(f"\nTotal frames captured: {frame_count}")
        print(f"Total frames dropped: {wlan.csi.dropped()}")
        print("CSI disabled")

if __name__ == "__main__":
    main()
