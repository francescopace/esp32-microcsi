#!/bin/bash
# SPDX-FileCopyrightText: 2024 ESP32-MicroCSI Contributors
# SPDX-License-Identifier: MIT
#
# ESP32-MicroCSI Build and Flash Script
# This script builds MicroPython with CSI module and flashes it to ESP32 devices
#
# Usage: ./build_flash.sh [OPTIONS]
# Options:
#   --board BOARD, -b BOARD:  Board name (default: ESP32_GENERIC_S3)
#                             Examples: ESP32_GENERIC_S3, ESP32_GENERIC, ESP32_GENERIC_S2, ESP32_GENERIC_C3
#   --monitor, -m:            Automatically start monitor after flashing
#   --erase, -e:              Erase entire flash before flashing (usually not needed)
#
# Examples:
#   ./build_flash.sh                          # Build and flash ESP32-S3
#   ./build_flash.sh -b ESP32_GENERIC         # Build and flash ESP32
#   ./build_flash.sh -b ESP32_GENERIC_S2 -m  # Build, flash ESP32-S2 and start monitor

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default board
BOARD="ESP32_GENERIC_S3"

# Parse arguments
START_MONITOR=false
ERASE_FLASH=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --board|-b)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: --board requires a board name${NC}"
                exit 1
            fi
            BOARD="$2"
            shift 2
            ;;
        --monitor|-m)
            START_MONITOR=true
            shift
            ;;
        --erase|-e)
            ERASE_FLASH=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --board BOARD, -b BOARD  Board name (default: ESP32_GENERIC_S3)"
            echo "                           Examples: ESP32_GENERIC_S3, ESP32_GENERIC, ESP32_GENERIC_S2, ESP32_GENERIC_C3"
            echo "  --monitor, -m            Start monitor after flashing"
            echo "  --erase, -e              Erase flash before flashing"
            echo "  --help, -h               Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Building and Flashing MicroPython${NC}"
echo -e "${GREEN}Board: ${BOARD}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
BUILD_DIR="${PROJECT_ROOT}/build"
MP_DIR="${BUILD_DIR}/micropython"
ESP32_DIR="${MP_DIR}/ports/esp32"
IDF_DIR="${BUILD_DIR}/esp-idf"

# Check if ESP-IDF exists
if [ ! -d "${IDF_DIR}" ]; then
    echo -e "${RED}Error: ESP-IDF not found. Run scripts/setup_env.sh first.${NC}"
    exit 1
fi

# Check if MicroPython exists
if [ ! -d "${MP_DIR}" ]; then
    echo -e "${RED}Error: MicroPython not found. Run scripts/setup_env.sh first.${NC}"
    exit 1
fi

# Source ESP-IDF environment
echo -e "${YELLOW}Sourcing ESP-IDF environment...${NC}"
source "${IDF_DIR}/export.sh"
echo -e "${GREEN}✓ ESP-IDF environment loaded${NC}"

# Navigate to ESP32 port
cd "${ESP32_DIR}"

# Clean previous build (optional, comment out for faster rebuilds)
#echo -e "${YELLOW}Cleaning previous build...${NC}"
#make BOARD=${BOARD} clean || true

# Configure for selected board
echo -e "${YELLOW}Configuring for ${BOARD}...${NC}"
make BOARD=${BOARD} submodules

# Build firmware (MicroPython uses make for BOARD configuration)
echo -e "${YELLOW}Building firmware (this may take 15-20 minutes on first build)...${NC}"
make BOARD=${BOARD}

echo -e "${GREEN}✓ Build complete!${NC}"
echo -e "${GREEN}✓ Firmware ready in build-${BOARD}/${NC}"
echo ""

# Detect ESP32 port
echo -e "${YELLOW}Detecting ESP32 device...${NC}"
PORT=""

# Try common macOS USB serial ports
for p in /dev/cu.usbserial-* /dev/cu.usbmodem* /dev/cu.SLAB_USBtoUART*; do
    if [ -e "$p" ]; then
        PORT="$p"
        break
    fi
done

if [ -z "$PORT" ]; then
    echo -e "${RED}Error: ESP32 device not detected.${NC}"
    echo -e "${YELLOW}Please connect your ESP32 device and try again.${NC}"
    echo -e "${YELLOW}Available ports:${NC}"
    ls -la /dev/cu.* 2>/dev/null || echo "No USB devices found"
    exit 1
fi

