#!/usr/bin/env python3

#: converts the global, file and field sections in diag_table to yaml format:

import copy as cp
import argparse
from os import path
import yaml

#: parse user input
parser = argparse.ArgumentParser(prog='diag_table_to_yaml', description="converts diag_table to yaml format")
parser.add_argument('-f', type=str, help='diag_table file' )
in_diag_table = parser.parse_args().f

#: diag_table related attributes and functions
class DiagTable :

    def __init__(self, diag_table_file='Diag_Table' ) :

        '''add description of this class later'''

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
                                  'dim1_begin',
                                  'dim1_end',
                                  'dim2_begin',
                                  'dim2_end',
                                  'dim3_begin',
                                  'dim3_end',
                                  'file_name'
                                  'line']
        self.region_section_fvalues = {'grid_type'            : str,
                                    'dim1_begin'              : float,
                                    'dim1_end'                : float,
                                    'dim2_begin'              : float,
                                    'dim2_end'                : float,
                                    'dim3_begin'              : float,
                                    'dim3_end'                : float,
                                    'file_name'               : str,
                                    'line'                : str}
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
        #: read
        with open( self.diag_table_file, 'r' ) as myfile :
            self.diag_table_content = myfile.readlines()

    def set_region(self, myval, file_name) :
        tmp_dict2 = {}
        found = False
        for iregion_dict in self.region_section :
           if iregion_dict['file_name'] == file_name :
              found = True
              if iregion_dict['line'] != myval :
                 print("There are multiple regions for file:" + file_name)
                 print("Region1:" + myval)
                 print("Region2:" + iregion_dict['line'])
                 exit()
        if (found) : return

        tmp_dict2["line"] = myval
        if "none" in myval:
           tmp_dict2[self.region_section_keys[0]] = myval
        else :
           tmp_dict2[self.region_section_keys[0]] = "latlon"
           stuff = myval.split(' ')
           k = -1
           for j in range(len(stuff)) :
               if (stuff[j] == "") : continue #LOL some lines have extra spaces ("1 10  9 11 -1 -1")
               k = k + 1 #The Classic way
               mykey   = self.region_section_keys[k+1]
               myfunct = self.region_section_fvalues[mykey]
               myval   = myfunct( stuff[j] )
               if myval != -1 and myval != -999 : #Do not add a key if the limit is -1 or -999
                  tmp_dict2[mykey] = myval
        tmp_dict2["file_name"] = file_name
        self.region_section.append( cp.deepcopy(tmp_dict2) )

    def parse_diag_table(self) :
        if self.diag_table_content == [] : exit('ERROR:  diag_table_content is empty')

        iline_count, global_count = 0, 0

        #: global section; should be the first two lines
        while global_count < 2 :
            iline = self.diag_table_content[iline_count]
            iline_count += 1
            if iline.strip() != '' and '#' not in iline.strip()[0] : #: if not blank or comment
                #: line 2
                if global_count == 1 :
                    try :
                        iline_list, tmp_list = iline.split('#')[0].split(), [] #: not comma separated integers
                        mykey    = self.global_section_keys[1]
                        self.global_section[mykey] = iline.split('#')[0].strip()
                        global_count += 1
                    except :
                        exit(" ERROR1 with line # " + str(iline_count) + '\n'
                             " CHECK:            " + str(iline) + '\n' )
                #: line 1
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

        #: rest are either going to be file or field section
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
                        if (i == 3) : continue #do not do anything with the "file_format" section
                        if (i > 3) : j = i-1
                        mykey   = self.file_section_keys[j]
                        myfunct = self.file_section_fvalues[mykey]
                        myval   = myfunct( iline_list[i].strip().strip('"').strip("'"))
                        if (i == 9 and myval <= 0) : continue
                        if (i == 10 and myval == "") : continue
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
                               self.set_region(myval, tmp_dict["file_name"])
                        self.field_section.append( cp.deepcopy(tmp_dict) )
                    except :
                        exit(" ERROR3 with line # " + str(iline_count) + '\n'
                             " CHECK:            " + str(iline) + '\n' )

    def construct_yaml(self) :
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
                       break
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
                    break
            if not found : del ifile_dict['varlist']
            yaml_doc['diag_files'].append(ifile_dict)
        myfile = open(self.diag_table_file+'.yaml', 'w')
        yaml.dump(yaml_doc, myfile, sort_keys=False)

    def read_and_parse_diag_table(self) :
        self.read_diag_table()
        self.parse_diag_table()

#: start
test_class = DiagTable( diag_table_file=in_diag_table )
test_class.read_and_parse_diag_table()
test_class.construct_yaml()
