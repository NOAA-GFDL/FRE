#!/usr/bin/env python3
"""
***********************************************************************
*                   GNU Lesser General Public License
*
* This file is part of the GFDL Flexible Modeling System (FMS) YAML tools.
*
* FMS_yaml_tools is free software: you can redistribute it and/or modify it under
* the terms of the GNU Lesser General Public License as published by
* the Free Software Foundation, either version 3 of the License, or (at
* your option) any later version.
*
* FMS_yaml_tools is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
* FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
* for more details.
*
* You should have received a copy of the GNU Lesser General Public
* License along with FMS.  If not, see <http://www.gnu.org/licenses/>.
***********************************************************************
"""

""" Converts a legacy ascii data_table to a yaml data_table.
    Run `python3 data_table_to_yaml.py -h` for more details
    Author: Uriel Ramirez 05/27/2022
"""

import copy as cp
from os import path
import argparse
import yaml

#: parse user input
parser = argparse.ArgumentParser(prog='data_table_to_yaml',\
                                 description="Converts a legacy ascii data_table to a yaml data_table. \
                                              Requires pyyaml (https://pyyaml.org/) \
                                              More details on the data_table yaml format can be found in \
                                              https://github.com/NOAA-GFDL/FMS/tree/main/data_override")
parser.add_argument('-f', type=str, help='Name of the data_table file to convert' )
in_data_table = parser.parse_args().f

class DataType :
    def __init__(self, data_table_file='data_table') :
        """Initialize the DataType"""
        self.data_table_file = data_table_file

        self.data_type  = {}
        self.data_type_keys = ['gridname',
                               'fieldname_code',
                               'fieldname_file',
                               'file_name',
                               'interpol_method',
                               'factor',
                               'lon_start',
                               'lon_end',
                               'lat_start',
                               'lat_end',
                               'region_type']
        self.data_type_values = {'gridname' : str,
                                 'fieldname_code' : str,
                                 'fieldname_file' : str,
                                 'file_name' : str,
                                 'interpol_method' : str,
                                 'factor': float,
                                 'lon_start': float,
                                 'lon_end': float,
                                 'lat_start': float,
                                 'lat_end': float,
                                 'region_type': str}

        self.data_table_content = []

        #: check if data_table file exists
        if not path.exists( self.data_table_file ) : raise Exception( 'file '+self.data_table_file+' does not exist' )


    def read_data_table(self) :
        """Open and read the legacy ascii data_table file"""
        with open( self.data_table_file, 'r' ) as myfile :
            self.data_table_content = myfile.readlines()


    def parse_data_table(self) :
        """Loop through each line in the ascii data_Table file and fill in data_type class"""
        iline_count = 0
        self.data_type['data_table']=[]
        for iline in self.data_table_content :
            iline_count += 1
            if iline.strip() != '' and '#' not in iline.strip()[0] :
                iline_list = iline.split('#')[0].split(',') #: get rid of comment at the end of line
                try :
                    tmp_list = {}
                    for i in range(len(iline_list)) :
                        mykey   = self.data_type_keys[i]
                        myfunct = self.data_type_values[mykey]
                        myval   = myfunct( iline_list[i].strip().strip('"').strip("'") )
                        if i == 4 :
                           #If LIMA format convert to the regular format #FUTURE
                           if("true"  in myval) : myval = '"bilinear"'
                           if("false" in myval) : myval = '"none"'
                        tmp_list[mykey]=myval
                except :
                    raise Exception( '\nERROR in line # ' + str(iline_count) +
                          '\nCHECK           ' + str(iline) )
            # If the fieldname_file is empty (i.e no interpolation just multiplying by a constant),
            # remove fieldname_file, file_name, and interpol_method
                if (tmp_list['fieldname_file'] == "") :
                   del tmp_list['fieldname_file']
                   del tmp_list['file_name']
                   del tmp_list['interpol_method']
                self.data_type['data_table'].append(tmp_list)

    def read_and_parse_data_table(self) :
        """Open, read, and parse the legacy ascii data_table file"""
        if self.data_table_content != [] : self.data_table_content = []
        self.read_data_table()
        self.parse_data_table()

    def convert_data_table(self) :
        """Convert the legacy ascii data_table file to yaml"""
        self.read_and_parse_data_table()
        myfile = open(self.data_table_file+'.yaml', 'w')
        yaml.dump(self.data_type, myfile, sort_keys=False)

test_class = DataType(data_table_file=in_data_table)
test_class.convert_data_table()