echo -e "${GREEN}✓ ESP32 device detected on ${PORT}${NC}"
echo ""

# Verify port is still accessible
if [ ! -e "${PORT}" ]; then
    echo -e "${RED}Error: Port ${PORT} is no longer accessible.${NC}"
    echo -e "${YELLOW}Please check the USB connection and try again.${NC}"
    exit 1
fi

# Check if port might be in use (basic check)
if lsof "${PORT}" >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Port ${PORT} appears to be in use by another process.${NC}"
    echo -e "${YELLOW}Please close any programs using this port (e.g., screen, minicom, Arduino IDE)${NC}"
fi

# Flash firmware
echo -e "${YELLOW}Flashing firmware to ${BOARD}...${NC}"
echo -e "${YELLOW}This will install MicroPython with CSI support${NC}"

# Verify port is still accessible before flashing
if [ ! -e "${PORT}" ]; then
    echo -e "${RED}Error: Port ${PORT} is no longer accessible.${NC}"
    echo -e "${YELLOW}Please check the USB connection and try again.${NC}"
    exit 1
fi

# Determine chip type from board name
CHIP_TYPE="esp32s3"  # Default
case "$BOARD" in
    ESP32_GENERIC)
        CHIP_TYPE="esp32"
        ;;
    ESP32_GENERIC_S2)
        CHIP_TYPE="esp32s2"
        ;;
    ESP32_GENERIC_S3)
        CHIP_TYPE="esp32s3"
        ;;
    ESP32_GENERIC_C3)
        CHIP_TYPE="esp32c3"
        ;;
    *)
        # Try to extract chip type from board name
        if [[ "$BOARD" == *"S2"* ]]; then
            CHIP_TYPE="esp32s2"
        elif [[ "$BOARD" == *"S3"* ]]; then
            CHIP_TYPE="esp32s3"
        elif [[ "$BOARD" == *"C3"* ]]; then
            CHIP_TYPE="esp32c3"
        else
            CHIP_TYPE="esp32"
        fi
        ;;
esac

# Erase flash only if requested (usually not needed - make flash overwrites partitions)
if [ "$ERASE_FLASH" = true ]; then
    echo -e "${YELLOW}Erasing entire flash...${NC}"
    if ! esptool.py --chip ${CHIP_TYPE} --port "${PORT}" erase_flash; then
        echo -e "${YELLOW}Warning: Failed to erase flash, continuing anyway...${NC}"
        echo -e "${YELLOW}(make deploy will overwrite the necessary partitions)${NC}"
    fi
else
    echo -e "${GREEN}Note: Skipping full erase (make deploy will overwrite necessary partitions)${NC}"
    echo -e "${YELLOW}Use --erase flag if you need to completely erase the flash${NC}"
    echo -e "${YELLOW}Or use: make BOARD=${BOARD} PORT=\"${PORT}\" erase${NC}"
fi

# Flash firmware using make deploy (MicroPython's build system)
echo -e "${YELLOW}Writing firmware...${NC}"
# MicroPython uses 'deploy' target which calls idf.py flash with correct settings
# PORT variable is automatically converted to -p PORT by the Makefile
if ! make BOARD=${BOARD} PORT="${PORT}" deploy; then
    echo -e "${RED}Failed to write firmware.${NC}"
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Check USB connection"
    echo "  2. Put ESP32 device in download mode (BOOT + RESET)"
    echo "  3. Try a different USB cable/port"
    echo "  4. Check if another program is using the port"
    echo "  5. Verify board name is correct: ${BOARD}"
    exit 1
fi

cd "${PROJECT_ROOT}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Flash Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ "$START_MONITOR" = true ]; then
    echo -e "${YELLOW}Starting monitor...${NC}"
    echo -e "${YELLOW}(Press Ctrl-] to exit)${NC}"
    echo ""
    # Use idf.py monitor from ESP32 port directory (where CMakeLists.txt is)
    # Specify build directory with -B flag
    cd "${ESP32_DIR}"
    idf.py -B "build-${BOARD}" -p "${PORT}" monitor
else
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Run a CSI example with WiFi credentials:"
    echo -e "   ${GREEN}./scripts/run_example.sh <SSID> <PASSWORD>${NC}"
    echo ""
    echo "2. Or run this script with --monitor flag:"
    echo -e "   ${GREEN}./scripts/build_flash.sh --monitor${NC}"
    echo ""
fi
