/*
 * This file is part of the MicroPython project, http://micropython.org/
 *
 * The MIT License (MIT)
 *
 * Copyright (c) 2024 MicroPython CSI Module Contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#ifndef MICROPY_INCLUDED_ESP32_MPCONFIGPORT_H
#define MICROPY_INCLUDED_ESP32_MPCONFIGPORT_H

// ============================================================================
// CSI Module Configuration
// ============================================================================

// Enable/disable WiFi CSI (Channel State Information) support
// Set to 0 to disable CSI support and reduce binary size
// Set to 1 to enable CSI support (default)
#ifndef MICROPY_PY_NETWORK_WLAN_CSI
#define MICROPY_PY_NETWORK_WLAN_CSI (1)
#endif

// ============================================================================
// Notes for Integration
// ============================================================================

/*
 * This is a minimal mpconfigport.h showing only the CSI configuration flag.
 * 
 * In a real MicroPython ESP32 port, this file would contain many other
 * configuration options. To integrate the CSI module into an existing
 * MicroPython ESP32 port, add the following lines to the existing
 * mpconfigport.h file:
 *
 * // WiFi CSI support
 * #ifndef MICROPY_PY_NETWORK_WLAN_CSI
 * #define MICROPY_PY_NETWORK_WLAN_CSI (1)
 * #endif
 *
 * The CSI module can be disabled at build time by setting:
 * MICROPY_PY_NETWORK_WLAN_CSI=0
 *
 * This can be done in several ways:
 * 1. In sdkconfig: Add CONFIG_MICROPY_PY_NETWORK_WLAN_CSI=n
 * 2. In Makefile: Add CFLAGS += -DMICROPY_PY_NETWORK_WLAN_CSI=0
 * 3. In CMakeLists.txt: Add target_compile_definitions(-DMICROPY_PY_NETWORK_WLAN_CSI=0)
 */

#endif // MICROPY_INCLUDED_ESP32_MPCONFIGPORT_H
