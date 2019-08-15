/*
   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
/*
 * AP_uLandingCAN.h, CAN protocol for uLanding radar
 */
 
#pragma once

#include <AP_HAL/CAN.h>
#include <AP_HAL/Semaphores.h>

#include <AP_Param/AP_Param.h>

#include <atomic>

class AP_uLandingCAN : public AP_HAL::CANProtocol {
public:
    AP_uLandingCAN();
    
    /* Do not allow copies */
    AP_uLandingCAN(const AP_uLandingCAN &other) = delete;
    AP_uLandingCAN &operator=(const AP_uLandingCAN&) = delete;

    static const struct AP_Param::GroupInfo var_info[];

    // Return AP_uLandingCAN from @driver_index or nullptr if it's not ready or doesn't exist
    static AP_uLandingCAN *get_ulandingcan(uint8_t driver_index);

    void init(uint8_t driver_index, bool enable_filters) override;

    void update();

    bool get_distance_cm(uint32_t &timestamp_ms, uint16_t &distance_cm);
    
private:
    void loop();
    void receive_frame();

    bool initialized;
    char thread_name[9];
    uint8_t driver_index;
    uavcan::ICanDriver* can_driver;
    const uavcan::CanFrame* select_frames[uavcan::MaxCanIfaces] { };

    HAL_Semaphore sem;

    static const uint8_t CAN_IFACE_INDEX = 0;

    uint32_t update_ms;
    uint16_t distance_cm;
};
