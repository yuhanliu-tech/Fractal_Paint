import bisect
from collections import defaultdict
import csv
import pandas as pd
import json

all_wavelengths = [412.0, 440.0, 488.0, 510.0, 532.0, 555.0, 630.0, 650.0, 676.0, 715.0]

def read_data():
    table = defaultdict(lambda: defaultdict(dict))

    with open('b.csv', newline='') as csvfile:
        reader = csv.reader(csvfile)
        for row in list(reader)[1:]:
            wavelength = float(row[1])
            scattering = float(row[2])
            jerlov_water_type = row[3]
            table[jerlov_water_type][wavelength]['sigma_s'] = scattering

    with open('a.csv', newline='') as csvfile:
        reader = csv.reader(csvfile)
        for row in list(reader)[1:]:
            wavelength = float(row[1])
            absorbtion = float(row[2])
            jerlov_water_type = row[3]
            scattering = table[jerlov_water_type][wavelength]['sigma_s']
            extinction = scattering + absorbtion
            table[jerlov_water_type][wavelength]['sigma_t'] = float(extinction)

    df_kd = pd.read_csv('kd.csv', index_col=0)

    for jerlov_water_type, val in table.items():
        for wavelength, properties in val.items():
            kd = df_kd.loc[wavelength, jerlov_water_type]
            table[jerlov_water_type][wavelength]['kd'] = kd
            
    return table

def fill_missing(table):
    all_wavelengths = [412.0, 440.0, 488.0, 510.0, 532.0, 555.0, 630.0, 650.0, 676.0, 715.0]
        
    for jerlov_water_type, val in table.items():
        water_type_wavelengths = sorted(val.keys())
        
        for wavelength in all_wavelengths:
            if wavelength not in water_type_wavelengths:
                # Lerp in between 2 closest wavelengths, or use the closest wavelength if out of bounds
                bisect_index = bisect.bisect(water_type_wavelengths, wavelength)
                if bisect_index == 0: 
                    val[wavelength] = val[water_type_wavelengths[0]]
                elif bisect_index == len(water_type_wavelengths):
                    val[wavelength] = val[water_type_wavelengths[-1]]
                else:
                    prev_wavelength = water_type_wavelengths[bisect_index - 1]
                    next_wavelength = water_type_wavelengths[bisect_index]
                    fract = (wavelength - prev_wavelength) / (next_wavelength - prev_wavelength)
                    prev_properties = val[prev_wavelength]
                    next_properties = val[next_wavelength]
                    properties = {
                        key: prev_properties[key] + fract * (next_properties[key] - prev_properties[key])
                        for key in prev_properties.keys()
                    }
                    val[wavelength] = properties


table = read_data()
fill_missing(table)
table = {
    jerlov_water_type: [val[wavelength] for wavelength in all_wavelengths]
    for jerlov_water_type, val in table.items()
}

output = {
    'jerlovWaterProps': table,
    'wavelengths': all_wavelengths
}
        
json.dump(output, open('data.json', 'w'), indent=4)