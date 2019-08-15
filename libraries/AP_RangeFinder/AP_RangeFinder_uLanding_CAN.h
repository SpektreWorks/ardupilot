#pragma once

#include "RangeFinder_Backend.h"

#if HAL_WITH_UAVCAN

class AP_RangeFinder_uLanding_CAN : public AP_RangeFinder_Backend {
public:
    AP_RangeFinder_uLanding_CAN(RangeFinder::RangeFinder_State &_state, AP_RangeFinder_Params &_params);

    void update() override;

protected:
    virtual MAV_DISTANCE_SENSOR _get_mav_distance_sensor_type() const override {
        return MAV_DISTANCE_SENSOR_RADAR;
    }

private:
    static uint8_t num_sensors;
    uint8_t instance;
    uint32_t last_update_ms;
};
#endif //HAL_WITH_UAVCAN
