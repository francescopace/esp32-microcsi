#!/bin/bash
# SPDX-FileCopyrightText: 2024 ESP32-MicroCSI Contributors
# SPDX-License-Identifier: MIT
#
# ESP32-MicroCSI Environment Setup Script
# This script sets up ESP-IDF and MicroPython for building the CSI module

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ESP32-MicroCSI Environment Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"
BUILD_DIR="${PROJECT_ROOT}/build"

# Create build directory
echo -e "${YELLOW}Creating build directory...${NC}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Check for required tools
echo -e "${YELLOW}Checking for required tools...${NC}"

# Check for Homebrew (macOS)
if ! command -v brew &> /dev/null; then
    echo -e "${RED}Homebrew not found. Please install it first:${NC}"
    echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python 3 not found. Installing via Homebrew...${NC}"
    brew install python3
fi

echo -e "${GREEN}✓ Python $(python3 --version) found${NC}"

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
brew install cmake ninja dfu-util

# Install Python packages
echo -e "${YELLOW}Checking Python packages...${NC}"
python3 -m pip install --break-system-packages --upgrade pip --quiet
for pkg in pyserial esptool adafruit-ampy; do
    if python3 -m pip show --break-system-packages "$pkg" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ $pkg already installed${NC}"
    else
        echo -e "${YELLOW}Installing $pkg...${NC}"
        python3 -m pip install --break-system-packages "$pkg"
    fi
done

# Setup ESP-IDF
ESP_IDF_VERSION="v5.4.2"
if [ ! -d "esp-idf" ]; then
    echo -e "${YELLOW}Cloning ESP-IDF ${ESP_IDF_VERSION}...${NC}"
    git clone --recursive --branch ${ESP_IDF_VERSION} https://github.com/espressif/esp-idf.git
    cd esp-idf
    echo -e "${YELLOW}Installing ESP-IDF tools...${NC}"
    ./install.sh esp32s3
    cd ..
else
    echo -e "${YELLOW}ESP-IDF already present, checking version...${NC}"
    cd esp-idf
    # Check if we're on the correct tag/version
    CURRENT_TAG=$(git describe --tags --exact-match HEAD 2>/dev/null || echo "")
    if [ "$CURRENT_TAG" != "${ESP_IDF_VERSION}" ]; then
        # Fetch tags and check if tag exists
        git fetch --tags --quiet 2>/dev/null || true
        if git rev-parse --verify "${ESP_IDF_VERSION}^{tag}" >/dev/null 2>&1; then
            echo -e "${YELLOW}Updating ESP-IDF to ${ESP_IDF_VERSION}...${NC}"
            git checkout ${ESP_IDF_VERSION}
            echo -e "${YELLOW}Updating submodules...${NC}"
            git submodule update --init --recursive
        else
            echo -e "${YELLOW}Tag ${ESP_IDF_VERSION} not found, fetching...${NC}"
            git fetch --tags
            git checkout ${ESP_IDF_VERSION}
            echo -e "${YELLOW}Updating submodules...${NC}"
            git submodule update --init --recursive
        fi
    else
        echo -e "${GREEN}✓ ESP-IDF already at ${ESP_IDF_VERSION}${NC}"
    fi
    
    # Check if tools are installed (check for toolchain directory)
    if [ ! -d "$HOME/.espressif/tools" ] || [ -z "$(ls -A $HOME/.espressif/tools 2>/dev/null)" ]; then
        echo -e "${YELLOW}Installing ESP-IDF tools...${NC}"
        ./install.sh esp32s3
    else
        echo -e "${GREEN}✓ ESP-IDF tools already installed${NC}"
    fi
    cd ..
fi

# Setup MicroPython
MP_VERSION="v1.26.1"
if [ ! -d "micropython" ]; then
    echo -e "${YELLOW}Cloning MicroPython ${MP_VERSION}...${NC}"
    git clone https://github.com/micropython/micropython.git
    cd micropython
    echo -e "${YELLOW}Checking out ${MP_VERSION}...${NC}"
    git checkout ${MP_VERSION}
    echo -e "${YELLOW}Updating submodules...${NC}"
    git submodule update --init
    echo -e "${YELLOW}Building mpy-cross...${NC}"
    cd mpy-cross
    make CFLAGS_EXTRA="-Wno-gnu-folding-constant"
    cd ../..
else
    echo -e "${YELLOW}MicroPython already present, checking version...${NC}"
    cd micropython
    # Check if we're on the correct tag/version
    CURRENT_TAG=$(git describe --tags --exact-match HEAD 2>/dev/null || echo "")
    if [ "$CURRENT_TAG" != "${MP_VERSION}" ]; then
        # Fetch tags and check if tag exists
        git fetch --tags --quiet 2>/dev/null || true
        if git rev-parse --verify "${MP_VERSION}^{tag}" >/dev/null 2>&1; then
            echo -e "${YELLOW}Updating MicroPython to ${MP_VERSION}...${NC}"
            git checkout ${MP_VERSION}
            echo -e "${YELLOW}Updating submodules...${NC}"
            git submodule update --init --recursive
        else
            echo -e "${YELLOW}Tag ${MP_VERSION} not found, fetching...${NC}"
            git fetch --tags
            git checkout ${MP_VERSION}
            echo -e "${YELLOW}Updating submodules...${NC}"
            git submodule update --init --recursive
        fi
    else
        echo -e "${GREEN}✓ MicroPython already at ${MP_VERSION}${NC}"
    fi
    
    # Check if mpy-cross is built
    if [ ! -f "mpy-cross/mpy-cross" ]; then
        echo -e "${YELLOW}Building mpy-cross...${NC}"
        cd mpy-cross
        make CFLAGS_EXTRA="-Wno-gnu-folding-constant"
        cd ..
    else
        echo -e "${GREEN}✓ mpy-cross already built${NC}"
    fi
    cd ..
fi

# Create firmware directory
mkdir -p firmware

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "1. Run integration script:"
echo -e "   ${GREEN}./scripts/integrate_csi.sh${NC}"
echo ""
echo "2. Build and flash:"
echo -e "   ${GREEN}./scripts/build_flash.sh${NC}"
echo ""
