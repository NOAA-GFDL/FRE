#!/usr/bin/python
"""FRE XML Conversion Tool

-------------------
Why use this tool?|
-----------------------------------------------------------------------
The purpose of this Python script is to facilitate the transition of  |
FRE XML documents into the latest version of Bronx. Two events        |
preceded the need for this tool.                                      |
                                                                      |
1. On March 12, 2019, Gaea's F1 file system was officially rendered   |
obsolete, designated as read-only, and scheduled for removal in       |
April, 2019. It was replaced by the F2 file system.                   |
                                                                      |
2. It was decided that the MOAB batch scheduler would be discontinued |
and be replaced by the Slurm scheduler. That transition is expected to|
be completed by May, 2019.                                            |
                                                                      |
Many components of FRE had explicitly referenced F1 file locations or |
the MOAB scheduler, prompting the decision to push a new FRE upgrade  |
that instead referenced F2 and Slurm. In doing this, the decision was |
also made to end support for all FRE versions that referenced F1 and  |
(soon) MOAB. Thus, as of March 12, 2019, Bronx-10, Bronx-11,          |
and Bronx-12 are no longer supported. This converter script was       |
created to ease the pain of converting XML's to a version that        |
supports F2 and Slurm, particularly harder conversions such as from   |
Bronx-10.                                                             |
-----------------------------------------------------------------------

-------------------------------
Summary of how this tool works|
-----------------------------------------------------------------------
The core functionality of this script is parsing the original input   |
XML, modifying its elements, and writing out the newly converted file.|
Transitioning from Bronx-12 or Bronx-13 requires very few XML tag     |
manipulations and is done via simple string substitution. On the other|
hand, Bronx-10 and Bronx-11 XML's require more extensive work. Thus,  |
the built-in Python module, ElementTree, is used to carry out major   |
XML tag changes, additions, or subtractions. ElementTree, however,    |
comes with several drawbacks, namely:                                 |
                                                                      |
    1) ElementTree doesn't preserve comments from the input XML       |
    2) FRE XML's may contain non-conforming characters within <csh>   |
       blocks, which are preserved in special CDATA tags and tend to  |
       break ElementTree.                                             |
    3) XML declarations are not consistently preserved.               |
    4) XML namespaces are not easily preserved                        |
    5) The order of tag attributes are not preserved.                 |
    6) Many other anomalies occur when trying to correct 1-5,         |
       particularly during the preservation of comment and CDATA tags.|
                                                                      |
To overcome the drawbacks, this script implements a 4-step approach   |
towards writing out a converted XML.                                  |
                                                                      |
    1) Pre-parse the original XML into a slightly customized string   |
       that ElementTree can understand, without running into errors,  |
       i.e. an ElementTree object.                                    |
    2) Modify the existing XML tags and attributes and adding or      |
       removing tags where necessary.                                 |
    3) Post-parse the modified ElementTree object back into an XML    |
       conforming string.                                             |
    4. Write out the modified XML string into a new file.             |
                                                                      |
Non-conforming input XML's will cause the script to throw an error    |
and write out the pre-parsed XML to a new file, which may be used     |
for identifying the cause of the non-conformance.                     |
-----------------------------------------------------------------------

---------------------
How to use this tool|
-----------------------------------------------------------------------
To use this tool, you must have a version of Python greater than 2.7. |
Python 3 is also acceptable. This script is run on the command line   |
and invokes a minimum of 1 argument, with the option of several       |
others.                                                               |
                                                                      |
ARGUMENTS                                                             |
_________                                                             |
                                                                      |
-x --input_xml (required)                                             |
-o --output_xml (optional)                                            |
-s --setup (optional)                                                 |
-v --verbosity (optional)                                             |
-q --quiet (optional)                                                 |
                                                                      |
USAGE                                                                 |
_____                                                                 |
                                                                      |
>$ ./freconvert.py -x /path/to/foo.xml                                |
Output: /path/to/foo_bronx-14.xml                                     |
                                                                      |
>$ ./freconvert.py -x /path/to/foo.xml -o /path/to/converted/bar.xml  |
Output: /path/to/converted/bar.xml                                    |
-----------------------------------------------------------------------

--------
Contact|
-----------------------------------------------------------------------
For inquiries, please submit a help desk ticket to FRE(FMS Workflows).|
Email: Kristopher.Rand@noaa.gov                                       |
Phone: (609) 452-6589                                                 |
Room 134                                                              |
-----------------------------------------------------------------------
"""

import os
import sys
import re
import time
import argparse
import xml.etree.ElementTree as ET

#py_vers = sys.version
## --------------- Parse the XML as a Text file first ------------- ###

# Perform all XML string replacements first, including F2 transitions #
newest_version = 'bronx-14'
char_to_replace = "<"
replacement_char = '&lt;'

configs_to_edit = ['atmos_npes', 'atmos_nthreads', 'ocean_npes',
                   'ocean_nthreads', 'layout', 'io_layout',
                   'ocean_mask_table', 'ice_mask_table', 'land_mask_table',
                   'atm_mask_table']
nmls_to_edit = ["coupler_nml", "fv_core_nml", "ice_model_nml", "land_model_nml",
                "ocean_model_nml"]


def convert_xml_text(xml_string, prev_version='bronx-12'):

    # Replace all old versions of bronx with the newest version
    xml_string = change_fre_version(xml_string, prev_version)
    # Change all F1 paths to the corresponding F2 destination
    xml_string = points_to_f2(xml_string)
    # Change any 'cubicToLatLon' attributes to 'xyInterp' in the post-processing
    xml_string = modify_pp_components(xml_string)
    # Replace any "DO_DATABASE" and "DO_ANALYSIS" property elements with "MDBIswitch" and "ANALYSIS_SWITCH"
    xml_string = xml_string.replace('DO_ANALYSIS', 'ANALYSIS_SWITCH')
    xml_string = xml_string.replace('DO_DATABASE', 'DB_SWITCH')
    # Remove database_ingestor.csh script, if it exists
    xml_string = xml_string.replace(' script="$FRE_CURATOR_HOME/share/bin/database_ingestor.csh"', '')

    return xml_string


def replace_chars(string, to_replace, replacement):

    return re.sub(to_replace, replacement, string)


def rreplace(string, old, new, occurrence=1):
    
    str_list = string.rsplit(old, occurrence)
    return new.join(str_list)


def modify_pp_components(xml_string):

    xml_string = xml_string.replace('cubicToLatLon', 'xyInterp')
    return xml_string


