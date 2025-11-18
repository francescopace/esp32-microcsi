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

#include "py/runtime.h"
#include "py/mphal.h"
#include "py/objarray.h"

#if MICROPY_PY_NETWORK_WLAN_CSI

#include "modwifi_csi.h"
#include "esp_wifi.h"
#include "esp_log.h"
#include "esp_timer.h"
#include <string.h>

static const char *TAG = "wifi_csi";

// Global CSI state
csi_state_t g_csi_state = {
    .buffer = {
        .frames = NULL,
        .head = 0,
        .tail = 0,
        .size = 0,
        .dropped = 0,
        .initialized = false,
    },
    .config = {
        .lltf_en = true,
        .htltf_en = true,
        .stbc_htltf2_en = true,
        .ltf_merge_en = true,
        .channel_filter_en = true,
        .manu_scale = false,
        .shift = 0,
        .buffer_size = CSI_DEFAULT_BUFFER_SIZE,
    },
    .enabled = false,
};

// ============================================================================
// Circular Buffer Implementation (Lock-Free)
// ============================================================================

static bool csi_buffer_init(csi_buffer_t *buf, uint32_t size) {
    if (buf->initialized) {
        // Already initialized, free old buffer
        if (buf->frames) {
            free(buf->frames);
        }
    }

    buf->frames = (csi_frame_t *)malloc(sizeof(csi_frame_t) * size);
    if (buf->frames == NULL) {
        ESP_LOGE(TAG, "Failed to allocate CSI buffer");
        return false;
    }

    buf->size = size;
    buf->head = 0;
    buf->tail = 0;
    buf->dropped = 0;
    buf->initialized = true;

    ESP_LOGI(TAG, "CSI buffer initialized: %lu frames", (unsigned long)size);
    return true;
}

static void csi_buffer_deinit(csi_buffer_t *buf) {
    if (buf->initialized && buf->frames) {
        free(buf->frames);
        buf->frames = NULL;
        buf->initialized = false;
    }
}

static bool csi_buffer_is_empty(const csi_buffer_t *buf) {
    return buf->head == buf->tail;
}

static bool csi_buffer_is_full(const csi_buffer_t *buf) {
    return ((buf->head + 1) % buf->size) == buf->tail;
}

// Called from ISR context - must be fast and non-blocking
static bool csi_buffer_write(csi_buffer_t *buf, const csi_frame_t *frame) {
    if (!buf->initialized) {
        return false;
    }

    uint32_t next_head = (buf->head + 1) % buf->size;
    
    if (next_head == buf->tail) {
        // Buffer full, drop frame
        buf->dropped++;
        return false;
    }

    // Copy frame data
    memcpy(&buf->frames[buf->head], frame, sizeof(csi_frame_t));
    
    // Update head (atomic on ESP32)
    buf->head = next_head;
    
    return true;
}

// Called from Python context
static bool csi_buffer_read(csi_buffer_t *buf, csi_frame_t *frame) {
    if (!buf->initialized || csi_buffer_is_empty(buf)) {
        return false;
    }

    // Copy frame data
    memcpy(frame, &buf->frames[buf->tail], sizeof(csi_frame_t));
    
    // Update tail
    buf->tail = (buf->tail + 1) % buf->size;
    
    return true;
}

// ============================================================================
// CSI Callback (ISR Context)
// ============================================================================

