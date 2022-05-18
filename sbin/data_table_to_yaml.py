#!/usr/bin/env python3

import copy as cp
from os import path
import argparse


#: parse user input
parser = argparse.ArgumentParser(prog='data_table_to_yaml', description="converts data_table to yaml format")
parser.add_argument('-f', type=str, help='data_table file' )
in_data_table = parser.parse_args().f


#: write '---' at top of the yaml file
def init_yaml_file(outfile='') :
    myfile = open(outfile,'w')

#: section = [ list1, list2, list3, ... ]
#: list1   = [ {key1:val1}, {key2:val2}, ... ]
def write_yaml_sections(outfile='', section=[], header='') :
    with open(outfile, 'a+') as myfile :
        myfile.write( header + ':\n')
        for ilist in section :
            mystr = ' {:2s}' + '{:17s} : ' + '{:' + str(len(ilist[0].values())) + 's} \n'
            myfile.write( mystr.format( '-', str(*ilist[0].keys()) , str(*ilist[0].values()) ))
            for i in range(1,len(ilist)) :
                mystr = ' {:2s}' + '{:17s} : ' + '{:' + str(len(ilist[i].values())) + 's} \n'
                myfile.write( mystr.format( '', str(*ilist[i].keys()) , str(*ilist[i].values()) ))
            myfile.write('\n')


class DataType :

    def __init__(self, data_table_file='data_table') :

        self.data_table_file = data_table_file

        self.data_type  = []
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
        if not path.exists( self.data_table_file ) : exit( 'file '+self.data_table_file+' does not exist' )


    def read_data_table(self) :
        with open( self.data_table_file, 'r' ) as myfile :
            self.data_table_content = myfile.readlines()


    def parse_data_table(self) :
        iline_count = 0
        for iline in self.data_table_content :
            iline_count += 1
            if iline.strip() != '' and '#' not in iline.strip()[0] :
                iline_list = iline.split('#')[0].split(',') #: get rid of comment at the end of line
                try :
                    tmp_list = []
                    for i in range(len(iline_list)) :
                        mykey   = self.data_type_keys[i]
                        myfunct = self.data_type_values[mykey]
                        myval   = myfunct( iline_list[i].strip() )
                        if i == 4 :
                           #If LIMA format convert to the regular format #FUTURE
                           if("true"  in myval) : myval = '"bilinear"'
                           if("false" in myval) : myval = '"none"'
                        tmp_list.append( {mykey:myval} )
                    self.data_type.append( cp.deepcopy(tmp_list) )
                except :
                    exit( '\nERROR in line # ' + str(iline_count) +
                          '\nCHECK           ' + str(iline) )


    def read_and_parse_data_table(self) :
        if self.data_table_content != [] : self.data_table_content = []
        self.read_data_table()
        self.parse_data_table()


    def write_yaml(self) :
        outfile = self.data_table_file + '.yaml'
        init_yaml_file(outfile)
        if self.data_table_content != [] : write_yaml_sections( outfile, self.data_type, header='data_table' )


    def convert_data_table(self) :
        self.read_and_parse_data_table()
        self.write_yaml()


test_class = DataType(data_table_file=in_data_table)
test_class.convert_data_table()