def points_to_f2(xml_string):

    soft_filesystem_pointers = {'$CDATA': '$PDATA/gfdl', '${CDATA}': '$PDATA/gfdl', 
                                '$CTMP': '$SCRATCH', '${CTMP}': '$SCRATCH', 
                                '$CPERM': '$DEV', '${CPERM}': '$DEV'}

    hard_filesystem_pointers = {'/lustre/f1/$USER': '/lustre/f2/scratch/$USER',
                                '/lustre/f1/unswept': '/lustre/f2/dev',
                                '/lustre/f1/pdata': '/lustre/f2/pdata/gfdl'}

    for f1_soft_pointer, f2_soft_pointer in soft_filesystem_pointers.items(): 
        xml_string = xml_string.replace(f1_soft_pointer, f2_soft_pointer)

    for f1_hard_pointer, f2_hard_pointer in hard_filesystem_pointers.items():
        xml_string = xml_string.replace(f1_hard_pointer, f2_hard_pointer)

    xml_string = xml_string.replace('lustre/f1', 'lustre/f2/dev')

    return xml_string


def change_fre_version(xml_string, version='bronx-12'):

    return xml_string.replace(version, newest_version)


def write_parsable_xml(xml_string):
   
    xml_string = xml_string.replace('<root>', '<xml_root>')
    xml_string = xml_string.replace('</root>', '</xml_root>')
 
    xml_declaration = '<?xml version="1.0"?>'
    xml_string = xml_declaration + "\n" + '<root>' + "\n" + xml_string
    
    if xml_string.count(xml_declaration) > 1:
        xml_string = rreplace(xml_string, xml_declaration, '')
        
    xml_string = xml_string.replace('&', '&amp;')
    
    xml_string = xml_string.replace('<!--', '<xml_comment>')
    xml_string = xml_string.replace('-->', '</xml_comment>')
    xml_string = xml_string.replace('<![CDATA[', '<cdata>')
    xml_string = xml_string.replace(']]>', '</cdata>')
    xml_string = xml_string.replace('<!DOCTYPE', '<doctype>')
    xml_string = xml_string.replace(']>', '</doctype>')

    comment_regex = r'<xml_comment>(.*?)</xml_comment>'
    cdata_regex = r'<cdata>(.*?)</cdata>'
    entity_regex = r'<!ENTITY.*?>'
   
    #Fix CDATA
    xml_string = fix_special_strings(cdata_regex, xml_string, '<', '&lt;')

    #Fix Comments
    xml_string = fix_special_strings(comment_regex, xml_string, '<', '&lt;')

    #Fix Entity Doctypes (Closing tags)
    xml_string = fix_special_strings(entity_regex, xml_string, '>', '</entity>')
    
    #Fix Entity Doctypes (Opening tags)
    xml_string = xml_string.replace('<!ENTITY', '<entity>')

    #Add new-line character at end of XML to separate the final 'root' tag
    xml_string = xml_string + "\n</root>"
    return xml_string
    
    
def fix_special_strings(regex_str, xml_string, to_replace, replacement):

    regex_matches = re.findall(regex_str, xml_string, re.DOTALL)

    for match in regex_matches:        
        xml_string = re.sub(re.escape(match), replace_chars(match, to_replace, replacement), xml_string)

    return xml_string


## ----------------------------- END PRE-XML PARSER ----------------------------##


## ----------------------------- BEGIN XML PARSING  ----------------------------##


# Modify (or add) 'FRE_VERSION' property and retrieve old version 

def do_properties(etree_root):

    old_ver = "bronx-10" # Default value (i.e. if no FRE_VERSION property exists)
    fre_prop_exists = False
    mdbi_switch = False

    #Retrieve the current XML bronx version through the FRE_VERSION property tag
    for prop in etree_root.iter('property'):
         
        if prop.get("name").upper() == "FRE_VERSION":

            if 'fre/' in prop.get("value").lower():
                prop.set("value", prop.get("value").lower().replace('fre/', ''))

            old_ver = prop.get("value")
            fre_prop_exists = True
        
        # Check if the MDBI switch property exists. If not, set it to "off" by default.
        if prop.get("name") == "MDBIswitch" or prop.get("name").upper() == "DB_SWITCH":
            mdbi_switch = True

        else:
            pass

    if not mdbi_switch:
        db_property = ET.Element('property', attrib={'name': 'MDBIswitch',
                                                     'value': 'off'})
        db_property.tail = '\n  '
        parent = etree_root.find('experimentSuite')
        #setup_include XML's won't have an 'experimentSuite' root
        if not parent:
            parent = etree_root.find('setup')

        parent.insert(0, db_property)
 
    #If no FRE_VERSION property tag exists (rare), add one as the first property tag
    if not fre_prop_exists:
        fre_version_property = ET.Element('property', attrib={'name': 'FRE_VERSION',
                                                              'value': old_ver})
        fre_version_property.tail = '\n  '
        parent = etree_root.find('experimentSuite')
        if not parent:
            parent = etree_root.find('setup')

        parent.insert(0, fre_version_property)

    return old_ver


#Add platform-specific <freVersion> tags, if necessary
def add_fre_version_tag(etree_root):

    #Check platform tags for <freVersion> tag
    for platform in etree_root.iter('platform'):

        #Skip over xi:include tags. We DO NOT put a <freVersion> tag here!
        #The element tag name for xi:include is '{http://www.w3.org/2001/XInclude}include'
        #Insert <freVersion> tag at the VERY BEGINNING of the <platform> tag
        xi_include = ET.iselement(platform.find('{http://www.w3.org/2001/XInclude}include'))
        if xi_include:
            continue
        else:
            if platform.find('freVersion') is None:
                freVersion_elem = ET.Element('freVersion')
                freVersion_elem.text = '$(FRE_VERSION)'
                freVersion_elem.tail = '\n      '
                platform.insert(0, freVersion_elem)
                

#Add attribute 'doF90Cpp="yes"' to <compile> tag for land component in build experiment
#Note: will only work for 1 land build component. Manual modification is needed for more than 1.

def do_land_f90(etree_root):

    for experiment in etree_root.iter('experiment'):

        for component_elem in experiment.iter('component'):
            
            if component_elem.get('name') == 'land':
                compile_elem = component_elem.find('compile')

                #Terminate inner loop if no compile element exists for land
                if compile_elem is None:
                    break

                elif not 'doF90Cpp' in compile_elem.keys():
                    csh_land_elem = compile_elem.find('csh')

                    if csh_land_elem is not None:
                        compile_elem.set('doF90Cpp', 'yes')
                        cdata_elem = csh_land_elem.find('cdata')
                        csh_land_elem.remove(cdata_elem)
                        compile_elem.remove(csh_land_elem)
                        return

                    #Shouldn't get here very often, but if no <csh> exists, exit
                    else:
                        return

                #Exit if 'doF90Cpp' already exists
                else:
                    return

            #If not on land component, check next component
            else:
                continue
    

