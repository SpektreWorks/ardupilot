#include <AP_HAL/AP_HAL.h>

#if HAL_WITH_UAVCAN

#include "AP_RangeFinder_uLanding_CAN.h"
#include <AP_BoardConfig/AP_BoardConfig_CAN.h>
#include <AP_uLandingCAN/AP_uLandingCAN.h>

extern const AP_HAL::HAL& hal;

uint8_t AP_RangeFinder_uLanding_CAN::num_sensors;

/*
  constructor
 */
AP_RangeFinder_uLanding_CAN::AP_RangeFinder_uLanding_CAN(RangeFinder::RangeFinder_State &_state, AP_RangeFinder_Params &_params) :
    AP_RangeFinder_Backend(_state, _params)
{
    instance = num_sensors++;
}

//Called from frontend to update with the readings received by handler
void AP_RangeFinder_uLanding_CAN::update()
{
    AP_uLandingCAN *ap_ucan = AP_uLandingCAN::get_ulandingcan(instance);
    if (!ap_ucan) {
        set_status(RangeFinder::RangeFinder_NotConnected);
        return;
    }
    uint32_t timestamp_ms;
    uint16_t dist_cm;

    if (ap_ucan->get_distance_cm(timestamp_ms, dist_cm) && timestamp_ms != last_update_ms) {
        last_update_ms = timestamp_ms;
        WITH_SEMAPHORE(_sem);
        state.distance_cm = dist_cm;
        state.last_reading_ms = timestamp_ms;
        update_status();
    } else {
        set_status(RangeFinder::RangeFinder_NoData);
    }
}

#endif // HAL_WITH_UAVCAN


