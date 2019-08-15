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
  driver for uLanding CAN radar altimeter
 */

#include <AP_HAL/AP_HAL.h>

#if HAL_WITH_UAVCAN

#include <AP_BoardConfig/AP_BoardConfig.h>
#include <AP_BoardConfig/AP_BoardConfig_CAN.h>
#include <AP_Common/AP_Common.h>
#include "AP_uLandingCAN.h"

extern const AP_HAL::HAL& hal;

// table of user settable CAN bus parameters, none for this sensor
const AP_Param::GroupInfo AP_uLandingCAN::var_info[] = {
    AP_GROUPEND
};


AP_uLandingCAN::AP_uLandingCAN()
{
    AP_Param::setup_object_defaults(this, var_info);
}

/*
  accessor for AP_RangeFinder driver
 */
AP_uLandingCAN *AP_uLandingCAN::get_ulandingcan(uint8_t driver_index)
{
    if (driver_index >= AP::can().get_num_drivers() ||
        AP::can().get_protocol_type(driver_index) != AP_BoardConfig_CAN::Protocol_Type_uLandingCAN) {
        return nullptr;
    }
    return static_cast<AP_uLandingCAN*>(AP::can().get_driver(driver_index));
}

void AP_uLandingCAN::init(uint8_t _driver_index, bool enable_filters)
{
    driver_index = _driver_index;

    if (initialized) {
        return;
    }

    // get CAN manager instance
    AP_HAL::CANManager* can_mgr = hal.can_mgr[driver_index];
    if (can_mgr == nullptr) {
        return;
    }

    if (!can_mgr->is_initialized()) {
        return;
    }

    // store pointer to CAN driver
    can_driver = can_mgr->get_driver();
    if (can_driver == nullptr) {
        return;
    }

    snprintf(thread_name, sizeof(thread_name), "ulcan_%u", driver_index);

    // start thread for receiving CAN frames
    if (!hal.scheduler->thread_create(FUNCTOR_BIND_MEMBER(&AP_uLandingCAN::loop, void), thread_name, 4096, AP_HAL::Scheduler::PRIORITY_CAN, 0)) {
        return;
    }

    initialized = true;

    return;
}

void AP_uLandingCAN::receive_frame()
{
    // wait for space in buffer to read
    uavcan::CanSelectMasks inout_mask;
    uavcan::MonotonicTime timeout = uavcan::MonotonicTime::fromUSec(AP_HAL::micros64() + 50000);
    uavcan::CanFrame recv_frame {};

    inout_mask.read = 1 << CAN_IFACE_INDEX;
    inout_mask.write = 0;
    select_frames[CAN_IFACE_INDEX] = &recv_frame;
    can_driver->select(inout_mask, select_frames, timeout);

    // return false if no data is available to read
    if (!inout_mask.read) {
        return;
    }

    uavcan::MonotonicTime time;
    uavcan::UtcTime utc_time;
    uavcan::CanIOFlags flags {};

    // read frame and return success
    if (can_driver->getIface(CAN_IFACE_INDEX)->receive(recv_frame, time, utc_time, flags) != 1) {
        return;
    }

    // format is 16 bit range in cm, followed by 16 bit SNR
    WITH_SEMAPHORE(sem);
    distance_cm = (recv_frame.data[0]<<8) | recv_frame.data[1];
    update_ms = AP_HAL::millis();
}


void AP_uLandingCAN::loop()
{
    while (true) {
        if (initialized) {
            receive_frame();
        }
        hal.scheduler->delay_microseconds(2000);
    }
}

void AP_uLandingCAN::update()
{
    // nothing to do
}

/*
  get distance in cm
 */
bool AP_uLandingCAN::get_distance_cm(uint32_t &timestamp_ms, uint16_t &dist_cm)
{
    WITH_SEMAPHORE(sem);
    if (update_ms == 0) {
        return false;
    }
    timestamp_ms = update_ms;
    dist_cm = distance_cm;
    return true;
}

#endif // HAL_WITH_UAVCAN
