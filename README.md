# ESP32-MicroCSI - A MicroPython ESP32 CSI Module

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: ESP32](https://img.shields.io/badge/Platform-ESP32-blue.svg)](https://www.espressif.com/en/products/socs/esp32)
[![ESP-IDF](https://img.shields.io/badge/ESP--IDF-v5.4.2-blue.svg)](https://github.com/espressif/esp-idf)
[![MicroPython](https://img.shields.io/badge/MicroPython-v1.26.1-green.svg)](https://micropython.org/)

Native MicroPython module for ESP32 that exposes ESP-IDF CSI (Channel State Information) functionality.

## What is CSI?

Channel State Information (CSI) provides detailed information about the Wi-Fi channel state by analyzing physical layer signals. Unlike simple RSSI measurements, CSI captures the complex channel response across multiple subcarriers, enabling advanced applications such as:

- **Motion Detection**: Detect human presence and movement through Wi-Fi signal changes
- **Indoor Localization**: Precise positioning using Wi-Fi signal fingerprinting
- **Gesture Recognition**: Recognize hand gestures and body movements
- **Device-Free Sensing**: Monitor environments without wearable sensors
- **Activity Recognition**: Identify different types of human activities

This module provides low-level access to CSI data through a simple Python API, making it easy to build Wi-Fi sensing applications on ESP32 devices.

## Requirements

- **ESP-IDF**: v5.4.2
- **MicroPython**: v1.26.1
- **Supported Chips**: ESP32, ESP32-S2, ESP32-S3, ESP32-C3, ESP32-C5, ESP32-C6
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
./scripts/build_flash.sh -b ESP32_GENERIC_C5     # ESP32-C5
./scripts/build_flash.sh -b ESP32_GENERIC_C6     # ESP32-C6
```

**Important for ESP32-C6**: Use the `--clean` flag for the first build after running `integrate_csi.sh` to ensure `CONFIG_ESP_WIFI_CSI_ENABLED` is properly applied:

```bash
./scripts/build_flash.sh -b ESP32_GENERIC_C6 --clean
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
print(hasattr(wlan, 'csi_enable'))  # Should print True
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
- **Efficient data format** using `bytes` and `array('b')` for int8 CSI data
- **Multi-chip support** with automatic configuration for all ESP32 variants
- **Wi-Fi 6 (802.11ax) support** on ESP32-C6 and ESP32-C5

## Architecture

### Circular Buffer

The module uses a pre-allocated circular buffer to store received CSI frames, implementing a lock-free producer-consumer pattern:

- **Producer**: Wi-Fi hardware captures CSI frames and stores them in the buffer (ISR context)
- **Consumer**: Python code reads frames from the buffer at its own pace
- **Default size**: 128 frames (configurable 1-1024)
- **Lock-free**: Safe for concurrent ISR/Python access
- **Zero allocations**: Everything pre-allocated at initialization
- **Dropped counter**: Tracks frames lost when buffer is full
- **Memory efficient**: ~172 bytes per frame (metadata + up to 128 bytes CSI data)

#### Buffer Sizing Guidelines

Choose buffer size based on your application needs:

- **Small buffer (32-64 frames)**: 
  - Lower RAM usage (~5-11KB)
  - Risk of frame drops if Python processing is slow
  - Suitable for simple applications with low traffic

- **Default buffer (128 frames)**: 
  - Balanced approach (~22KB RAM)
  - Handles moderate traffic bursts
  - Recommended for most applications

- **Large buffer (256-512 frames)**: 
  - Minimal frame drops (~44-88KB RAM)
  - Suitable for high-traffic scenarios
  - Best for applications requiring continuous capture

#### Memory Calculation

RAM usage can be estimated as:
```
RAM usage ≈ buffer_size × 172 bytes per frame

Examples:
- 32 frames × 172 bytes = ~5.5KB
- 128 frames × 172 bytes = ~22KB (default)
- 256 frames × 172 bytes = ~44KB
- 512 frames × 172 bytes = ~88KB
```

**Note**: Each frame's `data` field can hold up to 128 bytes of CSI samples (64 subcarriers × 2 for I/Q components). The actual CSI data length varies based on Wi-Fi mode and configuration (typically 52-128 bytes for HT20).

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
5. **Set promiscuous mode** - Call `esp_wifi_set_promiscuous(false)` BEFORE CSI config
6. **Configure CSI** - Set LTF parameters and filters (API differs between chips)
7. **Register callback** - Set ISR callback function
8. **Enable CSI** - Activate CSI capture

**Important Notes:**
- Step 5 (promiscuous mode call) is **mandatory** even though we pass `false`
  - The function call itself initializes internal WiFi structures required for CSI
  - This is especially critical for ESP32-C6 where CSI will fail without this call
  - The `false` value means we're not enabling full promiscuous mode, just preparing the WiFi stack
- The order of steps 5-6 is critical: promiscuous mode must be called before CSI configuration
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

# Enable CSI with configuration (all parameters optional)
wlan.csi_enable(
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
# Enable CSI (with default config)
wlan.csi_enable()

# Or enable with custom config
wlan.csi_enable(buffer_size=64)

# Disable CSI (cleans state and deallocates buffer)
wlan.csi_disable()

# Re-enable requires passing config again
wlan.csi_enable(buffer_size=128)
```

### Reading Frames

```python
# Non-blocking read (returns None if buffer empty)
frame = wlan.csi_read()

if frame:
    # Format MAC address manually (MicroPython compatible)
    mac_str = ':'.join('%02x' % b for b in frame['mac'])
    
    print("RSSI: " + str(frame['rssi']) + " dBm")
    print("Rate: " + str(frame['rate']))
    print("MCS: " + str(frame['mcs']))
    print("Channel: " + str(frame['channel']))
    print("MAC: " + mac_str)
    print("Timestamp: " + str(frame['timestamp']) + " µs")
    
    # CSI data as array('b') - int8 values
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
available = wlan.csi_available()
print("Frames available: " + str(available))

# Number of dropped frames (buffer full)
dropped = wlan.csi_dropped()
print("Frames dropped: " + str(dropped))
```

## CSI Frame Fields

Each CSI frame is a dictionary with the following fields:

| Field | Type | Description | ESP32/S2/S3/C3 | ESP32-C5 | ESP32-C6 |
|-------|------|-------------|----------------|----------|----------|
| `rssi` | `int` | RSSI in dBm | ✅ Available | ✅ Available | ✅ Available |
| `rate` | `int` | Data rate | ✅ Available | ✅ Available | ✅ Available |
| `sig_mode` | `int` | Signal mode (0=legacy, 1=HT, 3=VHT) | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `mcs` | `int` | MCS index | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `cwb` | `int` | Channel bandwidth (0=20MHz, 1=40MHz) | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `smoothing` | `int` | Smoothing applied | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `not_sounding` | `int` | Not sounding frame | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `aggregation` | `int` | Aggregation | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `stbc` | `int` | STBC | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `fec_coding` | `int` | FEC coding (0=BCC, 1=LDPC) | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `sgi` | `int` | Short GI | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `noise_floor` | `int` | Noise floor in dBm | ✅ Available | ✅ Available | ✅ Available |
| `ampdu_cnt` | `int` | AMPDU count | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `channel` | `int` | Primary channel | ✅ Available | ✅ Available | ✅ Available |
| `secondary_channel` | `int` | Secondary channel | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `timestamp` | `int` | Timestamp in microseconds | ✅ Available | ✅ Available | ✅ Available |
| `local_timestamp` | `int` | Local timestamp | ✅ Available | ✅ Available | ✅ Available |
| `ant` | `int` | Antenna | ✅ Available | ⚠️ Always 0 | ⚠️ Always 0 |
| `sig_len` | `int` | Signal length | ✅ Available | ✅ Available | ✅ Available |
| `mac` | `bytes` | Source MAC address (6 bytes) | ✅ Available | ✅ Available | ✅ Available |
| `data` | `array('b')` | CSI data (int8 I/Q values) | ✅ Available | ✅ Available | ✅ Available |

**Chip Compatibility Notes:**
- **ESP32, ESP32-S2, ESP32-S3, ESP32-C3**: All fields are available from the hardware
- **ESP32-C5, ESP32-C6**: Due to hardware differences in the `esp_wifi_rxctrl_t` structure, many metadata fields are not available and are set to 0. This does not affect CSI data quality - the important fields (`rssi`, `rate`, `channel`, `noise_floor`, `timestamp`, `mac`, `data`) are fully available on all chips.
- **ESP32-C5 vs ESP32-C6**: The main difference is that ESP32-C5 does not support the `acquire_csi_he_stbc` configuration field (WiFi 6 HE STBC packets), while ESP32-C6 does. Both chips have identical CSI frame field availability.

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

# Enable CSI with buffer configuration
# buffer_size: Number of CSI frames to store in circular buffer
# Each frame is ~172 bytes (metadata + up to 128 bytes of CSI data)
# Larger buffer = less frame drops, but more RAM usage
wlan.csi_enable(buffer_size=64)  # Store up to 64 frames (~11KB RAM)

# Reading loop
try:
    while True:
        frame = wlan.csi_read()
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
    wlan.csi_disable()
    print("Dropped frames: " + str(wlan.csi_dropped()))
```

**Quick start with provided scripts:**

```bash
# Run the example with your WiFi credentials
./scripts/run_example.sh YourSSID YourPassword
```

## Testing

### Test Results

The module has been extensively tested on ESP32-S3 and ESP32-C6:

**ESP32-S3 Test Results:**
- ✅ Successfully captured CSI frames with RSSI=-48 dBm, Channel=4, 256 samples
- ✅ Circular buffer working correctly: 63 frames captured, 28 dropped during overflow test
- ✅ All API methods verified: `config()`, `enable()`, `disable()`, `read()`, `available()`, `dropped()`
- ✅ Buffer overflow handling: `dropped()` counter correctly tracks lost frames when buffer is full

**ESP32-C6 Test Results:**
- ✅ All CSI functionality working correctly with Wi-Fi 6 support
- ✅ Wi-Fi 6 (802.11ax) CSI capture confirmed using the new ESP-IDF 5.x API
- ✅ `acquire_csi_*` configuration fields working as expected
- ✅ Successfully captured CSI from Legacy (802.11a/g), HT20 (802.11n), and WiFi 6 SU packets

**Untested Chips:**
- ⚠️ ESP32, ESP32-S2, ESP32-C3, ESP32-C5: Not tested due to hardware availability
- ✅ Code includes conditional compilation for all variants based on ESP-IDF documentation
- ✅ Firmware compiles successfully for all ESP32_GENERIC boards

### Multi-Chip Support

The module supports multiple ESP32 variants with automatic configuration:

| Chip | Architecture | WiFi | CSI Support | Tested | Notes |
|------|-------------|------|-------------|--------|-------|
| **ESP32** | Xtensa dual-core | 802.11b/g/n | ✅ Yes | ⚠️ No | Classic ESP32 |
| **ESP32-S2** | Xtensa single-core | 802.11b/g/n | ✅ Yes | ⚠️ No | Lower power |
| **ESP32-S3** | Xtensa dual-core | 802.11b/g/n | ✅ Yes | ✅ Yes | Tested extensively |
| **ESP32-C3** | RISC-V single-core | 802.11b/g/n | ✅ Yes | ⚠️ No | RISC-V architecture |
| **ESP32-C5** | RISC-V single-core | 802.11ax (WiFi 6) | ✅ Yes | ⚠️ No | Dual-band 2.4/5 GHz WiFi 6 |
| **ESP32-C6** | RISC-V single-core | 802.11ax (WiFi 6) | ✅ Yes | ✅ Yes | Tested extensively |

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
- Hardware limitation: `esp_wifi_rxctrl_t` structure has fewer fields compared to other ESP32 chips
  - Many metadata fields (mcs, cwb, stbc, etc.) are not available in hardware and return 0
  - This is a hardware/driver limitation, not a bug in the module
  - Critical fields (rssi, rate, channel, noise_floor, timestamp, mac, CSI data) work correctly

## Trade-offs and Design Decisions

### Code Size Impact

The CSI module adds approximately **15KB** to the firmware when enabled:

- Total application size: ~1.87MB (fits in 2MB partition with 8% free space)
- Conditional compilation via `MICROPY_PY_NETWORK_WLAN_CSI` allows disabling if needed
- Compiler optimizations (`-Os`) reduce overall firmware size by ~5-10%

### Justification

The 15KB overhead is justified because:

1. **New Application Categories**: CSI enables entirely new use cases (sensing, localization, gesture recognition)
2. **Optional Feature**: Can be disabled via build configuration if not needed
3. **Efficient Implementation**: Lock-free ISR-safe design with minimal overhead
4. **Comparable Footprint**: Similar features (Bluetooth, ESP-NOW) have comparable or larger footprints

### Alternative Approaches Considered

**Initial Approach**: Created separate `sdkconfig.board` files for each board
- ❌ More complex to maintain
- ❌ Inconsistent across boards
- ❌ Harder to update

**Final Approach**: Single `CONFIG_ESP_WIFI_CSI_ENABLED=y` line in `sdkconfig.base`
- ✅ Better maintainability
- ✅ Consistency across all ESP32 variants
- ✅ Simpler configuration hierarchy

### Design Decisions

1. **Circular Buffer**: Chosen over dynamic allocation for ISR safety and predictable performance
2. **Singleton Pattern**: One CSI instance per WLAN interface for simplicity
3. **Conditional API**: Different configuration for ESP32-C6 WiFi 6 vs legacy chips
4. **Pre-allocated Frames**: Avoids memory fragmentation and ensures deterministic behavior
5. **Lock-free Implementation**: Enables safe concurrent access from ISR and Python contexts

## Technical Notes

### General Requirements

- **WiFi Connection Required**: CSI requires an active WiFi connection. Connect to an AP before enabling CSI.
- **Power Save**: Should be disabled for real-time CSI capture (configure with `wlan.config(pm=wlan.PM_NONE)`)
- **Protocol**: Automatically set to 802.11b/g/n (ESP32-C6 also supports 802.11ax)
- **Bandwidth**: Automatically configured to HT20 (20MHz) for optimal stability

### Bandwidth Support

The module currently supports **HT20 (20MHz) bandwidth only**:

- **HT20 Configuration**: Automatically set by the module in `wifi_csi_enable()`
- **Subcarriers**: 64 subcarriers available with HT20
- **Stability**: HT20 is more stable and has less interference than HT40
- **Compatibility**: Tested on 2.4GHz band

**Future Support**: HT40 (40MHz) support is planned for future releases:
- HT40 provides 128 subcarriers for higher resolution CSI analysis
- Requires 5GHz band testing and validation
- Better suited for high-bandwidth applications
- Will be added after thorough testing on 5GHz networks

### CSI Data Format

- CSI data is returned as `array('b')` containing alternating int8 I/Q values
- Each subcarrier has 2 values: real (I) and imaginary (Q)
- Value range: -128 to +127 (int8_t, matches ESP-IDF API)
- HT20: 128 values (64 subcarriers × 2)
- HT40: 256 values (128 subcarriers × 2) - future support
- Calculate amplitude: `sqrt(I² + Q²)`
- Calculate phase: `atan2(Q, I)`

### Limitations

- **Memory**: Pre-allocated buffer, not resizable at runtime
- **Concurrency**: Single Python reader supported
- **WiFi**: Must be in STA or AP+STA mode
- **Bandwidth**: HT20 only (HT40 support planned)

## Related Projects

The CSI acquisition implementation in this module is based on techniques developed in the [ESPectre](https://github.com/francescopace/espectre) project, a Wi-Fi-based motion detection system. The MicroPython CSI module provides the low-level CSI capture functionality that can serve as a foundation for Wi-Fi sensing applications.

## License

MIT License - See file headers for complete details.

## Contributions

This module was developed for the MicroPython ESP32 port following project best practices.

## References

- [ESP-IDF CSI Documentation](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/api-guides/wifi.html#wi-fi-channel-state-information)
- [MicroPython ESP32 Port](https://github.com/micropython/micropython/tree/master/ports/esp32)
- [IEEE 802.11 CSI](https://en.wikipedia.org/wiki/Channel_state_information)
- [ESPectre Project](https://github.com/francescopace/espectre) - Wi-Fi-based motion detection system

## 👤 Author

**Francesco Pace**  
📧 Email: [francesco.pace@gmail.com](mailto:francesco.pace@gmail.com)  
💼 LinkedIn: [linkedin.com/in/francescopace](https://www.linkedin.com/in/francescopace/)  
🛜 Project: [ESP32-MicroCSI](https://github.com/francescopace/esp32-microcsi)