void IRAM_ATTR wifi_csi_rx_cb(void *ctx, wifi_csi_info_t *info) {
    if (!g_csi_state.enabled || !g_csi_state.buffer.initialized) {
        return;
    }

    csi_frame_t frame;
    memset(&frame, 0, sizeof(csi_frame_t));

    // Extract metadata
    frame.rssi = info->rx_ctrl.rssi;
    frame.rate = info->rx_ctrl.rate;
    frame.sig_mode = info->rx_ctrl.sig_mode;
    frame.mcs = info->rx_ctrl.mcs;
    frame.cwb = info->rx_ctrl.cwb;
    frame.smoothing = info->rx_ctrl.smoothing;
    frame.not_sounding = info->rx_ctrl.not_sounding;
    frame.aggregation = info->rx_ctrl.aggregation;
    frame.stbc = info->rx_ctrl.stbc;
    frame.fec_coding = info->rx_ctrl.fec_coding;
    frame.sgi = info->rx_ctrl.sgi;
    frame.noise_floor = info->rx_ctrl.noise_floor;
    frame.ampdu_cnt = info->rx_ctrl.ampdu_cnt;
    frame.channel = info->rx_ctrl.channel;
    frame.secondary_channel = info->rx_ctrl.secondary_channel;
    frame.local_timestamp = info->rx_ctrl.timestamp;
    frame.ant = info->rx_ctrl.ant;
    frame.sig_len = info->rx_ctrl.sig_len;
    frame.rx_state = info->rx_ctrl.rx_state;

    // Copy MAC address
    memcpy(frame.mac, info->mac, 6);

    // Get timestamp
    frame.timestamp_us = (uint32_t)esp_timer_get_time();

    // Copy CSI data
    frame.len = info->len > CSI_MAX_DATA_LEN ? CSI_MAX_DATA_LEN : info->len;
    if (info->buf && frame.len > 0) {
        memcpy(frame.data, info->buf, frame.len * sizeof(int16_t));
    }

    // Write to circular buffer
    csi_buffer_write(&g_csi_state.buffer, &frame);
}

// ============================================================================
// CSI Control Functions
// ============================================================================

void wifi_csi_init(void) {
    // Initialize with default configuration
    if (!g_csi_state.buffer.initialized) {
        csi_buffer_init(&g_csi_state.buffer, g_csi_state.config.buffer_size);
    }
}

void wifi_csi_deinit(void) {
    if (g_csi_state.enabled) {
        wifi_csi_disable();
    }
    csi_buffer_deinit(&g_csi_state.buffer);
}

esp_err_t wifi_csi_enable(void) {
    if (g_csi_state.enabled) {
        return ESP_OK;
    }

    // Ensure buffer is initialized
    if (!g_csi_state.buffer.initialized) {
        if (!csi_buffer_init(&g_csi_state.buffer, g_csi_state.config.buffer_size)) {
            return ESP_ERR_NO_MEM;
        }
    }

    // Configure CSI
    wifi_csi_config_t csi_config = {
        .lltf_en = g_csi_state.config.lltf_en,
        .htltf_en = g_csi_state.config.htltf_en,
        .stbc_htltf2_en = g_csi_state.config.stbc_htltf2_en,
        .ltf_merge_en = g_csi_state.config.ltf_merge_en,
        .channel_filter_en = g_csi_state.config.channel_filter_en,
        .manu_scale = g_csi_state.config.manu_scale,
        .shift = g_csi_state.config.shift,
    };

    esp_err_t ret = esp_wifi_set_csi_config(&csi_config);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to set CSI config: %d", ret);
        return ret;
    }

    // Register callback
    ret = esp_wifi_set_csi_rx_cb(wifi_csi_rx_cb, NULL);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to set CSI callback: %d", ret);
        return ret;
    }

    // Enable CSI
    ret = esp_wifi_set_csi(true);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to enable CSI: %d", ret);
        return ret;
    }

    g_csi_state.enabled = true;
    ESP_LOGI(TAG, "CSI enabled");
    return ESP_OK;
}

esp_err_t wifi_csi_disable(void) {
    if (!g_csi_state.enabled) {
        return ESP_OK;
    }

    esp_err_t ret = esp_wifi_set_csi(false);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to disable CSI: %d", ret);
        return ret;
    }

    g_csi_state.enabled = false;
    ESP_LOGI(TAG, "CSI disabled");
    return ESP_OK;
}