#Delete Default Platforms -- if they exist
def delete_default_platforms(etree_root):

    try:
        setup_element = etree_root.find('experimentSuite').find('setup')
    except AttributeError as e:
        setup_element = etree_root.find('setup')

    try:
        platform_list = setup_element.findall('platform')
    except AttributeError as e:

        if setup_element is None:
            print("Setup tag doesn't exist. Skipping...")
            return
        else:
            print("No platforms listed under setup. Skipping...")
            return

    for i in range(len(platform_list)):
        platform_name = platform_list[i].get('name')

        if '.default' in platform_name:
            print("Deleting platform: %s" % platform_name)
            setup_element.remove(platform_list[i])


def add_compiler_tag(etree_root, compiler_type='intel', compiler_version='16.0.3.210'):

    try:
        platform_list = etree_root.find('experimentSuite').find('setup').findall('platform')
    except AttributeError as e:
        platform_list = etree_root.find('setup').findall('platform') 

    for platform in platform_list:
        
        if platform.find('compiler') is None:
            xi_include = ET.iselement(platform.find('{http://www.w3.org/2001/XInclude}include'))

            if xi_include:
                continue
            else:
                print("Writing compiler tag for platform %s" % platform.get("name"))
                compiler_tag = ET.SubElement(platform, 'compiler', attrib={'type': compiler_type, \
                                                                           'version': compiler_version})
                compiler_tag.tail = "\n    "
        else:
            continue
        

# Insert <resources> tags for 'production' and 'regression' elements

###     First, check for the existence of resources tags in the XML.
###     If none exist

###           Find the values of the atm, ocn, lnd, and ice ranks using the namelists located under each
###           individual experiment. Sometimes, namelists are inherited from other experiments.
###           If certain namelists are not found, then we can reasonably conclude that the resource namelist variables
###           have been inherited and only need to be rereferenced from their original source when setting the
###           resource tags for that particular experiment.

###           Rename the namelist variable values to the new 'resource variable' name. Example: layout     = 'atm_layout'

###           Delete the 'npes' and 'runTime' attributes from the 'production' tag as well as the 'runTime' attribute
###           from the 'segment' tag. Inside resource tag, create new attributes 'jobWallclock' and 'segRuntime' and
###           and use the old 'runTime' values for the new 'jobWallclock' and 'segRuntime' attribute respectively.

###           If multiple production tests/regression tests exist, create new <freInclude> tags and reference them in the
###           <runtime> tags for each experiment using <xi:include>. Regression tags are referenced in     their own
###           <regression> tags apart from <production>.

###     If they do exist, then pass.
###

#4.1 - Change variable names in namelist string and produce new namelist string ###


def nml_to_dict(nml):

    str_list = get_str_list(nml)
    nml_dict = {}

    for substr in str_list:            
        key = substr[:substr.find('=')]
        value = substr[substr.find('=')+1:]
        nml_dict[key] = value

    return nml_dict


def get_str_list(nml):

    str_list = nml.text.splitlines()
    return str_list


def modify_namelist(nml, nml_name):

    str_list = get_str_list(nml)
    new_nml_str = get_new_nml_str(nml_name, str_list)
    nml.text = new_nml_str


#Helper function for get_new_nml_str
def nml_text_replace(str_to_check, namelist_dict, namelist_substr, old_nml_str_list,
                     loop_index):

    for old_str, new_str in namelist_dict.items():

        if str_to_check == old_str:
            old_nml_str_list[loop_index] = re.sub('(?<=\=).*', new_str, namelist_substr)
            break

    return old_nml_str_list[loop_index]


def get_new_nml_str(nml_name, old_nml_str_list):

    #configs_to_edit = ['atmos_npes', 'atmos_nthreads', 'ocean_npes',
                       #'ocean_nthreads', 'layout', 'io_layout',
                       #'ocean_mask_table', 'ice_mask_table', 'land_mask_table',
                       #'atm_mask_table']

    coupler_dict = {'atmos_npes': '$atm_ranks', 'atmos_nthreads': '$atm_threads',
                    'atmos_mask_table': '$atm_mask_table', 'ocean_npes': '$ocn_ranks',
                    'ocean_nthreads': '$ocn_threads', 'ocean_mask_table': '$ocn_mask_table'}
    fv_core_dict = {'layout': '$atm_layout', 'io_layout': '$atm_io_layout'}
    ice_model_dict = {'layout': '$ice_layout', 'io_layout': '$ice_io_layout', 
                      'ice_mask_table': '$ice_mask_table'}
    land_model_dict = {'layout': '$lnd_layout', 'io_layout': '$lnd_io_layout', 
                       'land_mask_table': '$lnd_mask_table'}
    ocean_model_dict = {'layout': '$ocn_layout', 'io_layout': '$ocn_io_layout', 
                        'ocean_mask_table': '$ocn_mask_table'}

    for index, substr in enumerate(old_nml_str_list):

        #Checking only the string to the LEFT of the equal sign
        str_to_check = re.search('\w+|^\s*$', substr).group()

        #We need to set some default value in case there is no record in namelist
        #Reason: Validation purposes
        if str_to_check not in configs_to_edit:
            continue

        if nml_name == 'coupler_nml':
            old_nml_str_list[index] = nml_text_replace(str_to_check,
                                                       coupler_dict, substr, 
                                                       old_nml_str_list, index)
        elif nml_name == 'fv_core_nml':
            old_nml_str_list[index] = nml_text_replace(str_to_check,
                                                       fv_core_dict, substr, 
                                                       old_nml_str_list, index)
        elif nml_name == 'ice_model_nml':
            old_nml_str_list[index] = nml_text_replace(str_to_check,
                                                       ice_model_dict, substr, 
                                                       old_nml_str_list, index)
        elif nml_name == 'land_model_nml':
            old_nml_str_list[index] = nml_text_replace(str_to_check,
                                                       land_model_dict, substr, 
                                                       old_nml_str_list, index)
        elif nml_name == 'ocean_model_nml':
            old_nml_str_list[index] = nml_text_replace(str_to_check,
                                                       ocean_model_dict, substr, 
                                                       old_nml_str_list, index)
        else:
            pass
 
    final_str = '\n'.join(old_nml_str_list)
    return final_str


#4.2 - EXTRACT VALUES FROM NAMELISTS###

