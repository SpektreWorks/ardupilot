#pragma once

#include <AP_Common/AP_Common.h>
#include <AP_Param/AP_Param.h>
#include <AP_Math/AP_Math.h>
#include "AP_BattMonitor_SMBus.h"
#include <AP_HAL/I2CDevice.h>

#define SUI_MAXCELLS 6

// Base SUI class
class AP_BattMonitor_SMBus_SUI : public AP_BattMonitor_SMBus
{
public:

    // Constructor
    AP_BattMonitor_SMBus_SUI(AP_BattMonitor &mon,
                             AP_BattMonitor::BattMonitor_State &mon_state,
                             AP_BattMonitor_Params &params,
                             AP_HAL::OwnPtr<AP_HAL::I2CDevice> dev,
                             uint8_t cell_count
                            );

    void init(void) override;

private:
    float currents[SUI_MAXCELLS];
    float consumed_mahs[SUI_MAXCELLS];
    float temperatures[SUI_MAXCELLS];

    void timer(void) override;
    void read_cell_voltages();
    bool read_temp();
    bool read_remaining_capacity();

    // read_block - returns number of characters read if successful, zero if unsuccessful
    bool read_block(uint8_t reg, uint8_t* data, uint8_t len) const;
    bool read_block_bare(uint8_t reg, uint8_t* data, uint8_t len) const;

    // average over one of currents, consumed_mahs, temperatures
    float avg(const float *p) const;

    uint8_t button_press_count;

    const uint8_t cell_count;
    int32_t capacity;
    bool phase_voltages;
    uint32_t last_volt_read_us;
};