esp_err_t wifi_csi_config(const csi_config_t *config) {
    if (config == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    // Update configuration
    memcpy(&g_csi_state.config, config, sizeof(csi_config_t));

    // Reinitialize buffer if size changed
    if (config->buffer_size != g_csi_state.buffer.size) {
        bool was_enabled = g_csi_state.enabled;
        
        if (was_enabled) {
            wifi_csi_disable();
        }

        csi_buffer_deinit(&g_csi_state.buffer);
        if (!csi_buffer_init(&g_csi_state.buffer, config->buffer_size)) {
            return ESP_ERR_NO_MEM;
        }

        if (was_enabled) {
            return wifi_csi_enable();
        }
    } else if (g_csi_state.enabled) {
        // If already enabled, update configuration
        return wifi_csi_enable();
    }

    return ESP_OK;
}

bool wifi_csi_read_frame(csi_frame_t *frame) {
    return csi_buffer_read(&g_csi_state.buffer, frame);
}

// ============================================================================
// MicroPython Bindings
// ============================================================================

// wifi.csi.enable()
STATIC mp_obj_t wifi_csi_enable_obj(mp_obj_t self_in) {
    esp_err_t ret = wifi_csi_enable();
    if (ret != ESP_OK) {
        mp_raise_OSError(ret);
    }
    return mp_const_none;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_1(wifi_csi_enable_obj_obj, wifi_csi_enable_obj);

// wifi.csi.disable()
STATIC mp_obj_t wifi_csi_disable_obj(mp_obj_t self_in) {
    esp_err_t ret = wifi_csi_disable();
    if (ret != ESP_OK) {
        mp_raise_OSError(ret);
    }
    return mp_const_none;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_1(wifi_csi_disable_obj_obj, wifi_csi_disable_obj);

// wifi.csi.config(**kwargs)
STATIC mp_obj_t wifi_csi_config_obj(size_t n_args, const mp_obj_t *args, mp_map_t *kw_args) {
    enum { 
        ARG_lltf_en, ARG_htltf_en, ARG_stbc_htltf2_en, ARG_ltf_merge_en,
        ARG_channel_filter_en, ARG_manu_scale, ARG_shift, ARG_buffer_size
    };
    static const mp_arg_t allowed_args[] = {
        { MP_QSTR_lltf_en, MP_ARG_KW_ONLY | MP_ARG_BOOL, {.u_bool = true} },
        { MP_QSTR_htltf_en, MP_ARG_KW_ONLY | MP_ARG_BOOL, {.u_bool = true} },
        { MP_QSTR_stbc_htltf2_en, MP_ARG_KW_ONLY | MP_ARG_BOOL, {.u_bool = true} },
        { MP_QSTR_ltf_merge_en, MP_ARG_KW_ONLY | MP_ARG_BOOL, {.u_bool = true} },
        { MP_QSTR_channel_filter_en, MP_ARG_KW_ONLY | MP_ARG_BOOL, {.u_bool = true} },
        { MP_QSTR_manu_scale, MP_ARG_KW_ONLY | MP_ARG_BOOL, {.u_bool = false} },
        { MP_QSTR_shift, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = 0} },
        { MP_QSTR_buffer_size, MP_ARG_KW_ONLY | MP_ARG_INT, {.u_int = CSI_DEFAULT_BUFFER_SIZE} },
    };

    mp_arg_val_t parsed_args[MP_ARRAY_SIZE(allowed_args)];
    mp_arg_parse_all(n_args - 1, args + 1, kw_args, MP_ARRAY_SIZE(allowed_args), allowed_args, parsed_args);

    csi_config_t config = g_csi_state.config;

    config.lltf_en = parsed_args[ARG_lltf_en].u_bool;
    config.htltf_en = parsed_args[ARG_htltf_en].u_bool;
    config.stbc_htltf2_en = parsed_args[ARG_stbc_htltf2_en].u_bool;
    config.ltf_merge_en = parsed_args[ARG_ltf_merge_en].u_bool;
    config.channel_filter_en = parsed_args[ARG_channel_filter_en].u_bool;
    config.manu_scale = parsed_args[ARG_manu_scale].u_bool;
    config.shift = parsed_args[ARG_shift].u_int & 0x0F; // Limit to 0-15
    config.buffer_size = parsed_args[ARG_buffer_size].u_int;

    if (config.buffer_size < 1 || config.buffer_size > 1024) {
        mp_raise_ValueError(MP_ERROR_TEXT("buffer_size must be between 1 and 1024"));
    }

    esp_err_t ret = wifi_csi_config(&config);
    if (ret != ESP_OK) {
        mp_raise_OSError(ret);
    }

    return mp_const_none;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_KW(wifi_csi_config_obj_obj, 1, wifi_csi_config_obj);

// wifi.csi.read() -> dict or None
STATIC mp_obj_t wifi_csi_read_obj(mp_obj_t self_in) {
    csi_frame_t frame;
    
    if (!wifi_csi_read_frame(&frame)) {
        return mp_const_none;
    }

    // Create dictionary for frame data
    mp_obj_t dict = mp_obj_new_dict(20);

    // Add metadata
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_rssi), mp_obj_new_int(frame.rssi));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_rate), mp_obj_new_int(frame.rate));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_sig_mode), mp_obj_new_int(frame.sig_mode));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_mcs), mp_obj_new_int(frame.mcs));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_cwb), mp_obj_new_int(frame.cwb));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_smoothing), mp_obj_new_int(frame.smoothing));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_not_sounding), mp_obj_new_int(frame.not_sounding));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_aggregation), mp_obj_new_int(frame.aggregation));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_stbc), mp_obj_new_int(frame.stbc));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_fec_coding), mp_obj_new_int(frame.fec_coding));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_sgi), mp_obj_new_int(frame.sgi));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_noise_floor), mp_obj_new_int(frame.noise_floor));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_ampdu_cnt), mp_obj_new_int(frame.ampdu_cnt));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_channel), mp_obj_new_int(frame.channel));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_secondary_channel), mp_obj_new_int(frame.secondary_channel));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_timestamp), mp_obj_new_int(frame.timestamp_us));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_local_timestamp), mp_obj_new_int(frame.local_timestamp));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_ant), mp_obj_new_int(frame.ant));
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_sig_len), mp_obj_new_int(frame.sig_len));

    // MAC address as bytes
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_mac), 
                     mp_obj_new_bytes(frame.mac, 6));

    // CSI data as array('h')
    mp_obj_array_t *csi_array = MP_OBJ_TO_PTR(mp_obj_new_bytearray_by_ref(
        frame.len * sizeof(int16_t), frame.data));
    csi_array->typecode = 'h';
    mp_obj_dict_store(dict, MP_OBJ_NEW_QSTR(MP_QSTR_data), MP_OBJ_FROM_PTR(csi_array));

    return dict;
}
STATIC MP_DEFINE_CONST_FUN_OBJ_1(wifi_csi_read_obj_obj, wifi_csi_read_obj);