class Namelist(object):

    def __init__(self):

        self.nml_vars = {}


    def set_var(self, nml_dict, nml_field, set_layout=False, set_io_layout=False, layout_group="", io_layout_group=""):

        try:
            value = nml_dict[nml_field]

        except KeyError as e:
            return 

        #Next 3 'if' statements quality check the value (namelist comments and extra commas)
        if '!' in value:
            exc_idx = value.index('!')
            value = value[:exc_idx]

        if value.count(',') > 1:
            value = rreplace(value, ',', '', occurrence=value.count - 1)

        if value[-1] == ',':
            value = rreplace(value, ',', '')
 
        #Insert namelist value into the Namelist class dictionary
        if set_layout:
            self.nml_vars[layout_group + "_" + nml_field] = value

        elif set_io_layout:
            self.nml_vars[io_layout_group + "_" + nml_field] = value

        else:
            self.nml_vars[nml_field] = value


    def print_vars(self):

        for key, value in self.nml_vars.items():

            print("%s = %s" % (key, value))


    def get_var(self, var):
        
        #There will be instances where attributes won't exist, so test a 
        #dummy variable in a Try-Except to determine which fields exist/don't exist.
        try:
            foo = self.nml_vars[var]
    
        #Sometimes, there will be namelist keys that will not be displayed in namelist, but we need
        #it in the resource tags. Set default values to be returned.
        except KeyError as e:

            if var == 'atmos_nthreads':
                self.nml_vars[var] = '1'
                return self.nml_vars[var]
            elif var == 'atmos_npes':
                self.nml_vars[var] = '1'
                return self.nml_vars[var]
            elif var == 'atmos_layout':
                self.nml_vars[var] = '1,1'
                return self.nml_vars[var]
            elif var == 'ocean_nthreads':
                self.nml_vars[var] = '1'
                return self.nml_vars[var]
            elif var == 'ocean_npes':
                self.nml_vars[var] = '1'
                return self.nml_vars[var]
            elif var == 'ocean_layout':
                self.nml_vars[var] = '1,1'
                return self.nml_vars[var]
            else:
                self.nml_vars[var] = ''
                return self.nml_vars[var]
        
        #There will be times when ranks (or other resource params) are set to 0. Set to 1 instead.
        if self.nml_vars[var] == '0':
            self.nml_vars[var] = '1'

        return self.nml_vars[var]


### End Main 4.1 ###

### Begin Main 4.2 ###

def strip_dict_whitespace(nml_dict):

    new_dict = {}
    for key, value in nml_dict.items():
    
        new_key = key.replace(' ', '')
        new_value = value.replace(' ', '')
        new_dict[new_key] = new_value

    return new_dict


