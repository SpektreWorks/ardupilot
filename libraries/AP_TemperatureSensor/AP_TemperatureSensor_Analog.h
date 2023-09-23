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

#pragma once
#include "AP_TemperatureSensor_Backend.h"

#if AP_TEMPERATURE_SENSOR_ANALOG

#include <AP_Param/AP_Param.h>

class AP_TemperatureSensor_Analog : public AP_TemperatureSensor_Backend {
public:
    AP_TemperatureSensor_Analog(AP_TemperatureSensor &front, AP_TemperatureSensor::TemperatureSensor_State &state, AP_TemperatureSensor_Params &params);

    void init(void) override;

    void update(void) override;

    static const struct AP_Param::GroupInfo var_info[];

private:

    AP_HAL::AnalogSource *_analog_source;

    // Pin used to measure voltage
    AP_Int8  _pin; 

    // Polynomial coefficients to calculate temperature from voltage
    AP_Float _a0;
    AP_Float _a1;
    AP_Float _a2;
    AP_Float _a3;
    AP_Float _a4;

};

#endif // AP_TEMPERATURE_SENSOR_ANALOG
