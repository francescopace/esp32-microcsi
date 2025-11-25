#!/bin/bash
# SPDX-FileCopyrightText: 2024 ESP32-MicroCSI Contributors
# SPDX-License-Identifier: MIT
#
# ESP32-MicroCSI Integration Script
# This script integrates the CSI module into MicroPython source

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Integrating CSI Module into MicroPython${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
BUILD_DIR="${PROJECT_ROOT}/build"
MP_DIR="${BUILD_DIR}/micropython"
ESP32_DIR="${MP_DIR}/ports/esp32"

# Check if MicroPython exists
if [ ! -d "${MP_DIR}" ]; then
    echo -e "${RED}Error: MicroPython not found. Run scripts/setup_env.sh first.${NC}"
    exit 1
fi

# Step 0: Reset files to clean state
echo -e "${YELLOW}Step 0: Resetting MicroPython files to clean state...${NC}"
cd "${MP_DIR}"

# Check if it's a git repository
if [ -d ".git" ]; then
    # Reset the entire repository to clean state
    echo -e "${YELLOW}Resetting MicroPython repository to clean state...${NC}"
    git reset --hard HEAD
    git clean -fd
    echo -e "${GREEN}✓ MicroPython repository reset${NC}"
    
    # Initialize required submodules (needed after git clean)
    echo -e "${YELLOW}Initializing required submodules...${NC}"
    git submodule update --init lib/berkeley-db-1.xx lib/micropython-lib 2>/dev/null || true
    echo -e "${GREEN}✓ Submodules initialized${NC}"
    
    # Remove CSI files if they exist (they will be copied fresh)
    if [ -f "${ESP32_DIR}/modwifi_csi.c" ]; then
        rm -f "${ESP32_DIR}/modwifi_csi.c"
        echo -e "${GREEN}✓ Removed old modwifi_csi.c${NC}"
    fi
    if [ -f "${ESP32_DIR}/modwifi_csi.h" ]; then
        rm -f "${ESP32_DIR}/modwifi_csi.h"
        echo -e "${GREEN}✓ Removed old modwifi_csi.h${NC}"
    fi
else
    echo -e "${YELLOW}Warning: Not a git repository, skipping reset${NC}"
    # Still try to remove CSI files if they exist
    if [ -f "${ESP32_DIR}/modwifi_csi.c" ]; then
        rm -f "${ESP32_DIR}/modwifi_csi.c"
        echo -e "${GREEN}✓ Removed old modwifi_csi.c${NC}"
    fi
    if [ -f "${ESP32_DIR}/modwifi_csi.h" ]; then
        rm -f "${ESP32_DIR}/modwifi_csi.h"
        echo -e "${GREEN}✓ Removed old modwifi_csi.h${NC}"
    fi
fi

cd "${PROJECT_ROOT}"

echo -e "${YELLOW}Step 1: Copying CSI module files...${NC}"
cp "${PROJECT_ROOT}/src/modwifi_csi.c" "${ESP32_DIR}/"
cp "${PROJECT_ROOT}/src/modwifi_csi.h" "${ESP32_DIR}/"
echo -e "${GREEN}✓ Files copied${NC}"

echo -e "${YELLOW}Step 2: Updating mpconfigport.h...${NC}"
# Check if CSI flag already exists
if grep -q "MICROPY_PY_NETWORK_WLAN_CSI" "${ESP32_DIR}/mpconfigport.h"; then
    echo -e "${GREEN}✓ CSI flag already present${NC}"
else
    # Add CSI configuration after MICROPY_ESP_IDF_ENTRY (near end of file)
    sed -i '' '/^#define MICROPY_ESP_IDF_ENTRY/a\
\
// WiFi CSI support\
#ifndef MICROPY_PY_NETWORK_WLAN_CSI\
#define MICROPY_PY_NETWORK_WLAN_CSI (1)\
#endif
' "${ESP32_DIR}/mpconfigport.h"
    echo -e "${GREEN}✓ mpconfigport.h updated${NC}"
fi

echo -e "${YELLOW}Step 3: Enabling CSI in sdkconfig.board for all boards...${NC}"
# Enable CSI for all supported boards
BOARDS=("ESP32_GENERIC" "ESP32_GENERIC_S2" "ESP32_GENERIC_S3" "ESP32_GENERIC_C3" "ESP32_GENERIC_C6")
for BOARD in "${BOARDS[@]}"; do
    BOARD_DIR="${ESP32_DIR}/boards/${BOARD}"
    if [ -d "${BOARD_DIR}" ]; then
        SDKCONFIG="${BOARD_DIR}/sdkconfig.board"
        if [ -f "${SDKCONFIG}" ]; then
            if grep -q "CONFIG_ESP_WIFI_CSI_ENABLED" "${SDKCONFIG}"; then
                echo -e "${GREEN}✓ CSI already enabled for ${BOARD}${NC}"
            else
                echo "CONFIG_ESP_WIFI_CSI_ENABLED=y" >> "${SDKCONFIG}"
                echo -e "${GREEN}✓ CSI enabled for ${BOARD}${NC}"
            fi
        else
            # Create sdkconfig.board if it doesn't exist
            echo "CONFIG_ESP_WIFI_CSI_ENABLED=y" > "${SDKCONFIG}"
            echo -e "${GREEN}✓ Created sdkconfig.board and enabled CSI for ${BOARD}${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Board ${BOARD} not found, skipping${NC}"
    fi
done

echo -e "${YELLOW}Step 4: Updating sdkconfig.base...${NC}"
SDKCONFIG_BASE="${ESP32_DIR}/boards/sdkconfig.base"

# Enable CSI for all boards
if ! grep -q "CONFIG_ESP_WIFI_CSI_ENABLED" "${SDKCONFIG_BASE}"; then
    echo "CONFIG_ESP_WIFI_CSI_ENABLED=y" >> "${SDKCONFIG_BASE}"
    echo -e "${GREEN}✓ Added CSI support to sdkconfig.base${NC}"
else
    echo -e "${GREEN}✓ CSI already enabled in sdkconfig.base${NC}"
fi

# Use SIZE optimization instead of PERF
if grep -q "CONFIG_COMPILER_OPTIMIZATION_PERF=y" "${SDKCONFIG_BASE}"; then
    sed -i '' 's/CONFIG_COMPILER_OPTIMIZATION_PERF=y/CONFIG_COMPILER_OPTIMIZATION_SIZE=y/' "${SDKCONFIG_BASE}"
    echo -e "${GREEN}✓ Changed sdkconfig.base to use SIZE optimization${NC}"
else
    echo -e "${GREEN}✓ sdkconfig.base already using SIZE optimization${NC}"
fi

echo -e "${YELLOW}Step 5: Updating esp32_common.cmake...${NC}"
# Check if modwifi_csi.c is already in esp32_common.cmake
if grep -q "modwifi_csi.c" "${ESP32_DIR}/esp32_common.cmake"; then
    echo -e "${GREEN}✓ modwifi_csi.c already in esp32_common.cmake${NC}"
else
    # Add modwifi_csi.c after network_wlan.c in the source list
    sed -i '' '/network_wlan\.c/a\
    modwifi_csi.c
' "${ESP32_DIR}/esp32_common.cmake"
    echo -e "${GREEN}✓ esp32_common.cmake updated${NC}"
fi

echo -e "${YELLOW}Step 6: Patching network_wlan.c...${NC}"
# Check if CSI is already integrated
if grep -q "modwifi_csi.h" "${ESP32_DIR}/network_wlan.c"; then
    echo -e "${GREEN}✓ network_wlan.c already patched${NC}"
else
    # Add include after esp_wifi.h
    sed -i '' '/#include "esp_wifi.h"/a\
\
#if MICROPY_PY_NETWORK_WLAN_CSI\
#include "modwifi_csi.h"\
#endif
' "${ESP32_DIR}/network_wlan.c"
    
    # Add CSI methods to WLAN locals dict (after ipconfig, before constants section)
    sed -i '' '/{ MP_ROM_QSTR(MP_QSTR_ipconfig), MP_ROM_PTR(\&esp_nic_ipconfig_obj) },/a\
\
#if MICROPY_PY_NETWORK_WLAN_CSI\
    { MP_ROM_QSTR(MP_QSTR_csi_enable), MP_ROM_PTR(\&network_wlan_csi_enable_obj) },\
    { MP_ROM_QSTR(MP_QSTR_csi_disable), MP_ROM_PTR(\&network_wlan_csi_disable_obj) },\
    { MP_ROM_QSTR(MP_QSTR_csi_read), MP_ROM_PTR(\&network_wlan_csi_read_obj) },\
    { MP_ROM_QSTR(MP_QSTR_csi_dropped), MP_ROM_PTR(\&network_wlan_csi_dropped_obj) },\
    { MP_ROM_QSTR(MP_QSTR_csi_available), MP_ROM_PTR(\&network_wlan_csi_available_obj) },\
#endif
' "${ESP32_DIR}/network_wlan.c"
    echo -e "${GREEN}✓ network_wlan.c patched${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Integration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Files modified:${NC}"
echo "  - ${ESP32_DIR}/modwifi_csi.c (copied)"
echo "  - ${ESP32_DIR}/modwifi_csi.h (copied)"
echo "  - ${ESP32_DIR}/mpconfigport.h (patched)"
echo "  - ${ESP32_DIR}/esp32_common.cmake (patched)"
echo "  - ${ESP32_DIR}/network_wlan.c (patched)"
echo "  - ${ESP32_DIR}/boards/*/sdkconfig.board (CSI enabled for all supported boards)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Build and flash firmware:"
echo -e "   ${GREEN}./scripts/build_flash.sh${NC}                    # Default: ESP32-S3"
echo ""
echo "   Or specify a different board:"
echo -e "   ${GREEN}./scripts/build_flash.sh -b ESP32_GENERIC${NC}    # ESP32 classic"
echo -e "   ${GREEN}./scripts/build_flash.sh -b ESP32_GENERIC_S2${NC} # ESP32-S2"
echo -e "   ${GREEN}./scripts/build_flash.sh -b ESP32_GENERIC_C3${NC} # ESP32-C3"
echo -e "   ${GREEN}./scripts/build_flash.sh -b ESP32_GENERIC_C6${NC} # ESP32-C6 (WiFi 6)"
echo ""
echo "2. Optional: Add --monitor flag to start serial monitor after flashing:"
echo -e "   ${GREEN}./scripts/build_flash.sh --monitor${NC}"
echo ""
