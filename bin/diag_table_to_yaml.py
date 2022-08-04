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

""" Converts a legacy ascii diag_table to a yaml diag_table.
    Run `python3 diag_table_to_yaml.py -h` for more details
    Author: Uriel Ramirez 05/27/2022
"""

import copy as cp
import argparse
from os import path
import yaml

#: parse user input
parser = argparse.ArgumentParser(prog='diag_table_to_yaml', \
                                 description="converts a legacy ascii diag_table to a yaml diag_table \
                                              Requires pyyaml (https://pyyaml.org/) \
                                              More details on the diag_table yaml format can be found in \
                                              https://github.com/NOAA-GFDL/FMS/tree/main/diag_table")
parser.add_argument('-f', type=str, help='Name of the ascii diag_table to convert' )
in_diag_table = parser.parse_args().f

class DiagTable :

    def __init__(self, diag_table_file='Diag_Table' ) :
        '''Initialize the diag_table type'''

        self.diag_table_file = diag_table_file

        self.global_section = {}
        self.global_section_keys = ['title','base_date' ]
        self.global_section_fvalues = {'title'    : str,
                                      'base_date' : [int,int,int,int,int,int]}
        self.max_global_section = len(self.global_section_keys) - 1 #: minus title

        self.file_section = []
        self.file_section_keys = ['file_name',
                                  'freq',
                                  'freq_units',
                                  'time_units',
                                  'unlimdim',
                                  'new_file_freq',
                                  'new_file_freq_units',
                                  'start_time',
                                  'file_duration',
                                  'file_duration_units',
                                  'filename_time_bounds' ]
        self.file_section_fvalues = {'file_name'          : str,
                                    'freq'                : int,
                                    'freq_units'          : str,
                                    'time_units'          : str,
                                    'unlimdim'            : str,
                                    'new_file_freq'       : int,
                                    'new_file_freq_units' : str,
                                    'start_time'          : str,
                                    'file_duration'       : int,
                                    'file_duration_units' : str,
                                    'filename_time_bounds': str }
        self.max_file_section = len(self.file_section_keys)

        self.region_section = []
        self.region_section_keys = ['grid_type',
                                    'corner1',
                                    'corner2',
                                    'corner3',
                                    'corner4',
                                    'zbounds',
                                    'file_name'
                                    'line']
        self.region_section_fvalues = {'grid_type'            : str,
                                       'corner1'              : [ float, float],
                                       'corner2'              : [ float, float],
                                       'corner3'              : [ float, float],
                                       'corner4'              : [ float, float],
                                       'zbounds'              : [ float, float],
                                       'file_name'            : str,
                                       'line'                 : str}
        self.max_file_section = len(self.file_section_keys)
        self.field_section = []
        self.field_section_keys = ['module',
                                   'var_name',
                                   'output_name',
                                   'file_name',
                                   'reduction',
                                   'spatial_ops',
                                   'kind']
        self.field_section_fvalues = {'module'       : str,
                                     'var_name'      : str,
                                     'output_name'   : str,
                                     'file_name'     : str,
                                     'reduction'     : str,
                                     'spatial_ops'   : str,
                                     'kind'          : str }
        self.max_field_section = len(self.field_section_keys)

        self.diag_table_content = []

        #: check if diag_table file exists
        if not path.exists( self.diag_table_file ) : exit( 'file '+self.diag_table_file+' does not exist' )


    def read_diag_table(self) :
        """ Open and read the diag_table"""
        with open( self.diag_table_file, 'r' ) as myfile :
            self.diag_table_content = myfile.readlines()

    def set_sub_region(self, myval, file_name) :
        """ Loop through the defined sub_regions, determine if the file already has a sub_region defined
            if it does crash. If the sub_region is not already defined add the region to the list
        """
        tmp_dict2 = {}
        found = False
        for iregion_dict in self.region_section :
           if iregion_dict['file_name'] == file_name :
              found = True
              if iregion_dict['line'] != myval :
                 print("The "+ file_name +" has multiple sub_regions defined. Be sure that all the variables \
                        in the file are in the same sub_region!")
                 print("Region1:" + myval)
                 print("Region2:" + iregion_dict['line'])
                 exit()
        if (found) : return

        tmp_dict2["line"] = myval
        tmp_dict2["file_name"] = file_name
        if "none" in myval:
           tmp_dict2[self.region_section_keys[0]] = myval
        else :
           tmp_dict2[self.region_section_keys[0]] = "latlon"
           stuff = myval.split(' ')
           k = -1
           for j in range(len(stuff)) :
               if (stuff[j] == "") : continue #Some lines have extra spaces ("1 10  9 11 -1 -1")
               k = k + 1

               if float(stuff[j]) == -1 :
                  stuff[j] = "-999"

               if k==0 :
                   corner1 = stuff[j]
                   corner2 = stuff[j]
               elif k==1 :
                   corner3 = stuff[j]
                   corner4 = stuff[j]
               elif k==2 :
                   corner1 = corner1 + ' ' + stuff[j]
                   corner2 = corner2 + ' ' + stuff[j]
               elif k==3 :
                   corner3 = corner3 + ' ' + stuff[j]
                   corner4 = corner4 + ' ' + stuff[j]
               elif k==4:
                   zbounds = stuff[j]
               elif k==5:
                   zbounds = zbounds + ' ' + stuff[j]

           tmp_dict2["corner1"] = corner1
           tmp_dict2["corner2"] = corner2
           tmp_dict2["corner3"] = corner3
           tmp_dict2["corner4"] = corner4
           tmp_dict2["zbounds"] = zbounds
        self.region_section.append( cp.deepcopy(tmp_dict2) )

    def parse_diag_table(self) :
        """ Loop through each line in the diag_table and parse it"""

        if self.diag_table_content == [] : raise Exception('ERROR:  The input diag_table is empty!')

        iline_count, global_count = 0, 0

        #: The first two lines should be the title and base_time
        while global_count < 2 :
            iline = self.diag_table_content[iline_count]
            iline_count += 1
            if iline.strip() != '' and '#' not in iline.strip()[0] : #: if not blank or comment
                #: Set the base_date
                if global_count == 1 :
                    try :
                        iline_list, tmp_list = iline.split('#')[0].split(), [] #: not comma separated integers
                        mykey    = self.global_section_keys[1]
                        self.global_section[mykey] = iline.split('#')[0].strip()
                        global_count += 1
                    except :
                        exit(" ERROR1 with line # " + str(iline_count) + '\n'
                             " CHECK:            " + str(iline) + '\n' )
                #: Set the title
                if global_count == 0 :
                    try :
                        mykey   = self.global_section_keys[0]
                        myfunct = self.global_section_fvalues[mykey]
                        myval   = myfunct( iline.strip().strip('"').strip("'") )
                        self.global_section[mykey] = myval
                        global_count += 1
                    except :
                        exit(" ERROR2 with line # " + str(iline_count) + '\n'
                             " CHECK:            " + str(iline) + '\n' )

        #: The rest of the lines are either going to be file or field section
        for iline_in in self.diag_table_content[iline_count:] :
            iline = iline_in.strip().strip(',') #get rid of any leading spaces and the comma that some file lines have in the end #classic
            iline_count += 1
            if iline.strip() != '' and '#' not in iline.strip()[0] : #: if not blank line or comment
                iline_list = iline.split('#')[0].split(',')          #:get rid of comment at the end
                try :
                    #: see if file section
                    tmp_dict = {}
                    for i in range(len(iline_list)) :
                        j = i
                        if (i == 3) : continue #do not do anything with the "file_format" column
                        if (i > 3) : j = i-1
                        mykey   = self.file_section_keys[j]
                        myfunct = self.file_section_fvalues[mykey]
                        myval   = myfunct( iline_list[i].strip().strip('"').strip("'"))
                        if (i == 9 and myval <= 0) : continue #ignore file_duration if it less than 0
                        if (i == 10 and myval == "") : continue #ignore the file_duration_units if it is an empty string
                        tmp_dict[mykey] = myval
                    self.file_section.append( cp.deepcopy(tmp_dict) )
                except :
                    #: see if field section
                    try :
                        tmp_dict = {}
                        for i in range(len(self.field_section_keys)+1) :
                            j = i
                            buf = iline_list[i]
                            if (i == 4) : continue #do not do anything with the "time_sampling" section
                            if (i > 4) : j = i-1
                            if (i == 5) : #Set the reduction to average or none instead of the other options
                                if ("true" in buf.lower() or "avg" in buf.lower() or "mean" in buf.lower() ) : buf = "average"
                                elif ("false" in buf.lower()) : buf = "none"
                            if (i == 7) : #Set the kind to either "float" or "double"
                                if   ("2" in buf) : buf = "r4"
                                elif ("1" in buf) : buf = "r8"
                                else : exit("Error: the kind needs to be 1 or 2")
                            mykey   = self.field_section_keys[j]
                            myfunct = self.field_section_fvalues[mykey]
                            myval   = myfunct( buf.strip().strip('"').strip("'") )
                            if (i != 6) : # Do not add the region to the field section
                               tmp_dict[mykey] = myval
                            else:
                               self.set_sub_region(myval, tmp_dict["file_name"])
                        self.field_section.append( cp.deepcopy(tmp_dict) )
                    except :
                        exit(" ERROR3 with line # " + str(iline_count) + '\n'
                             " CHECK:            " + str(iline) + '\n' )

    def construct_yaml(self) :
        """ Combine the global, file, field, sub_region sections into 1 """
        yaml_doc= {}
        #: title
        mykey = self.global_section_keys[0]
        yaml_doc[mykey]=self.global_section[mykey]
        #: basedate
        mykey = self.global_section_keys[1]
        yaml_doc[mykey]=self.global_section[mykey]
        #: diag_files
        yaml_doc['diag_files']=[]
        #: go through each file
        for ifile_dict in self.file_section : #: file_section = [ {}, {}, {} ]
            if 'ocean' in ifile_dict['file_name'] :
              ifile_dict['is_ocean'] = True
            ifile_dict['sub_region']=[]
            found = False
            for iregion_dict in self.region_section :
                if iregion_dict['file_name'] == ifile_dict['file_name'] :
                   tmp_dict=cp.deepcopy(iregion_dict)
                   del tmp_dict['file_name']
                   del tmp_dict['line']
                   if (tmp_dict['grid_type'] != "none"):
                       ifile_dict['sub_region'].append(tmp_dict)
                       found = True
                       continue
            if not found : del ifile_dict['sub_region']
            ifile_dict['varlist']=[]
            found = False
            for ifield_dict in self.field_section : #: field_section = [ {}, {}. {} ]
                if ifield_dict['file_name'] == ifile_dict['file_name'] :
                    tmp_dict=cp.deepcopy(ifield_dict)
                    # If the output_name and the var_name are the same, there is no need for output_name
                    if tmp_dict['output_name'] == tmp_dict['var_name'] :
                      del tmp_dict['output_name']
                    del tmp_dict['file_name']
                    ifile_dict['varlist'].append(tmp_dict)
                    found = True
                    continue
            if not found : del ifile_dict['varlist']
            yaml_doc['diag_files'].append(ifile_dict)
        myfile = open(self.diag_table_file+'.yaml', 'w')
        yaml.dump(yaml_doc, myfile, sort_keys=False)

    def read_and_parse_diag_table(self) :
        """ Read and parse the file """
        self.read_diag_table()
        self.parse_diag_table()

#: start
test_class = DiagTable( diag_table_file=in_diag_table )
test_class.read_and_parse_diag_table()
test_class.construct_yaml()
