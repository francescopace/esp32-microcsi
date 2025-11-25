# SPDX-FileCopyrightText: 2024 ESP32-MicroCSI Contributors
# SPDX-License-Identifier: MIT

"""
MicroPython ESP32 CSI Module - Advanced Analysis Example

This example demonstrates CSI data analysis including:
- Complex amplitude calculation
- Phase extraction
- Statistical analysis
- Data logging
"""

import network
import time
import math

# Import WiFi credentials
try:
    from wifi_config import WIFI_SSID, WIFI_PASSWORD
except ImportError:
    print("Error: wifi_config.py not found!")
    print("Please run this script using: ./scripts/run_example.sh <SSID> <PASSWORD>")
    raise

def calculate_amplitude(csi_data):
    """Calculate amplitude from complex CSI data (I, Q pairs)"""
    amplitudes = []
    for i in range(0, len(csi_data), 2):
        real = csi_data[i]
        imag = csi_data[i+1] if i+1 < len(csi_data) else 0
        amplitude = math.sqrt(real**2 + imag**2)
        amplitudes.append(amplitude)
    return amplitudes

def calculate_phase(csi_data):
    """Calculate phase from complex CSI data (I, Q pairs)"""
    phases = []
    for i in range(0, len(csi_data), 2):
        real = csi_data[i]
        imag = csi_data[i+1] if i+1 < len(csi_data) else 0
        phase = math.atan2(imag, real)
        phases.append(phase)
    return phases

def analyze_frame(frame):
    """Perform statistical analysis on CSI frame"""
    csi_data = frame['data']
    
    # Calculate amplitudes
    amplitudes = calculate_amplitude(csi_data)
    
    if not amplitudes:
        return None
    
    # Statistical measures
    avg_amplitude = sum(amplitudes) / len(amplitudes)
    max_amplitude = max(amplitudes)
    min_amplitude = min(amplitudes)
    
    # Variance
    variance = sum((a - avg_amplitude)**2 for a in amplitudes) / len(amplitudes)
    std_dev = math.sqrt(variance)
    
    return {
        'avg': avg_amplitude,
        'max': max_amplitude,
        'min': min_amplitude,
        'std': std_dev,
        'subcarriers': len(amplitudes)
    }

def log_to_file(filename, frame, analysis):
    """Log frame data to file"""
    try:
        with open(filename, 'a') as f:
            mac_str = ':'.join('%02x' % b for b in frame['mac'])
            f.write(str(frame['timestamp']) + "," + str(frame['rssi']) + "," + str(frame['rate']) + ",")
            f.write(str(frame['mcs']) + "," + str(frame['channel']) + "," + mac_str + ",")
            f.write("%.2f,%.2f," % (analysis['avg'], analysis['max']))
            f.write("%.2f,%.2f\n" % (analysis['min'], analysis['std']))
    except Exception as e:
        print("Error logging to file: " + str(e))

def main():
    # Initialize WiFi in station mode
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    
    print("WiFi initialized")
    mac = wlan.config('mac')
    print("MAC address: " + ':'.join('%02x' % b for b in mac))
    
    # Configure WiFi BEFORE connecting
    print("Configuring WiFi for CSI...")
    wlan.config(pm=wlan.PM_NONE)  # Disable power save
    # Note: protocol and bandwidth are set automatically by MicroPython
    
    # Connect to WiFi
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
    print("IP: " + wlan.ifconfig()[0])
    print()
    
    # Wait for WiFi to be fully ready
    print("Waiting for WiFi to stabilize...")
    time.sleep(2)
    
    # Enable CSI with configuration
    print("Enabling CSI...")
    try:
        wlan.csi_enable(buffer_size=64)
        print("CSI enabled successfully!")
    except OSError as e:
        print("ERROR: Failed to enable CSI")
        print("Error code: " + str(e))
        print("This may indicate:")
        print("  - WiFi not fully initialized")
        print("  - CSI not supported in current WiFi mode")
        print("  - Hardware limitation")
        return
    print("CSI enabled - capturing and analyzing frames...")
    print()
    
    # Initialize logging
    log_filename = "csi_log.csv"
    try:
        with open(log_filename, 'w') as f:
            f.write("timestamp,rssi,rate,mcs,channel,mac,avg_amp,max_amp,min_amp,std_dev\n")
        print("Logging to: " + log_filename)
    except Exception as e:
        print("Warning: Could not create log file: " + str(e))
        log_filename = None
    
    print()
    print("Press Ctrl+C to stop")
    print("-" * 60)
    
    frame_count = 0
    start_time = time.ticks_ms()
    
    try:
        while True:
            frame = wlan.csi_read()
            
            if frame:
                frame_count += 1
                
                # Analyze frame
                analysis = analyze_frame(frame)
                
                if analysis:
                    # Display analysis
                    print("Frame #%4d | RSSI: %3d dBm | MCS: %2d | Subcarriers: %3d | Avg: %6.2f | Std: %6.2f" % 
                          (frame_count, frame['rssi'], frame['mcs'], analysis['subcarriers'], 
                           analysis['avg'], analysis['std']))
                    
                    # Log to file
                    if log_filename:
                        log_to_file(log_filename, frame, analysis)
                    
                    # Show detailed analysis every 10 frames
                    if frame_count % 10 == 0:
                        print()
                        print("  Detailed Analysis (Frame #" + str(frame_count) + "):")
                        print("    Average Amplitude: %.2f" % analysis['avg'])
                        print("    Max Amplitude:     %.2f" % analysis['max'])
                        print("    Min Amplitude:     %.2f" % analysis['min'])
                        print("    Std Deviation:     %.2f" % analysis['std'])
                        print("    Subcarriers:       " + str(analysis['subcarriers']))
                        
                        # Calculate and show phases for first few subcarriers
                        phases = calculate_phase(frame['data'][:10])
                        print("    First 5 phases:    ", end="")
                        for i, phase in enumerate(phases[:5]):
                            print("%6.3f " % phase, end="")
                        print()
                        
                        # Buffer statistics
                        available = wlan.csi_available()
                        dropped = wlan.csi_dropped()
                        print("    Buffer status:     " + str(available) + " available, " + str(dropped) + " dropped")
                        
                        # Throughput
                        elapsed = time.ticks_diff(time.ticks_ms(), start_time) / 1000.0
                        fps = frame_count / elapsed if elapsed > 0 else 0
                        print("    Throughput:        %.1f frames/sec" % fps)
                        print()
            else:
                # No frame available
                time.sleep(0.001)
                
    except KeyboardInterrupt:
        print("\n" + "=" * 60)
        print("Stopping...")
    
    finally:
        # Cleanup and final statistics
        wlan.csi_disable()
        
        elapsed = time.ticks_diff(time.ticks_ms(), start_time) / 1000.0
        
        print()
        print("=" * 60)
        print("Final Statistics:")
        print("=" * 60)
        print("Total frames captured: " + str(frame_count))
        print("Total frames dropped:  " + str(wlan.csi_dropped()))
        print("Elapsed time:          %.2f seconds" % elapsed)
        if elapsed > 0:
            print("Average throughput:    %.2f frames/sec" % (frame_count/elapsed))
        if log_filename:
            print("Data logged to:        " + log_filename)
        print("=" * 60)
        print("CSI disabled")

if __name__ == "__main__":
    main()