def do_resources_main(etree_root):

    #nmls_to_edit = ["coupler_nml", "fv_core_nml", "ice_model_nml", "land_model_nml", "ocean_model_nml"]

    for exp in etree_root.iter('experiment'):
        subelements = [elem.tag for elem in exp.iter() if elem is not exp]
        print("Inserting resources tags for experiment " + str(exp.get('name')))

        if not 'compile' in subelements: 
            nml_container = Namelist() #1 namelist object per experiment. It will hold all necessary namelist values per key.

            for nml in exp.iter('namelist'):
                nml_name = nml.get("name")

                if nml_name in nmls_to_edit:
                    nml_container.name = nml_name
                    nml_dict = nml_to_dict(nml)
                    nml_dict = strip_dict_whitespace(nml_dict)

                    if nml_name == 'coupler_nml':
                        nml_container.set_var(nml_dict, "atmos_npes")
                        nml_container.set_var(nml_dict, "atmos_nthreads")
                        nml_container.set_var(nml_dict, "ocean_npes")
                        nml_container.set_var(nml_dict, "ocean_nthreads")
                        nml_container.set_var(nml_dict, "atmos_mask_table")

                    elif nml_name == 'fv_core_nml':
                        nml_container.set_var(nml_dict, "layout", set_layout=True, layout_group="atm")
                        nml_container.set_var(nml_dict, "io_layout", set_io_layout=True, io_layout_group="atm")

                    elif nml_name == 'ice_model_nml':
                        nml_container.set_var(nml_dict, "layout", set_layout=True, layout_group="ice")
                        nml_container.set_var(nml_dict, "io_layout", set_io_layout=True, io_layout_group="ice")
                        nml_container.set_var(nml_dict, "ice_mask_table")

                    elif nml_name == 'land_model_nml':
                        nml_container.set_var(nml_dict, "layout", set_layout=True, layout_group="lnd")
                        nml_container.set_var(nml_dict, "io_layout", set_io_layout=True, io_layout_group="lnd")
                        nml_container.set_var(nml_dict, "land_mask_table")

                    elif nml_name == 'ocean_model_nml':
                        nml_container.set_var(nml_dict, "layout", set_layout=True, layout_group="ocn")
                        nml_container.set_var(nml_dict, "io_layout", set_io_layout=True, io_layout_group="ocn")
                        nml_container.set_var(nml_dict, "ocean_mask_table")

                    else:
                        pass

                #Empty Namelist elements will contain the value "None" for the text. Make sure to catch this.
                try:
                    modify_namelist(nml, nml_name)
                except AttributeError as e:
                    pass

            
            # Start building the Resource Tags after Modifying the Namelists #

            runtime_element = exp.find('runtime')       # Set to None if it doesn't exist
            prod_element = None                         # Initialize production element as None
            reg_element_list = []                       # Initialize regression element as None
            runtime_hours = '10:00:00'                  # Default setting
            segment_hours = '10:00:00'                  # Default setting

            atm_attribs = {'ranks': nml_container.get_var('atmos_npes'),
                           'threads': nml_container.get_var('atmos_nthreads'),
                           'layout': nml_container.get_var('atm_layout'),
                           'io_layout': nml_container.get_var('atm_io_layout'),
                           'mask_table': nml_container.get_var('atm_mask_table')}

            ocn_attribs = {'ranks': nml_container.get_var('ocean_npes'),
                           'threads': nml_container.get_var('ocean_nthreads'),
                           'layout': nml_container.get_var('ocn_layout'),
                           'io_layout': nml_container.get_var('ocn_io_layout'),
                           'mask_table': nml_container.get_var('ocn_mask_table')}

            lnd_attribs = {'ranks': nml_container.get_var('land_npes'),
                           'threads': nml_container.get_var('land_nthreads'),
                           'layout': nml_container.get_var('lnd_layout'),
                           'io_layout': nml_container.get_var('lnd_io_layout'),
                           'mask_table': nml_container.get_var('lnd_mask_table')}

            ice_attribs = {'ranks': nml_container.get_var('ice_npes'),
                           'threads': nml_container.get_var('ice_nthreads'),
                           'layout': nml_container.get_var('ice_layout'),
                           'io_layout': nml_container.get_var('ice_io_layout'),
                           'mask_table': nml_container.get_var('ice_mask_table')}

            attrib_list = [atm_attribs, ocn_attribs, lnd_attribs, ice_attribs]
            for attrib_dict in attrib_list:
           
                for key, value in attrib_dict.items():

                    if value == '' or value == None:
                        del attrib_dict[key]
            
            #print(atm_attribs)
            #print(ocn_attribs)
            #print(lnd_attribs)
            #print(ice_attribs)
            # Create a copies of the unedited dictionaries for regression tags #
            # We will create shallow copies, because we don't have nested objects #
            #atm_attr_copy = copy.copy(atm_attribs)
            #ocn_attr_copy = copy.copy(ocn_attribs)
            #lnd_attr_copy = copy.copy(lnd_attribs)
            #ice_attr_copy = copy.copy(ice_attribs)

            if runtime_element is not None:
                prod_element = runtime_element.find('production') # Set to None if it doesn't exist
                reg_element_list = runtime_element.findall('regression') # Will never be 'None'

            # ------------- PRODUCTION RUNS --------------- #

                try:
                    prod_element.attrib.pop('npes')
                except (AttributeError, KeyError) as e:
                    pass
        
                try:
                    runtime_hours = prod_element.attrib.pop('runTime')
                except (AttributeError, KeyError) as e:
                    pass
        
                try:
                    segment_hours = prod_element.find('segment').attrib.pop('runTime')
                except (AttributeError, KeyError) as e:
                    pass
        
                if prod_element is not None:
                    segment_element = prod_element.find('segment')
                    
                    if segment_element is not None:
                        segment_element.tail = "\n            "
 
                    resource_prod_element = ET.SubElement(prod_element, 'resources',
                                                          attrib={'site': 'ncrc3',
                                                                  'jobWallclock': runtime_hours,
                                                                  'segRuntime': segment_hours})
                    resource_prod_element.text = "\n              "
                    resource_prod_element.tail = "\n          "

                    # Make a child element only if the dictionary has attributes
                    atm_prod = ET.SubElement(resource_prod_element, 'atm', attrib=atm_attribs) if len(atm_attribs) > 0 else None
                    atm_prod.tail = "\n              "
                    ocn_prod = ET.SubElement(resource_prod_element, 'ocn', attrib=ocn_attribs) if len(ocn_attribs) > 0 else None
                    ocn_prod.tail = "\n              "
                    lnd_prod = ET.SubElement(resource_prod_element, 'lnd', attrib=lnd_attribs) if len(lnd_attribs) > 0 else None

                    if lnd_prod is not None:
                        lnd_prod.tail = "\n              "

                    ice_prod = ET.SubElement(resource_prod_element, 'ice', attrib=ice_attribs) if len(ice_attribs) > 0 else None

                    if ice_prod is not None:
                        ice_prod.tail = "\n            "

                # ----------------- REGRESSION RUNS -------------------- #

                for reg_element in reg_element_list:
                    run_element_list = reg_element.findall('run')
                    
                    for run_element in run_element_list:

                        try:
                            run_element.attrib.pop('npes')
                        except (AttributeError, KeyError) as e:
                            pass

                        try:
                            runtime_hours = run_element.attrib.pop('runTimePerJob')
                        except (AttributeError, KeyError) as e:
                            pass

                        if run_element is not None:
                            run_element.text = "\n              "
                            resource_reg_element = ET.SubElement(run_element, 'resources',
                                                                 attrib={'site': 'ncrc3',
                                                                         'jobWallclock': runtime_hours,})
                            resource_reg_element.text = "\n                "
                            resource_reg_element.tail = "\n            "

                            if not 'overrideParams' in run_element.attrib.keys():

                                # Make a child element only if the dictionary has attributes
                                atm_reg = ET.SubElement(resource_reg_element, 'atm', attrib=atm_attribs) if len(atm_attribs) > 0 else None
                                atm_reg.tail = "\n                    "
                                ocn_reg = ET.SubElement(resource_reg_element, 'ocn', attrib=ocn_attribs) if len(ocn_attribs) > 0 else None
                                ocn_reg.tail = "\n                    "
                                lnd_reg = ET.SubElement(resource_reg_element, 'lnd', attrib=lnd_attribs) if len(lnd_attribs) > 0 else None
                                if lnd_reg is not None:
                                    lnd_reg.tail = "\n                    "

                                ice_reg = ET.SubElement(resource_reg_element, 'ice', attrib=ice_attribs) if len(ice_attribs) > 0 else None

                                if ice_reg is not None:
                                    ice_reg.tail = "\n                 "
                            else:
                                override_container = Namelist()
                                override_str = run_element.get('overrideParams')
                                parse_overrides(override_str, override_container)
                                modified_override_str = get_modified_overrides(override_str)

                                if not modified_override_str:
                                    run_element.attrib.pop('overrideParams')
                                else:
                                    run_element.set('overrideParams', modified_override_str)

                                # OVERRIDE ATTRIBUTES BELOW #
                          
                                atm_overrides = {'ranks': override_container.get_var('atmos_npes'),
                                                 'threads': override_container.get_var('atmos_nthreads'),
                                                 'layout': override_container.get_var('atm_layout'),
                                                 'io_layout': override_container.get_var('atm_io_layout'),
                                                 'mask_table': override_container.get_var('atm_mask_table')}

                                ocn_overrides = {'ranks': override_container.get_var('ocean_npes'),
                                                 'threads': override_container.get_var('ocean_nthreads'),
                                                 'layout': override_container.get_var('ocn_layout'),
                                                 'io_layout': override_container.get_var('ocn_io_layout'),
                                                 'mask_table': override_container.get_var('ocn_mask_table')}

                                lnd_overrides = {'ranks': override_container.get_var('land_npes'),
                                                 'threads': override_container.get_var('land_nthreads'),
                                                 'layout': override_container.get_var('lnd_layout'),
                                                 'io_layout': override_container.get_var('lnd_io_layout'),
                                                 'mask_table': override_container.get_var('lnd_mask_table')}

                                ice_overrides = {'ranks': override_container.get_var('ice_npes'),
                                                 'threads': override_container.get_var('ice_nthreads'),
                                                 'layout': override_container.get_var('ice_layout'),
                                                 'io_layout': override_container.get_var('ice_io_layout'),
                                                 'mask_table': override_container.get_var('ice_mask_table')}

                                override_list = [atm_overrides, ocn_overrides, lnd_overrides, ice_overrides]
                               
                                 
                                #DEBUG
                                #print("\n****************REGULAR ATTRIBUTES*******************")
                                #print("Experiment: " + str(exp.get('name')))
                                #print(atm_attribs)
                                #print(ocn_attribs)
                                #print(lnd_attribs)
                                #print(ice_attribs)

                                #print("\n**************OVERRIDE ATTRIBUTES*******************")
                                #print("Experiment: " + str(exp.get('name')))
                                #print(atm_overrides)
                                #print(ocn_overrides)
                                #print(lnd_overrides)
                                #print(ice_overrides)
                                #sys.exit(1)

                                for override_dict in override_list:
           
                                    for key, value in override_dict.items():

                                        if value == '' or value == None:
                                            del override_dict[key]

                                #The following nested loop preserves values from experiment namelist
                                #that were not overriden by the overrideParams attribute
                                for index, override_dict in enumerate(override_list):

                                    if len(override_dict) < len(attrib_list[index]):

                                        for key, value in attrib_list[index].items():

                                            if key not in override_dict:
                                                override_dict[key] = value

                                atm_reg_ovr = ET.SubElement(resource_reg_element, 'atm', attrib=atm_overrides) if len(atm_overrides) > 0 else None
                                atm_reg_ovr.tail = "\n                "
                                ocn_reg_ovr = ET.SubElement(resource_reg_element, 'ocn', attrib=ocn_overrides) if len(ocn_overrides) > 0 else None
                                ocn_reg_ovr.tail = "\n                "
                                lnd_reg_ovr = ET.SubElement(resource_reg_element, 'lnd', attrib=lnd_overrides) if len(lnd_overrides) > 0 else None

                                if lnd_reg_ovr is not None:
                                    lnd_reg_ovr.tail = "\n                "

                                ice_reg_ovr = ET.SubElement(resource_reg_element, 'ice', attrib=ice_overrides) if len(ice_overrides) > 0 else None

                                if ice_reg_ovr is not None:
                                    ice_reg_ovr.tail = "\n              "               

                        #No <run> tag inside <regression> = Do nothing!
                        else:
                            pass

            # No <runtime> tag = Do nothing!
            else:
                pass

        else: #Don't do Build experiment
            pass
        

