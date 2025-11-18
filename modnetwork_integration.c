/*
 * This file is part of the MicroPython project, http://micropython.org/
 *
 * Integration snippet for modnetwork.c
 * 
 * This file shows the modifications needed to integrate the CSI module
 * into the existing modnetwork.c file in the MicroPython ESP32 port.
 *
 * DO NOT compile this file directly. Instead, apply these changes to
 * your existing ports/esp32/modnetwork.c file.
 */

// ============================================================================
// 1. Add include at the top of modnetwork.c
// ============================================================================

#if MICROPY_PY_NETWORK_WLAN_CSI
#include "modwifi_csi.h"
#endif

// ============================================================================
// 2. In the WLAN object locals dictionary, add the CSI attribute
// ============================================================================

// Find the STATIC const mp_rom_map_elem_t wlan_if_locals_dict_table[] section
// and add this entry:

STATIC const mp_rom_map_elem_t wlan_if_locals_dict_table[] = {
    // ... existing entries ...
    
    #if MICROPY_PY_NETWORK_WLAN_CSI
    { MP_ROM_QSTR(MP_QSTR_csi), MP_ROM_PTR(&wifi_csi_type) },
    #endif
    
    // ... rest of entries ...
};

// ============================================================================
// 3. In the WLAN initialization function
// ============================================================================

// Find the function that initializes the WLAN interface (usually wlan_if_make_new
// or similar) and add CSI initialization:

STATIC mp_obj_t wlan_if_make_new(const mp_obj_type_t *type, size_t n_args,
                                  size_t n_kw, const mp_obj_t *args) {
    // ... existing initialization code ...
    
    #if MICROPY_PY_NETWORK_WLAN_CSI
    // Initialize CSI module
    wifi_csi_init();
    #endif
    
    // ... rest of initialization ...
}

// ============================================================================
// 4. In the WLAN deinitialization/cleanup function
// ============================================================================

// Find the function that cleans up the WLAN interface (usually in deinit or
// when the module is unloaded) and add CSI cleanup:

STATIC mp_obj_t wlan_if_deinit(mp_obj_t self_in) {
    // ... existing cleanup code ...
    
    #if MICROPY_PY_NETWORK_WLAN_CSI
    // Deinitialize CSI module
    wifi_csi_deinit();
    #endif
    
    // ... rest of cleanup ...
}

// ============================================================================
// Alternative: Create a singleton CSI object
// ============================================================================

// If you prefer to have a single global CSI object instead of per-WLAN instance,
// you can create it as follows:

#if MICROPY_PY_NETWORK_WLAN_CSI

// Global CSI object instance
STATIC const wifi_csi_obj_t wifi_csi_obj = {
    .base = { &wifi_csi_type },
};

// Then in the WLAN locals dict:
STATIC const mp_rom_map_elem_t wlan_if_locals_dict_table[] = {
    // ... existing entries ...
    
    { MP_ROM_QSTR(MP_QSTR_csi), MP_ROM_PTR(&wifi_csi_obj) },
    
    // ... rest of entries ...
};

#endif

// ============================================================================
// Notes:
// ============================================================================

/*
 * The CSI module is designed to work as an attribute of the WLAN object,
 * accessible as wlan.csi in Python.
 *
 * The actual implementation depends on the structure of your modnetwork.c file.
 * The above snippets show the general pattern - you'll need to adapt them
 * to match your specific code structure.
 *
 * Key points:
 * 1. Include modwifi_csi.h when MICROPY_PY_NETWORK_WLAN_CSI is enabled
 * 2. Add wifi_csi_type to the WLAN object's locals dictionary
 * 3. Call wifi_csi_init() when WLAN is initialized
 * 4. Call wifi_csi_deinit() when WLAN is deinitialized
 *
 * The CSI module maintains its own global state, so it works correctly
 * even if accessed through multiple WLAN object instances.
 */
