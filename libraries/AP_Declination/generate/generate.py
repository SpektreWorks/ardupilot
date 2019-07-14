#!/usr/bin/env python3
'''
generate field tables from WMM
'''

import numpy as np
import datetime
from pathlib import Path
from magnetic_field_calculator import MagneticFieldCalculator
import time

if not Path("AP_Declination.h").is_file():
    raise OSError("Please run this tool from the AP_Declination directory")


def write_table(f,name, table):
    '''write one table'''
    f.write("const float AP_Declination::%s[%u][%u] = {\n" %
                (name, NUM_LAT, NUM_LON))
    for i in range(NUM_LAT):
        f.write("    {")
        for j in range(NUM_LON):
            f.write("%.5ff" % table[i][j])
            if j != NUM_LON-1:
                f.write(",")
        f.write("}")
        if i != NUM_LAT-1:
            f.write(",")
        f.write("\n")
    f.write("};\n\n")




if __name__ == '__main__':

    date = datetime.datetime.now()
   # date = datetime.date(2018,2,20)

    SAMPLING_RES = 10
    SAMPLING_MIN_LAT = -90
    SAMPLING_MAX_LAT = 90
    SAMPLING_MIN_LON = -180
    SAMPLING_MAX_LON = 180

    lats = np.arange(SAMPLING_MIN_LAT, SAMPLING_MAX_LAT+SAMPLING_RES, SAMPLING_RES)
    lons = np.arange(SAMPLING_MIN_LON, SAMPLING_MAX_LON+SAMPLING_RES, SAMPLING_RES)

    NUM_LAT = lats.size
    NUM_LON = lons.size

    intensity_table = np.empty((NUM_LAT, NUM_LON))
    inclination_table = np.empty((NUM_LAT, NUM_LON))
    declination_table = np.empty((NUM_LAT, NUM_LON))

    dtime = time.strftime('%Y-%m-%d')
    print("Fetching fields as of %s" % dtime)
    calc = MagneticFieldCalculator()

    for i,lat in enumerate(lats):
        for j,lon in enumerate(lons):
            mag = calc.calculate(latitude=lat, longitude=lon, altitude=0, date=dtime)
            intensity_table[i][j] = mag['field-value']['total-intensity']['value']/1.0e5
            inclination_table[i][j] = mag['field-value']['inclination']['value']
            declination_table[i][j] = mag['field-value']['declination']['value']
            print(lat, lon, intensity_table[i][j], inclination_table[i][j], declination_table[i][j])

    with open("tables.cpp", 'w') as f:
        f.write('''// this is an auto-generated file from the IGRF tables. Do not edit
// To re-generate run generate/generate.py

#include "AP_Declination.h"

''')

        f.write('''const float AP_Declination::SAMPLING_RES = %u;
const float AP_Declination::SAMPLING_MIN_LAT = %u;
const float AP_Declination::SAMPLING_MAX_LAT = %u;
const float AP_Declination::SAMPLING_MIN_LON = %u;
const float AP_Declination::SAMPLING_MAX_LON = %u;

''' % (SAMPLING_RES,
           SAMPLING_MIN_LAT,
           SAMPLING_MAX_LAT,
           SAMPLING_MIN_LON,
           SAMPLING_MAX_LON))


        write_table(f,'declination_table', declination_table)
        write_table(f,'inclination_table', inclination_table)
        write_table(f,'intensity_table', intensity_table)