def parse_overrides(override_str, override_container):

    nml_regex = r';\s*(.*?)\s*:'
    param_regex = r':\s*(.*?)\s*='
    value_regex = r'=\s*(.*?)\s*;'

    foo_override = ';' + override_str
    namelists = re.findall(nml_regex, foo_override)
    params = re.findall(param_regex, override_str)
    values = re.findall(value_regex, override_str)

    #Sanity check - length of namelists, params, and values should be the same
    if not len(namelists) == len(params) == len(values):
        print("WARNING! The overrideParams attribute is not set up correctly! Skipping regression.")
        return None

    for index, namelist in enumerate(namelists):

        if namelist in nmls_to_edit:

            if params[index] in configs_to_edit:
        
                if params[index] == 'layout' or params[index] == 'io_layout':
                
                    if namelist == 'fv_core_nml':
                        key = 'atm_' + params[index]
                        override_container.nml_vars[key] = values[index]
                    elif namelist == 'ocean_model_nml':
                        key = 'ocn_' + params[index]
                        override_container.nml_vars[key] = values[index]
                    elif namelist == 'ice_model_nml':
                        key = 'ice_' + params[index]
                        override_container.nml_vars[key] = values[index]
                    elif namelist == 'land_model_nml':
                        key = 'lnd_' + params[index]
                        override_container.nml_vars[key] = values[index]

                else:
                    override_container.nml_vars[params[index]] = values[index]

            #Correct namelist, wrong parameter, so don't parse
            else:
                pass

        #A namelist we don't have to parse
        else:
            pass
 

def get_modified_overrides(override_str):

    override_list = override_str.split(';')
    modified_overrides_list = [item for item in override_list if not \
                              ('npes' in item or 'nthreads' in item \
                               or 'layout' in item)]
    modified_overrides_str = ';'.join(modified_overrides_list)
    return modified_overrides_str

'''
def throw_regression_warnings(etree_root):

    for exp in etree_root.iter('experiment'):    
        exp_name = exp.get('name')

        if exp.find('runtime') is not None:

            if exp.find('runtime').find('regression') is not None:
                print("ATTENTION! Experiment " + str(exp_name) + " contains <regression> tags. \
                      freconvert.py does not adjust content within <regression> and will have \
                      to be modified manually.")
'''

#5. Insert/Modify publicMetadata Tags

### We will ignore any community tags or attributes in the build experiment
### Primary attributes seen in many bronx-10 XMLs are for database insertion. These
### include the following attributes: "communityProject", "communityModel", "communityModelID",
### "communityExperimentName", "communityExperimentID", "communityForcing" -- <scenario tag>,
### "startTime" -- <scenario tag>, "endTime" -- <scenario tag>, "parentExperimentID" -- <scenario tag>,
### "parentExperimentID" -- <scenario tag>, and "branch_time" -- <scenario tag>
###
### The tags to be replaced are <scenario> and <communityComment>.
### The tags that may need modification are <realization> and <description.

### Key changes: communityProject attribute ---------> project tag

###              communityModel attribute -----------> source tag
###              communityModelID attribute ---------> source_id tag
###              communityExperimentName attribute --> experiment_name tag
###              communityExperimentID attribute ----> experiment_id tag
###              communityComment tag ---------------> comment tag
###              scenario tag -----------------------> deleted
###              communityForcing attribute ---------> variant_info tag
###              startTime attribute ----------------> start_time tag
###              endTime attribute ------------------> end_time tag
###              parentExperimentID attribute -------> parent_experiment_id tag
###              parentExperimentRIP attribute ------> parent_variant_label tag
###              branch_time attribute --------------> branch_time_in_parent tag
###              publicMetadata tags ----------------> Add tag and option attribute DBswitch=$(MDBIswitch)
###              description tag --------------------> Removal of attributes
###              source_type tag --------------------> Add
###              branch_time_in_child tag -----------> Add
###              parent_activity_id tag -------------> Add
###              activity_id tag --------------------> Add
###              parent_source_id tag ---------------> Add
###              parent_time_units tag --------------> Add
###              sub_experiment tag -----------------> Add
###              sub_experiment_id tag --------------> Add

#   Check to see if tags are already updated (i.e. do publicMetadata tags already exist)
#   There are 3 tiers of database entry. First tier in bronx-10 with the community tags.
#   Second tier is bronx-11 with publicMetadata tags, but outdated tags.
#   Third tier is Bronx-12+ with correct publicMetadata tags in place.


