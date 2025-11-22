# ESP32-MicroCSI - A MicroPython ESP32 CSI Module

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: ESP32](https://img.shields.io/badge/Platform-ESP32-blue.svg)](https://www.espressif.com/en/products/socs/esp32)
[![ESP-IDF](https://img.shields.io/badge/ESP--IDF-v5.4.2-blue.svg)](https://github.com/espressif/esp-idf)
[![MicroPython](https://img.shields.io/badge/MicroPython-v1.26.1-green.svg)](https://micropython.org/)

Native MicroPython module for ESP32 that exposes ESP-IDF CSI (Channel State Information) functionality.

## Requirements

- **ESP-IDF**: v5.4.2
- **MicroPython**: v1.26.1
- **Supported Chips**: ESP32, ESP32-S2, ESP32-S3, ESP32-C3, ESP32-C6
- **Tested Chips**: ESP32-S3, ESP32-C6

## Project Structure

```
ESP32-MicroCSI/
├── src/                    # Source files
│   ├── modwifi_csi.c      # CSI module implementation
│   └── modwifi_csi.h      # CSI module header
├── scripts/                # Build and integration scripts
│   ├── setup_env.sh       # Environment setup script
│   ├── integrate_csi.sh   # CSI integration script
│   ├── build_flash.sh     # Build and flash script
│   └── run_example.sh     # Run examples with WiFi credentials
├── examples/               # Example Python scripts
│   ├── example_csi_basic.py      # Basic CSI capture and display
│   └── example_csi_analysis.py   # Advanced analysis with statistics
├── build/                  # Build artifacts (generated, not in repo)
│   ├── esp-idf/           # ESP-IDF v5.4.2 framework
│   ├── micropython/       # MicroPython v1.26.1 source
│   └── firmware/          # Compiled firmware binaries
├── .gitignore
├── README.md
└── LICENSE
```

**Note**: The `build/` directory is created by `setup_env.sh` and contains ~2-3 GB of downloaded dependencies.

## Quick Start

This project includes automated scripts to build and flash MicroPython with CSI support on your ESP32 device.

### 1. Setup Environment

Install ESP-IDF v5.4.2 and MicroPython v1.26.1:

```bash
./scripts/setup_env.sh
```

This script will:
- Install required tools (cmake, ninja, dfu-util)
- Install Python packages (pyserial, esptool, ampy)
- Clone ESP-IDF v5.4.2 in `build/esp-idf/`
- Clone MicroPython v1.26.1 in `build/micropython/`
- Build mpy-cross compiler
- Install toolchains for all supported ESP32 chips

**Time**: ~15-20 minutes (first run, downloads ~2-3 GB)

### 2. Integrate CSI Module

Patch MicroPython source with CSI module:

```bash
./scripts/integrate_csi.sh
```

This script will:
- Reset MicroPython files to clean state (git reset)
- Initialize required git submodules (lib/berkeley-db-1.xx, lib/micropython-lib)
- Copy `src/modwifi_csi.c` and `src/modwifi_csi.h` to MicroPython `ports/esp32/`
- Update `mpconfigport.h` with CSI configuration flag
- Update `esp32_common.cmake` to include modwifi_csi.c
- Patch `network_wlan.c` to expose `wlan.csi` attribute
- Enable CSI in `sdkconfig.board` for all supported boards
- Add compiler optimizations to reduce firmware size for all boards

**Note:** The script resets the MicroPython repository to ensure a clean integration.

**Compiler Optimizations:**
The integration script automatically modifies `boards/sdkconfig.base` to optimize for size:
- Replaces `CONFIG_COMPILER_OPTIMIZATION_PERF=y` with `CONFIG_COMPILER_OPTIMIZATION_SIZE=y`
- This changes compilation from `-O2` (performance) to `-Os` (size optimization)
- Applied globally to **all ESP32 boards** (ESP32, S2, S3, C3, C6)

These optimizations reduce firmware size by ~5-10% (50-100 KB), which is **critical for ESP32-C6** where the CSI module increases the binary size close to the partition limit.

**Why modify sdkconfig.base?**
- `sdkconfig.base` is processed first and has the highest priority in the configuration hierarchy
- Individual board `sdkconfig.board` files cannot override settings from `sdkconfig.base`
- By modifying the base configuration, we ensure size optimization is applied consistently across all boards

### 3. Build and Flash

Compile MicroPython firmware and flash to your ESP32 device:

```bash
./scripts/build_flash.sh
```

For other ESP32 chips, specify the board:

```bash
./scripts/build_flash.sh -b ESP32_GENERIC        # ESP32 classic
./scripts/build_flash.sh -b ESP32_GENERIC_S2     # ESP32-S2
./scripts/build_flash.sh -b ESP32_GENERIC_C3     # ESP32-C3
./scripts/build_flash.sh -b ESP32_GENERIC_C6     # ESP32-C6 (WiFi 6)
```

This script will:
- Source ESP-IDF environment
- Clean previous build
- Configure for ESP32-S3
- Build firmware (~15-20 minutes first time, ~2-3 minutes incremental)
- Detect ESP32 USB port
- Flash bootloader, partition table, and firmware

**Note**: If flashing fails, put your ESP32 device in download mode:
1. Hold BOOT button
2. Press and release RESET button
3. Release BOOT button
4. Run `./scripts/build_flash.sh` again

### 4. Run CSI Examples

The easiest way to test CSI functionality is using the provided example scripts:

```bash
./scripts/run_example.sh <SSID> <PASSWORD>
```

Example:
```bash
./scripts/run_example.sh MyWiFi MyPassword
```

This will:
- Create a temporary `wifi_config.py` with your credentials
- Upload it to the ESP32 via `mpremote`
- Run the CSI analysis example
- Display real-time CSI data with statistics

**Available examples:**
- `example_csi_basic.py` - Basic CSI capture and display
  - Shows RSSI, rate, MCS, MAC address, timestamp
  - Displays buffer status (available/dropped frames)
  - Simple frame-by-frame output

- `example_csi_analysis.py` - Advanced analysis with statistics
  - Calculates amplitude from complex I/Q data
  - Extracts phase information using `atan2`
  - Computes statistical measures (mean, max, min, std deviation)
  - Logs data to CSV file (`csi_log.csv`)
  - Shows throughput (frames/sec)
  - Detailed analysis every 10 frames

To switch between examples, edit `scripts/run_example.sh` and change the `SCRIPT` variable.

### Alternative: Manual REPL Testing

You can also connect to REPL manually using one of these methods:

**Option 1: Using screen (simplest)**
```bash
screen /dev/cu.usbmodem* 115200
```
(Press Ctrl-A then K to exit)

**Option 2: Using build script with monitor flag**
```bash
./scripts/build_flash.sh --monitor
```

Then in Python REPL:
```python
import network
wlan = network.WLAN(network.STA_IF)
wlan.active(True)
print(hasattr(wlan, 'csi'))  # Should print True
```

### Troubleshooting Setup

**ESP-IDF environment error:**
```bash
# Clean ESP-IDF Python environment
rm -rf ~/.espressif/python_env

# Reinstall
rm -rf build
./scripts/setup_env.sh
```

**Build errors:**
```bash
# Clean build directory
cd build/micropython/ports/esp32
make BOARD=ESP32_GENERIC_S3 clean

# Rebuild
cd /path/to/ESP32-MicroCSI
./scripts/build_flash.sh
```

## Features

- **Complete Python API** for CSI control
- **Lock-free circular buffer** for efficient frame management
- **ISR-safe callback** without dynamic allocations
- **Flexible configuration** with all ESP-IDF parameters
- **Conditional compilation** to reduce binary size
- **Efficient data format** using `bytes` and `array('h')`

## Architecture

### Circular Buffer

The module uses a pre-allocated circular buffer to store received CSI frames:

- **Default size**: 128 frames (configurable 1-1024)
- **Lock-free**: Safe for concurrent ISR/Python access
- **Zero allocations**: Everything pre-allocated at initialization
- **Dropped counter**: Tracks frames lost when buffer is full
- **Memory efficient**: ~750 bytes per frame

### ISR Callback

The C callback (`wifi_csi_rx_cb`) runs in interrupt context:

- Fast copy of data to circular buffer (< 100 µs per frame)
- No Python function calls
- Marked with `IRAM_ATTR` for RAM execution
- Atomic head/tail index management
- No dynamic memory allocation

### CSI Enable Sequence

The `wifi_csi_enable()` function follows a specific sequence that is **critical for all ESP32 chips**:

1. **Verify WiFi state** - Check WiFi is initialized and started
2. **Disable power save** - Set `WIFI_PS_NONE` for real-time CSI
3. **Set WiFi protocol** - Configure 802.11b/g/n (ESP32-C6: also 802.11ax)
4. **Set bandwidth** - Configure HT20 (20MHz)
5. **Enable promiscuous mode** - **CRITICAL**: Must be set BEFORE CSI config (especially for ESP32-C6)
6. **Configure CSI** - Set LTF parameters and filters (API differs between chips)
7. **Register callback** - Set ISR callback function
8. **Enable CSI** - Activate CSI capture

**Important Notes:**
- Step 5 (promiscuous mode) is **mandatory** even if set to `false`
- The order of steps 5-6 is critical: promiscuous mode must be enabled before CSI configuration
- ESP32-C6 uses a different CSI configuration API but the sequence remains the same


### Frame Structure

Each CSI frame contains:

- **Metadata**: RSSI, rate, MCS, bandwidth, channel, etc.
- **MAC address**: Source address (6 bytes)
- **Timestamp**: Microseconds (local and ESP-IDF)
- **CSI data**: Array of complex I/Q values (max 384 elements)
- **Statistics**: Noise floor, AMPDU count, signal length

## Python API

### Configuration

```python
import network

wlan = network.WLAN(network.STA_IF)
wlan.active(True)

# Configure CSI with all parameters
wlan.csi.config(
    lltf_en=True,           # Enable Legacy Long Training Field
    htltf_en=True,          # Enable HT Long Training Field
    stbc_htltf2_en=True,    # Enable STBC HT-LTF2
    ltf_merge_en=True,      # Enable LTF merge
    channel_filter_en=True, # Enable channel filter
    manu_scale=False,       # Manual scale
    shift=0,                # Shift value (0-15)
    buffer_size=128         # Buffer size (1-1024 frames)
)
```

**Note for ESP32-C6:**
- LTF configuration parameters (`lltf_en`, `htltf_en`, etc.) are **accepted but ignored** on ESP32-C6
- ESP32-C6 uses an optimized hardcoded configuration for best performance
- A warning will be logged when calling `wlan.csi.enable()` on ESP32-C6
- Only `buffer_size` parameter is respected on all chips
- ESP32-C6 automatically acquires CSI from: Legacy (802.11a/g), HT20 (802.11n), and WiFi 6 SU (802.11ax) packets

### Enable/Disable

```python
# Enable CSI
wlan.csi.enable()

# Disable CSI
wlan.csi.disable()
```

### Reading Frames

```python
# Non-blocking read (returns None if buffer empty)
frame = wlan.csi.read()

if frame:
    # Format MAC address manually (MicroPython compatible)
    mac_str = ':'.join('%02x' % b for b in frame['mac'])
    
    print("RSSI: " + str(frame['rssi']) + " dBm")
    print("Rate: " + str(frame['rate']))
    print("MCS: " + str(frame['mcs']))
    print("Channel: " + str(frame['channel']))
    print("MAC: " + mac_str)
    print("Timestamp: " + str(frame['timestamp']) + " µs")
    
    # CSI data as array('h')
    csi_data = frame['data']
    print("CSI length: " + str(len(csi_data)))
    
    # Access complex values (I, Q alternating)
    for i in range(0, len(csi_data), 2):
        real = csi_data[i]
        imag = csi_data[i+1] if i+1 < len(csi_data) else 0
        magnitude = (real**2 + imag**2)**0.5
        print("Subcarrier %d: %.2f" % (i//2, magnitude))
```

### Statistics

```python
# Number of frames available in buffer
available = wlan.csi.available()
print("Frames available: " + str(available))

# Number of dropped frames (buffer full)
dropped = wlan.csi.dropped()
print("Frames dropped: " + str(dropped))
```

## CSI Frame Fields

Each CSI frame is a dictionary with the following fields:

| Field | Type | Description | ESP32/S2/S3/C3 | ESP32-C6 |
|-------|------|-------------|----------------|----------|
| `rssi` | `int` | RSSI in dBm | ✅ Available | ✅ Available |
| `rate` | `int` | Data rate | ✅ Available | ✅ Available |
| `sig_mode` | `int` | Signal mode (0=legacy, 1=HT, 3=VHT) | ✅ Available | ⚠️ Always 0 |
| `mcs` | `int` | MCS index | ✅ Available | ⚠️ Always 0 |
| `cwb` | `int` | Channel bandwidth (0=20MHz, 1=40MHz) | ✅ Available | ⚠️ Always 0 |
| `smoothing` | `int` | Smoothing applied | ✅ Available | ⚠️ Always 0 |
| `not_sounding` | `int` | Not sounding frame | ✅ Available | ⚠️ Always 0 |
| `aggregation` | `int` | Aggregation | ✅ Available | ⚠️ Always 0 |
| `stbc` | `int` | STBC | ✅ Available | ⚠️ Always 0 |
| `fec_coding` | `int` | FEC coding (0=BCC, 1=LDPC) | ✅ Available | ⚠️ Always 0 |
| `sgi` | `int` | Short GI | ✅ Available | ⚠️ Always 0 |
| `noise_floor` | `int` | Noise floor in dBm | ✅ Available | ✅ Available |
| `ampdu_cnt` | `int` | AMPDU count | ✅ Available | ⚠️ Always 0 |
| `channel` | `int` | Primary channel | ✅ Available | ✅ Available |
| `secondary_channel` | `int` | Secondary channel | ✅ Available | ⚠️ Always 0 |
| `timestamp` | `int` | Timestamp in microseconds | ✅ Available | ✅ Available |
| `local_timestamp` | `int` | Local timestamp | ✅ Available | ✅ Available |
| `ant` | `int` | Antenna | ✅ Available | ⚠️ Always 0 |
| `sig_len` | `int` | Signal length | ✅ Available | ✅ Available |
| `mac` | `bytes` | Source MAC address (6 bytes) | ✅ Available | ✅ Available |
| `data` | `array('h')` | CSI data (complex values) | ✅ Available | ✅ Available |

**Chip Compatibility Notes:**
- **ESP32, ESP32-S2, ESP32-S3, ESP32-C3**: All fields are available from the hardware
- **ESP32-C6**: Due to hardware differences in the `esp_wifi_rxctrl_t` structure, many metadata fields are not available and are set to 0. This does not affect CSI data quality - the important fields (`rssi`, `rate`, `channel`, `noise_floor`, `timestamp`, `mac`, `data`) are fully available on all chips.

## Complete Example

See `examples/example_csi_basic.py` and `examples/example_csi_analysis.py` for complete working examples.

**Basic example:**

```python
import network
import time

# Initialize WiFi
wlan = network.WLAN(network.STA_IF)
wlan.active(True)

# Connect to WiFi (REQUIRED for CSI)
wlan.connect("YourSSID", "YourPassword")
while not wlan.isconnected():
    time.sleep(0.5)

# Configure CSI
wlan.csi.config(
    lltf_en=True,
    htltf_en=True,
    stbc_htltf2_en=True,
    buffer_size=64
)

# Enable CSI
wlan.csi.enable()

# Reading loop
try:
    while True:
        frame = wlan.csi.read()
        if frame:
            mac_str = ':'.join('%02x' % b for b in frame['mac'])
            print("RSSI: %3d dBm | Rate: %2d | MCS: %2d | MAC: %s" % 
                  (frame['rssi'], frame['rate'], frame['mcs'], mac_str))
        else:
            time.sleep(0.01)  # Wait if buffer empty
            
except KeyboardInterrupt:
    print("\nStopping...")
    
finally:
    # Disable CSI
    wlan.csi.disable()
    print("Dropped frames: " + str(wlan.csi.dropped()))
```

**Quick start with provided scripts:**

```bash
# Run the example with your WiFi credentials
./scripts/run_example.sh YourSSID YourPassword
```

## Technical Notes

### Buffer Sizing

Buffer size depends on frame reception rate:

- **8 frames**: Basic testing, low memory (~6 KB)
- **32 frames**: Normal use (~24 KB)
- **128 frames**: Intensive analysis (~96 KB)
- **1024 frames**: Maximum (~768 KB)

Each frame occupies approximately 750 bytes in memory.

### Performance

- **ISR callback**: < 100 µs per frame
- **Python read**: < 500 µs per frame
- **Throughput**: > 1000 frames/sec

### Limitations

- **Memory**: Pre-allocated buffer, not resizable at runtime
- **Concurrency**: Single Python reader supported
- **WiFi**: Must be in STA or AP+STA mode

## Important Notes

### Multi-Chip Support

The module supports multiple ESP32 variants with automatic configuration:

| Chip | Architecture | WiFi | CSI Support | Tested | Notes |
|------|-------------|------|-------------|--------|-------|
| **ESP32** | Xtensa dual-core | 802.11b/g/n | ✅ Yes | ⚠️ No | Classic ESP32 |
| **ESP32-S2** | Xtensa single-core | 802.11b/g/n | ✅ Yes | ⚠️ No | Lower power |
| **ESP32-S3** | Xtensa dual-core | 802.11b/g/n | ✅ Yes | ✅ Yes | Tested extensively |
| **ESP32-C3** | RISC-V single-core | 802.11b/g/n | ✅ Yes | ⚠️ No | RISC-V architecture |
| **ESP32-C6** | RISC-V single-core | 802.11ax (WiFi 6) | ✅ Yes | ✅ Yes | WiFi 6 support |

**Key Points:**
- All chips use the same Python API
- CSI data format is consistent across all chips
- ESP32-C6 supports WiFi 6 (802.11ax) but CSI works with all WiFi standards
- `CSI_MAX_DATA_LEN` (384) is sufficient for all chips including WiFi 6
- ESP32-C6 uses a different internal CSI API but this is handled automatically

**ESP32-C6 Specific Notes:**
- Uses newer CSI API with `acquire_csi_*` fields instead of `lltf_en`/`htltf_en`
- Automatically enables WiFi 6 (802.11ax) protocol support
- Configuration parameters (`lltf_en`, `htltf_en`, etc.) are accepted but use optimized defaults
- CSI acquisition configured for: Legacy (802.11a/g), HT20 (802.11n), and WiFi 6 SU packets

### General Requirements

- **WiFi Connection Required**: CSI requires an active WiFi connection. Connect to an AP before enabling CSI.
- **Power Save**: Automatically disabled for real-time CSI capture
- **Protocol**: Set to 802.11b/g/n (ESP32-C6 also supports 802.11ax)
- **Bandwidth**: Configured to HT20 (20MHz) by default

### CSI Data Format

- CSI data is returned as `array('h')` containing alternating I/Q values
- Each subcarrier has 2 values: real (I) and imaginary (Q)
- Maximum 384 values (192 subcarriers for HT40)
- Calculate amplitude: `sqrt(I² + Q²)`
- Calculate phase: `atan2(Q, I)`

## License

MIT License - See file headers for complete details.

## Contributions

This module was developed for the MicroPython ESP32 port following project best practices.

## References

- [ESP-IDF CSI Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/wifi.html#wi-fi-channel-state-information)
- [MicroPython ESP32 Port](https://github.com/micropython/micropython/tree/master/ports/esp32)
- [IEEE 802.11 CSI](https://en.wikipedia.org/wiki/Channel_state_information)


## 👤 Author

**Francesco Pace**  
📧 Email: [francesco.pace@gmail.com](mailto:francesco.pace@gmail.com)  
💼 LinkedIn: [linkedin.com/in/francescopace](https://www.linkedin.com/in/francescopace/)  
🛜 Project: [ESP32-MicroCSI](https://github.com/francescopace/esp32-microcsi)