// wifi.csi.dropped() -> int
STATIC mp_obj_t wifi_csi_dropped_obj(mp_obj_t self_in) {
    return mp_obj_new_int(g_csi_state.buffer.dropped);
}
STATIC MP_DEFINE_CONST_FUN_OBJ_1(wifi_csi_dropped_obj_obj, wifi_csi_dropped_obj);

// wifi.csi.available() -> int
STATIC mp_obj_t wifi_csi_available_obj(mp_obj_t self_in) {
    if (!g_csi_state.buffer.initialized) {
        return mp_obj_new_int(0);
    }
    
    uint32_t head = g_csi_state.buffer.head;
    uint32_t tail = g_csi_state.buffer.tail;
    uint32_t size = g_csi_state.buffer.size;
    
    uint32_t available = (head >= tail) ? (head - tail) : (size - tail + head);
    return mp_obj_new_int(available);
}
STATIC MP_DEFINE_CONST_FUN_OBJ_1(wifi_csi_available_obj_obj, wifi_csi_available_obj);

// Local dictionary for CSI object
STATIC const mp_rom_map_elem_t wifi_csi_locals_dict_table[] = {
    { MP_ROM_QSTR(MP_QSTR_enable), MP_ROM_PTR(&wifi_csi_enable_obj_obj) },
    { MP_ROM_QSTR(MP_QSTR_disable), MP_ROM_PTR(&wifi_csi_disable_obj_obj) },
    { MP_ROM_QSTR(MP_QSTR_config), MP_ROM_PTR(&wifi_csi_config_obj_obj) },
    { MP_ROM_QSTR(MP_QSTR_read), MP_ROM_PTR(&wifi_csi_read_obj_obj) },
    { MP_ROM_QSTR(MP_QSTR_dropped), MP_ROM_PTR(&wifi_csi_dropped_obj_obj) },
    { MP_ROM_QSTR(MP_QSTR_available), MP_ROM_PTR(&wifi_csi_available_obj_obj) },
};
STATIC MP_DEFINE_CONST_DICT(wifi_csi_locals_dict, wifi_csi_locals_dict_table);

// CSI type definition
MP_DEFINE_CONST_OBJ_TYPE(
    wifi_csi_type,
    MP_QSTR_CSI,
    MP_TYPE_FLAG_NONE,
    locals_dict, &wifi_csi_locals_dict
);

#endif // MICROPY_PY_NETWORK_WLAN_CSI