class Metadata(object):

    #"not_applicable_1" and "not_applicable_2" refer to "communityVersion" and "communityGrid" respectively
    #They are tagged as N/A, but it's not possible to use a '/' in __slots__
    #Currently excludes 'realization' tag

    #NOTE: ORDER IS VERY IMPORTANT HERE!


    __slots__ = ["project", "realization", "source", "source_id", "source_type", "experiment_name", "experiment_id", \
                 "comment", "variant_info", "start_time", "end_time", "parent_experiment_id", "parent_variant_label", \
                "parent_activity_id", "parent_time_units", "parent_source_id", "branch_time_in_parent",     \
                "branch_time_in_child", "activity_id", "sub_experiment", "sub_experiment_id", "name1",     \
                "name2", "not_applicable_1", "not_applicable_2"]

    conversion_table_bronx_10 = dict(zip(["communityProject", "realization", "communityModel", "communityModelID", \
                                          "source_type", "communityExperimentName", "communityExperimentID", "comment", \
                                         "communityForcing", "startTime", "endTime", "parentExperimentID", \
                                         "parentExperimentRIP", "parent_activity_id", "parent_time_units", \
                                         "parent_source_id", "branch_time", "branch_time_in_child", "activity_id", \
                                         "sub_experiment", "sub_experiment_id", "domainName", "communit yName", \
                                          "communityVersion", "communityGrid"], __slots__))

    conversion_table_bronx_11 = dict(zip(["project", "realization", "model", "modelID", "source_type", "experimentName", \
                                         "experimentID", "comment", "forcing", "startTime", "endTime", \
                                         "parentExperimentID", "parentExperimentRIP", "parent_activity_id", \
                                         "parent_time_units", "parent_source_id", "branchTime", "branch_time_in_child", \
                                         "activity_id", "sub_experiment", "sub_experiment_id", "name1", "name2", \
                                         "not_applicable_1", "not_applicable_2"], __slots__))

    def __init__(self):

        for tag in self.__slots__:

             setattr(self, tag, None)


    def print_metadata(self):

        print("\t  Tag\t\t\t\t\t Value\n\t________\t\t\t\t________\n")
        for tag in self.__slots__:

            print("\t%-22s\t\t\t%-22s" % (tag, getattr(self, tag)))


    def set_metadata(self, meta_key, meta_value):

        setattr(self, meta_key, meta_value)


    def get_value_from_tag(self, tag):

        return getattr(self, tag)


    def set_comment(self, communityComment_element):

        self.set_metadata("comment", communityComment_element.text)


    def set_tags_from_element(self, element):

        for attrib, value in element.items():

            new_key = self.convert_to_tag(attrib, bronx_version=10)
            self.set_metadata(new_key, value)


    def convert_to_tag(self, attrib, bronx_version=10):

        if bronx_version == 10:
            return self.conversion_table_bronx_10[attrib]
        else:
            return self.conversion_table_bronx_11[attrib]


    def delete_attributes(self, element):

        for attrib in element.keys():
            element.attrib.pop(attrib)
            

    def build_metadata_xml(self, experiment_element):

        new_metadata = ET.Element('publicMetadata', attrib={'DBswitch': '$(MDBIswitch)'})
        new_metadata.text = '\n      '
        new_metadata.tail = '\n\n    '
        experiment_element.insert(0, new_metadata)
        for tag in self.__slots__:

            #Check for realization tag. Go to next tag once try/except is completed
            if tag == 'realization':
                try:
                    realization_element = experiment_element.find('realization')
                    realization_dict = realization_element.attrib
                    experiment_element.remove(realization_element)
                    realization_meta_tag = ET.SubElement(new_metadata, 'realization')
                    realization_meta_tag.tail = '\n      '
                    for key, value in realization_dict.items():

                        realization_meta_tag.set(key, value)

                    continue

                except AttributeError as e:
                    continue

            else:
                value = self.get_value_from_tag(tag)

                if value is not None:
                    meta_sub_element = ET.SubElement(new_metadata, tag) #Create new tag if content exists.
                    meta_sub_element.text = value
                    meta_sub_element.tail = '\n      '

                else:
                    pass #Don't create any tags if value is None.


def do_metadata_main(etree_root):

    executed_metadata = False
    for exp in etree_root.iter('experiment'):

        subelements = [elem.tag for elem in exp.iter() if elem is not exp]
        if not 'compile' in subelements: 
            meta = Metadata()
            experiment_name = exp.get('name')

            #Sanity check -- make sure no publicMetadata tags are intermingled with description attributes,
            #scenario tags, or communityComment tags

            if (exp.find('publicMetadata') is not None) and ((exp.find('scenario') is not None) \
            or (exp.find('communityComment') is not None) or (exp.find('description').attrib != {})):

                print("WARNING! You have a mix of Bronx-10 and Bronx-11/12 metadata elements")
                print("Skipping experiment %s" % experiment_name)
                continue

        #---------------Bronx-11 metadata checks--------------#

            if exp.find('publicMetadata') is not None:
                metadata_head = exp.find('publicMetadata')
                for elem in metadata_head.iter():

                    if elem.tag == 'publicMetadata':
                        continue
                    else:
                        elem.tag = meta.convert_to_tag(elem.tag, bronx_version=11)
                        executed_metadata = True

                continue #No need to do Bronx-10 metadata checks. We already did that above. Go to next experiment.

        #------------Bronx-10 metadata checks------------#
            scenario_elem = False
            description_metadata = False
            community_comm_elem = False

            if exp.find('scenario') is not None:
                scenario_elem = True
                scenario_element = exp.find('scenario')
                meta.set_tags_from_element(scenario_element)
                meta.delete_attributes(scenario_element)
                exp.remove(scenario_element)

            if exp.find('description') is not None:
                description_element = exp.find('description')

                if not len(description_element.keys()) == 0:
                    description_metadata = True
                    description_element.text = description_element.text.strip()
                    meta.set_tags_from_element(description_element)
                    meta.delete_attributes(description_element)

            if exp.find('communityComment') is not None:
                community_comm_elem = True
                comment_element = exp.find('communityComment')
                comment_element.text = comment_element.text.strip()
                meta.set_comment(comment_element)
                exp.remove(comment_element)

            if scenario_elem or community_comm_elem or description_metadata:
                meta.build_metadata_xml(exp)
                executed_metadata = True

            continue

        else: #Don't do Build Experiment
            pass

    if not executed_metadata:
        print("No metadata to parse. Skipping...")


## ----------------------------- END XML PARSING  ----------------------------##


## ----------------------------- BEGIN POST-XML PARSING  ----------------------------##

def write_final_xml(xml_string, setup_include=False):

    xml_string = xml_string.replace('&lt;', '<')
 
    #1. Parse <xml_comment> and </xml_comment> back to <!-- and --> respectively
    xml_string = xml_string.replace('<xml_comment>', '<!--')
    xml_string = xml_string.replace('</xml_comment>', '-->')
 
    #2. Parse <cdata> and </cdata> back to <![CDATA[ and ]]> respectively.
    xml_string = xml_string.replace('<cdata>', '<![CDATA[')
    xml_string = xml_string.replace('</cdata>', ']]>')

    #3. Parse <doctype> and </doctype> back to '<!DOCTYPE' and ']>' respectively
    xml_string = xml_string.replace('<doctype>', '<!DOCTYPE')
    xml_string = xml_string.replace('</doctype>', ']>')

    #4. Parse <entity> and </entity> back to '<!ENTITY' and '>' respectively
    xml_string = xml_string.replace('<entity>', '<!ENTITY')
    xml_string = xml_string.replace('</entity>', '>')

    #3. Restore any escaped chars from pre-XML parsing
    xml_string = xml_string.replace('&amp;', '&')
    xml_string = xml_string.replace('&gt;', '>')

    #4. Remove <root> tags (restore first <root> with <?xml_version?> tag
    xml_string = re.sub('<root.*', '<?xml version="1.0"?>', xml_string)
    xml_string = xml_string.replace('</root>', '') 
   
    xml_string = xml_string.replace('<xml_root>', '<root>')
    xml_string = xml_string.replace('</xml_root>', '</root>')

    #5. Remove instances of 'ns0:'; replace with 'xi:'
    xml_string = xml_string.replace('<ns0:', '<xi:')
    
    #6. Restore attribute xml:ns for the <experimentSuite> tag or <setup> tag
    if setup_include:
        ns_line = re.search('<setup.*(?=\>)', xml_string).group()
    else:
        ns_line = re.search('<experimentSuite.*(?=\>)', xml_string).group()

    ns_att = ' xmlns:xi="http://www.w3.org/2001/XInclude"'
    xml_string = xml_string.replace(ns_line, ns_line + ns_att)

    #7. Remove two whitespace characters before closing </publicMetadata> tag
    xml_string = xml_string.replace('      </publicMetadata>', '    </publicMetadata>')

    #8. Get rid of extra space between end tag slash.
    xml_string = xml_string.replace(' />', '/>')

    return xml_string 


