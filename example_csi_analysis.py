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
            f.write(f"{frame['timestamp']},{frame['rssi']},{frame['rate']},")
            f.write(f"{frame['mcs']},{frame['channel']},{frame['mac'].hex(':')},")
            f.write(f"{analysis['avg']:.2f},{analysis['max']:.2f},")
            f.write(f"{analysis['min']:.2f},{analysis['std']:.2f}\n")
    except Exception as e:
        print(f"Error logging to file: {e}")

def main():
    # Initialize WiFi
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    
    print("=" * 60)
    print("MicroPython ESP32 CSI - Advanced Analysis")
    print("=" * 60)
    print(f"MAC address: {wlan.config('mac').hex(':')}")
    print()
    
    # Configure CSI
    wlan.csi.config(
        lltf_en=True,
        htltf_en=True,
        stbc_htltf2_en=True,
        ltf_merge_en=True,
        channel_filter_en=True,
        buffer_size=128
    )
    
    # Enable CSI
    wlan.csi.enable()
    print("CSI enabled - capturing and analyzing frames...")
    print()
    
    # Initialize logging
    log_filename = "csi_log.csv"
    try:
        with open(log_filename, 'w') as f:
            f.write("timestamp,rssi,rate,mcs,channel,mac,avg_amp,max_amp,min_amp,std_dev\n")
        print(f"Logging to: {log_filename}")
    except Exception as e:
        print(f"Warning: Could not create log file: {e}")
        log_filename = None
    
    print()
    print("Press Ctrl+C to stop")
    print("-" * 60)
    
    frame_count = 0
    start_time = time.ticks_ms()
    
    try:
        while True:
            frame = wlan.csi.read()
            
            if frame:
                frame_count += 1
                
                # Analyze frame
                analysis = analyze_frame(frame)
                
                if analysis:
                    # Display analysis
                    print(f"Frame #{frame_count:4d} | "
                          f"RSSI: {frame['rssi']:3d} dBm | "
                          f"MCS: {frame['mcs']:2d} | "
                          f"Subcarriers: {analysis['subcarriers']:3d} | "
                          f"Avg: {analysis['avg']:6.2f} | "
                          f"Std: {analysis['std']:6.2f}")
                    
                    # Log to file
                    if log_filename:
                        log_to_file(log_filename, frame, analysis)
                    
                    # Show detailed analysis every 10 frames
                    if frame_count % 10 == 0:
                        print()
                        print(f"  Detailed Analysis (Frame #{frame_count}):")
                        print(f"    Average Amplitude: {analysis['avg']:.2f}")
                        print(f"    Max Amplitude:     {analysis['max']:.2f}")
                        print(f"    Min Amplitude:     {analysis['min']:.2f}")
                        print(f"    Std Deviation:     {analysis['std']:.2f}")
                        print(f"    Subcarriers:       {analysis['subcarriers']}")
                        
                        # Calculate and show phases for first few subcarriers
                        phases = calculate_phase(frame['data'][:10])
                        print(f"    First 5 phases:    ", end="")
                        for i, phase in enumerate(phases[:5]):
                            print(f"{phase:6.3f} ", end="")
                        print()
                        
                        # Buffer statistics
                        available = wlan.csi.available()
                        dropped = wlan.csi.dropped()
                        print(f"    Buffer status:     {available} available, {dropped} dropped")
                        
                        # Throughput
                        elapsed = time.ticks_diff(time.ticks_ms(), start_time) / 1000.0
                        fps = frame_count / elapsed if elapsed > 0 else 0
                        print(f"    Throughput:        {fps:.1f} frames/sec")
                        print()
            else:
                # No frame available
                time.sleep(0.001)
                
    except KeyboardInterrupt:
        print("\n" + "=" * 60)
        print("Stopping...")
    
    finally:
        # Cleanup and final statistics
        wlan.csi.disable()
        
        elapsed = time.ticks_diff(time.ticks_ms(), start_time) / 1000.0
        
        print()
        print("=" * 60)
        print("Final Statistics:")
        print("=" * 60)
        print(f"Total frames captured: {frame_count}")
        print(f"Total frames dropped:  {wlan.csi.dropped()}")
        print(f"Elapsed time:          {elapsed:.2f} seconds")
        if elapsed > 0:
            print(f"Average throughput:    {frame_count/elapsed:.2f} frames/sec")
        if log_filename:
            print(f"Data logged to:        {log_filename}")
        print("=" * 60)
        print("CSI disabled")

if __name__ == "__main__":
    main()