## ----------------------------- END POST-XML PARSING  --------------------------- ##

## ----------------------------- MAIN PROGRAM ------------------------------------ ##

if __name__ == '__main__':

    # GET THE COMMAND LINE ARGUMENTS AND READ IN THE INPUT XML #
    parser = argparse.ArgumentParser(prog='freconvert', description=\
                                     "A Python script that converts a user's XML to the latest FRE version (bronx-14)")
    parser.add_argument('-o', '--output_xml', help='Destination path of converted XML')
    parser.add_argument('-s', '--setup', action='store_true', help='Specifies a setup_include XML')
    parser.add_argument('-q', '--quiet', help='Very little verbosity')
    parser.add_argument('-v', '--verbosity', action='store_true', help='Increase output verbosity.')
    parser.add_argument('-x', '--input_xml', required=True, type=str, help='Path of XML to be converted.')
    args = parser.parse_args()

    if not os.path.exists(args.input_xml):
        print("ERROR! The file path for the input XML does not exist")
        sys.exit(1) 
    elif not args.input_xml.endswith('.xml'):
        print("ERROR! Not a valid XML file (Bad extension)")
        sys.exit(1)

    input_xml = args.input_xml
    file_dest = args.output_xml

    if file_dest is None:
        modified_input_path = os.path.abspath(input_xml).replace('.xml', '')
        file_dest = modified_input_path + '_' + newest_version + '.xml'
    else:
        pass
    
    with open(input_xml, 'r') as f:
        input_content = f.read()

    # RUN THE PRE-XML PARSER AND TURN INTO ElementTree INSTANCE #
    print("Pre-parsing XML...")
    time.sleep(1) 
    pre_parsed_xml = write_parsable_xml(input_content) #Change paths to F2 - ALL BRONX VERSIONS
    #with open('testing.xml', 'w') as f:
        #f.write(pre_parsed_xml)
    #exit()
    try:
        tree = ET.ElementTree(ET.fromstring(pre_parsed_xml))
    except ET.ParseError as e:
        print("\nERROR: %s" % str(e).upper()) 
        print("The XML is non-conforming! Please correct issues and re-run freconvert.py")
        print("Writing out the pre-parsed file for debugging.")
        file_dest = file_dest.replace(newest_version + '.xml', 'pre_parsed_error.xml')

        with open(file_dest, 'w') as f:
            f.write(pre_parsed_xml)
        print("Path to Pre-Parsed XML: %s" % file_dest)

        sys.exit(1)
    
    #tree = ET.ElementTree(ET.fromstring(pre_parsed_xml))
    root = tree.getroot()
    
    # PARSE AND MODIFY ELEMENTS DEPENDING ON ORIGINAL BRONX VERSION #
    old_version = do_properties(root)    # freVersion checking # ALL BRONX VERSIONS
    print("Converting XML from %s to %s..." % (old_version, newest_version))
    time.sleep(3)
    if old_version == 'bronx-10':
        #print("Checking for land F90 <csh> block...")
        time.sleep(1)
        do_land_f90(root)
        #print("Checking for 'default' platforms (will be removed)...")
        time.sleep(1) 
        delete_default_platforms(root)
        #print("Adding <freVersion> tags...")
        time.sleep(1)
        add_fre_version_tag(root)
        #print("Checking for existence of 'compiler' tag in platforms")
        time.sleep(1)
        add_compiler_tag(root)
        #print("Adding resources tags...")
        time.sleep(1)
        do_resources_main(root) # Resource Tags - change namelists and create <resources> # IF BRONX-10
        #throw_regression_warnings(root)
        time.sleep(1)
        print("Checking for metadata. Adding <publicMetadata> tags if necessary...")
        time.sleep(1)
        do_metadata_main(root)  # Create and/or modify metadata tags #IF BRONX-10 or BRONX-11
        xml_string = ET.tostring(root)
        print("Linking paths to F2. Performing final XML manipulations...")
        time.sleep(1)
        xml_string = convert_xml_text(xml_string, prev_version=old_version)
        final_xml = write_final_xml(xml_string, args.setup)

    elif old_version == 'bronx-11':
        print("Checking for 'default' platforms (will be removed)...")
        time.sleep(1)
        delete_default_platforms(root)
        print("Checking for metadata. Updating tags if necessary...")
        time.sleep(1)
        do_metadata_main(root)
        xml_string = ET.tostring(root)
        print("Linking paths to F2. Performing final XML manipulations...")
        xml_string = convert_xml_text(xml_string, prev_version=old_version)
        final_xml = write_final_xml(xml_string, args.setup)

    # No need to parse XML with ElementTree if Bronx-12 or Bronx-13. Just do string replacements.
    elif old_version == 'bronx-12':
        print("Linking paths to F2. Performing final XML manipulations...")
        time.sleep(1)
        final_xml = convert_xml_text(input_content, prev_version=old_version)
    
    elif old_version == 'bronx-13':
        print("Making Slurm compatible...")
        time.sleep(1)
        final_xml = convert_xml_text(input_content, prev_version=old_version)
    
    elif old_version == newest_version:
        print("XML is already at the newest version (%s)" % newest_version)
        sys.exit(1)

    else:
        print("ERROR! This version of FRE (%s) isn't supported for conversion!" % old_version)
        sys.exit(1)
   
    print("Writing new XML...")
    time.sleep(1)
    # WRITE THE FINAL XML TO STATED FILE DESTINATION OR CREATE ONE IF -o OPTION IS NOT GIVEN
    with open(file_dest, 'w') as f:
        f.write(final_xml)

    print("Converted XML written to %s" % (file_dest))
    

