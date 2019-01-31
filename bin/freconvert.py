#!/usr/bin/python

import os
import sys
import re
import time
import argparse
import xml.etree.ElementTree as ET


## --------------- Parse the XML as a Text file first ------------- ##

# Rewrite comment and 'CDATA' blocks as their own temporary tags #

replacement_char = '&lt;'


def rreplace(string, old, new, occurrence=1):
    
    str_list = string.rsplit(old, occurrence)
    return new.join(str_list)


def strip_char(list_of_strings, char_to_strip='<', char_to_replace='&lt;'):
    
    replacement_count_list = []
    for i in range(len(list_of_strings)):
        
        if char_to_strip in list_of_strings[i]:
            list_of_strings[i] = list_of_strings[i].replace(char_to_strip, replacement_char)
            replacement_count_list.append(list_of_strings[i].count(replacement_char))
        else:
            replacement_count_list.append(0)
            
    return list_of_strings, replacement_count_list


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


def write_parsable_xml(xml_string):
    
    xml_declaration = '<?xml version="1.0"?>'
    xml_string = xml_declaration + "\n" + '<root>' + "\n" + xml_string
    
    if xml_string.count(xml_declaration) > 1:
        xml_string = rreplace(xml_string, xml_declaration, '')
        
    xml_string = xml_string.replace('&', '&amp;')
    
    comment_regex = '<!--(.*?)-->'
    cdata_regex = '<!\[CDATA\[(.*?)\]\]>'
    
    comment_strings, comment_replacements = strip_char(re.findall(comment_regex, xml_string, re.DOTALL), \
                                                      char_to_replace=replacement_char)
    cdata_strings, cdata_replacements = strip_char(re.findall(cdata_regex, xml_string, re.DOTALL), \
                                                  char_to_replace=replacement_char)
    
    xml_string = xml_string.replace('<!--', '<xml_comment>')
    xml_string = xml_string.replace('-->', '</xml_comment>')
    xml_string = xml_string.replace('<![CDATA[', '<cdata>')
    xml_string = xml_string.replace(']]>', '</cdata>')
    
    xml_string = points_to_f2(xml_string)

    comment_opens = [m.start() + 13 for m in re.finditer('<xml_comment>', xml_string)]
    comment_ends = [m.start() for m in re.finditer('</xml_comment>', xml_string)]
    
    diff = 0
    for i, start in enumerate(comment_opens):
        
        xml_string = xml_string.replace(xml_string[start + diff:comment_ends[i] + diff], comment_strings[i])
        diff += ((len(replacement_char) - 1) * comment_replacements[i])
        
    cdata_opens = [m.start() + 7 for m in re.finditer('<cdata>', xml_string)]
    cdata_ends = [m.start() for m in re.finditer('</cdata>', xml_string)]
    
    diff = 0
    for i, start in enumerate(cdata_opens):
        
        xml_string = xml_string.replace(xml_string[start + diff:cdata_ends[i] + diff], cdata_strings[i])
        diff += (len(replacement_char) - 1) * cdata_replacements[i]
    
    xml_string = xml_string + "\n</root>"
    
    return xml_string
    
    

## ----------------------------- END PRE-XML PARSER ----------------------------##


## ----------------------------- BEGIN XML PARSING  ----------------------------##


#1 ON CHANGE FOR XML CONVERTER

def modify_components(etree_root):

    for elem in etree_root.iter('postProcess'):

        component_list = elem.findall('component')
        #print(mylist)
        for component in component_list:
            if 'cubicToLatLon' in component.keys():
                temp = component.attrib['cubicToLatLon']
                component.attrib.pop('cubicToLatLon')
                component.set('xyInterp', temp)

            

#2 ON CHANGE FOR XML CONVERTER
# Also, test for case where <freVersion> tag doesn't exist

def do_fre_version(etree_root):

    for prop in etree_root.iter('property'):
        
        if prop.get("name") == "FRE_VERSION" and prop.get("value") != "bronx-13":
            prop.set("value", "bronx-13")
            break
        else:
            pass

    #Check platform tags for <freVersion> tag
    namespace = {'ns0': 'http://www.w3.org/2001/XInclude'}
    for platform in etree_root.iter('platform'):

        if not platform.find('freVersion'):
            for elem in platform.iter():
                #print(elem.tag)
                if elem.tag == '{http://www.w3.org/2001/XInclude}include':
                    print("Found the namespace!!!")
                    continue
            #print('Found a non-freVersion platform')
            #print(platform.tag)
            #if platform.find('ns0:include', namespace):
            #    print('Found namespace platform')
            #    continue
            
            freVersion_elem = ET.SubElement(platform, 'freVersion')
            freVersion_elem.text = '$(FRE_VERSION)'

    
"""
#Delete Default Platforms if they exist -- Work in progress
setup_element = root.find('setup')
platform_list = root.find('setup').findall('platform')

for platform in platform_list:
    if 'default' in platform.get('name'):
        setup_element.remove(platform)
        
platform_list_updated = root.find('setup').findall('platform')
for platform in platform_list_updated:
    print(platform)
    print(platform.get('name'))

"""

#Insert Resource Tags
### This is a longer code element. There will be multiple scenarios that have to be checked.
### First, check for the existence of resources tags in the XML.
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

#nml_names = ["coupler_nml", "fv_core_nml", "ice_model_nml", "land_model_nml", "ocean_model_nml"]

###3.1 - Change variable names in namelist string and produce new namelist string ###


def nml_to_dict(nml):

    str_list = get_str_list(nml)
    nml_dict = {}
    for substr in str_list:
            
        key = substr[:substr.find('=')]
        value = substr[substr.find('=')+1:]
        nml_dict[key] = value

    return nml_dict


def get_str_list(nml):

    #str_list = nml.text.replace(' ', '').splitlines()
    str_list = nml.text.splitlines()
    return str_list


def modify_namelist(nml, nml_name):

    str_list = get_str_list(nml)
    new_nml_str = get_new_nml_str(nml_name, str_list)
    nml.text = new_nml_str

#END FUNCTION: modify_namelist


#Below function returns a string of the new namelist text to be inserted.

def get_new_nml_str(nml_name, old_nml_str_list):

<<<<<<< HEAD
    configs_to_edit = ['atmos_npes', 'atmos_nthreads', 'ocean_npes', \
                       'ocean_nthreads', 'layout', 'io_layout', \
                       'ocean_mask_table', 'ice_mask_table', 'land_mask_table', \
                       'atm_mask_table']
    #print(old_nml_str_list)
=======
    configs_to_edit = ['atmos_npes', 'atmos_nthreads', 'ocean_npes', 'ocean_nthreads',
                       'layout', 'io_layout', 'ocean_mask_table', 'ice_mask_table', 
                       'land_mask_table', 'atm_mask_table']
>>>>>>> 3e071c3f77622d77d0b4cab14cc2990dbd5afbe2

    for index, substr in enumerate(old_nml_str_list):

        #Checking only the string to the LEFT of the equal sign
        #str_to_check = substr[:substr.find('=')]
        #print(substr)
        #print(old_nml_str_list)
        str_to_check = re.search('\w+|^\s*$', substr).group()
        #print(str_to_check)

        #We need to set some default value in case there is no record in namelist
        #Reason: Validation purposes
        if str_to_check not in configs_to_edit:
            continue

        #Anything right of the '=' sign will be replaced
        if nml_name == 'coupler_nml':
            #print("String to check: %s" % str_to_check)
            coupler_dict = {'atmos_npes': '$atm_ranks', 'atmos_nthreads': '$atm_threads',
                            'atmos_mask_table': '$atm_mask_table', 'ocean_npes': '$ocn_ranks',
                            'ocean_nthreads': '$ocn_threads'}

            #Below dictionary is updated if a parameter is found
            coupler_dict_found = {'atmos_npes': False, 'atmos_nthreads': False,
                                  'atmos_mask_table': False, 'ocean_npes': False,
                                  'ocean_nthreads': False}

            for old_str, new_str in coupler_dict.items():
            
                if str_to_check == old_str:
<<<<<<< HEAD
                    #print("String to check: %s; old_str: %s" % (str_to_check, old_str))
=======
                    coupler_dict_found[old_str] = True
>>>>>>> 3e071c3f77622d77d0b4cab14cc2990dbd5afbe2
                    old_nml_str_list[index] = re.sub('(?<=\=).*', new_str, substr)
                    break 

            #Most recent edit.
            for old_str, found in coupler_dict_found.items():

                if not found:
                    old_nml_str_list.append(old_str + '=' + coupler_dict[old_str])

            #if str_to_check == 'atmos_npes':
            #    old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$atm_ranks')
            #elif str_to_check == 'atmos_nthreads':
            #    old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$atm_threads')
            #elif str_to_check == 'atmos_mask_table':
            #    old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$atm_mask_table')
            #elif str_to_check == 'ocean_npes':
            #    old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$ocn_ranks')
            #elif str_to_check == 'ocean_nthreads':
            #    old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$ocn_threads')
            #else:
            #    pass

        elif nml_name == 'fv_core_nml':
            if str_to_check == 'layout':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$atm_layout')
            elif str_to_check == 'io_layout':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$atm_io_layout')
            else:
                pass

        elif nml_name == 'ice_model_nml':
            if str_to_check == 'layout':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$ice_layout')
            elif str_to_check == 'io_layout':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$ice_io_layout')
            elif str_to_check == 'ice_mask_table':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$ice_mask_table'    )
            else:
                pass

        elif nml_name == 'land_model_nml':
            if str_to_check == 'layout':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$lnd_layout')
            elif str_to_check == 'io_layout':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$lnd_io_layout')
            elif str_to_check == 'ice_mask_table':

                 old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$lnd_mask_table'    )
            else:
                pass

        elif nml_name == 'ocean_model_nml':
            if str_to_check == 'layout':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$ocn_layout')
            elif str_to_check == 'io_layout':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$ocn_io_layout')
            elif str_to_check == 'ocean_mask_table':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$ocn_mask_table'    )
            else:
                pass

        else:
            pass

    final_str = '\n'.join(old_nml_str_list)
    return final_str


###3.2 - EXTRACT VALUES FROM NAMELISTS###

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
            exc_idx = string.index('!')
            value = value[:exc_idx]

        if value.count(',') > 1:
            value = rreplace(value, ',', '', occurrence=value.count - 1)

        if value[-1] == ',':
            value = rreplace(value, ',', '')
 
        #Set up class dictionary
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
        
        #print(self.nml_vars)
        #There will be instances where attributes won't exist, so test a 
        #dummy variable in a Try-Except to determine which fields exist/don't exist.
        try:
            foo = self.nml_vars[var]
    
        #Sometimes ocn_nthreads will not be displayed in namelist, but we need
        #it in the resource tags. Set a default value of 1 to be returned.
        except KeyError as e:
            if var == 'ocean_nthreads':
                #print("HEEEELLLLLLOOOO")
                self.nml_vars[var] = '1'
                return self.nml_vars[var]

        return self.nml_vars[var]


#END CLASSES AND FUNCTIONS


### Begin Main 3.1 ###

#def resources_main_1(etree_root):
#
#    for exp in etree_root.iter('experiment'):
#
#        if True: #exp.get("name") == 'CM2.5_FLOR_A06_p1_ECDA_2.1Rv3.1_01_MON__YEAR_':
#            for nml in exp.iter('namelist'):
#
#                nml_name = nml.get("name")
#                modify_namelist(nml, nml_name)
#
#
### End Main 3.1 ###

### Begin Main 3.2 ###

def strip_dict_whitespace(nml_dict):

    new_dict = {}
    for key, value in nml_dict.items():
    
        new_key = key.replace(' ', '')
        new_value = value.replace(' ', '')
        new_dict[new_key] = new_value

    return new_dict

def do_resources_main(etree_root):

    nmls_to_edit = ["coupler_nml", "fv_core_nml", "ice_model_nml", "land_model_nml", "ocean_model_nml"]

    for exp in etree_root.iter('experiment'):

        subelements = [elem.tag for elem in exp.iter() if elem is not exp]
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

                modify_namelist(nml, nml_name)


### End Main 3.2 ###


### Begin Main 3.3 ###

###CREATE RESOURCE TAGS###

            try:
                exp.find('runtime').find('production').attrib.pop('npes')
            except (AttributeError, KeyError) as e:
                pass
        
            try:
                exp.find('runtime').find('production').attrib.pop('runTime')
            except (AttributeError, KeyError) as e:
                pass
        
            try:
                exp.find('runtime').find('production').find('segment').attrib.pop('runTime')
            except (AttributeError, KeyError) as e:
                pass
        

            #IGNORING attributes that don't exist, like mask_table and ice/land ranks and threads.
            #Need to build in exceptions for attributes that don't exist but need checking.

            if True: #exp.find('runtime').find('production').find('resources'):
                
                resource = ET.SubElement(exp.find('runtime').find('production'), 'resources', \
                                         attrib={'site': 'ncrc3', 'jobWallclock': '10:00:00', \
                                         'segRuntime': '10:00:00'})

                atm = ET.SubElement(exp.find('runtime').find('production').find('resources'), 'atm', \
                                    attrib={'ranks': nml_container.get_var('atmos_npes'), \
                                            'threads': nml_container.get_var('atmos_nthreads'), \
                                            'layout': nml_container.get_var('atm_layout'), \
                                            'io_layout': nml_container.get_var('atm_io_layout')})

                ocn = ET.SubElement(exp.find('runtime').find('production').find('resources'), 'ocn', \
                                    attrib={'ranks': nml_container.get_var('ocean_npes'), \
                                            'threads': nml_container.get_var('ocean_nthreads'), \
                                            'layout': nml_container.get_var('ocn_layout'), \
                                            'io_layout': nml_container.get_var('ocn_io_layout')})

                lnd = ET.SubElement(exp.find('runtime').find('production').find('resources'), 'lnd', \
                                    attrib={'layout': nml_container.get_var('lnd_layout'), \
                                            'io_layout': nml_container.get_var('lnd_io_layout')})

                ice = ET.SubElement(exp.find('runtime').find('production').find('resources'), 'ice', \
                                    attrib={'layout': nml_container.get_var('ice_layout'), \
                                            'io_layout': nml_container.get_var('ice_io_layout')})

        else: #Don't do Build experiment
            pass

        

#END MAIN 3.3#


#Insert/Modify PublicMetadata Tags

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

        new_metadata = ET.SubElement(experiment_element, 'publicMetadata')
        for tag in self.__slots__:

            #Check for realization tag. Go to next tag once try/except is completed
            if tag == 'realization':
                try:
                    realization_element = experiment_element.find('realization')
                    realization_dict = realization_element.attrib
                    realization_meta_tag = ET.SubElement(new_metadata, 'realization')
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

                else:
                    pass #Don't create any tags if value is None.

#End Class Metadata

def do_metadata_main(etree_root):

    for exp in etree_root.iter('experiment'):

        subelements = [elem.tag for elem in exp.iter() if elem is not exp]
        if not 'compile' in subelements: 
            test = Metadata()
            experiment_name = exp.get('name')

            #Sanity check -- make sure no publicMetadata tags are intermingled with description attributes,
            #scenario tags, or communityComment tags

            if (exp.find('publicMetadata') is not None) and ((exp.find('scenario') is not None) \
            or (exp.find('communityComment') is not None) or (exp.find('description').attrib != {})):

                #print("\nCondtion truth table\n\n")
            
                #print("publicMetadata: " + str(exp.find('publicMetadata')) + "\n")
                #print("scenario: " + str(exp.find('scenario')) + "\n")
                #print("communityComment: " + str(exp.find('communityComment')) + "\n")
                #print("description: " + str(exp.find('description')) + "\n")
            
                print("ERROR! You have a mix of Bronx-10 and Bronx-11/12 metadata elements")
                print("Skipping experiment %s" % experiment_name)
                continue

        #---------------Bronx-11 metadata checks--------------#

            if exp.find('publicMetadata') is not None:
                metadata_head = exp.find('publicMetadata')
                for elem in metadata_head.iter():

                    if elem.tag == 'publicMetadata':
                        continue
                    else:
                        #print("Old tag: " + elem.tag)
                        elem.tag = test.convert_to_tag(elem.tag, bronx_version=11)
                        #print("New tag: " + elem.tag)

                #print("\nHere's the new metadata section\n")

                #ET.dump(metadata_head)
                continue #No need to do Bronx-10 metadata checks. We already did that above. Go to next experiment.

        #------------Bronx-10 metadata checks------------#


            if exp.find('scenario') is not None:
                scenario_element = exp.find('scenario')
                #print(scenario_element.attrib)
                #print("\n")
                test.set_tags_from_element(scenario_element)
                test.delete_attributes(scenario_element)
                exp.remove(scenario_element)
                #print(scenario_element.attrib)
                #print("After deletion: " + str(scenario_element.attrib))


            if exp.find('description') is not None:
                description_element = exp.find('description')
                #print(description_element.attrib)
                #print("\n")
                test.set_tags_from_element(description_element)
                test.delete_attributes(description_element)
                #print("After deletion: " + str(description_element.attrib))
                #print("Description text: " + description_element.text)

            if exp.find('communityComment') is not None:
                comment_element = exp.find('communityComment')
                test.set_comment(comment_element)
                exp.remove(comment_element)


            #test.print_metadata()
            #print("\nBelow is the new metadata xml section\n\n")

            test.build_metadata_xml(exp)

            continue

        else: #Don't do Build Experiment
            pass


# END publicMetadata Tags

## ----------------------------- END XML PARSING  ----------------------------##

## ----------------------------- BEGIN POST-XML PARSING  ----------------------------##

def write_final_xml(xml_string):


    #1. Parse <xml_comment> and </xml_comment> back to <!-- and --> respectively
    xml_string = xml_string.replace('<xml_comment>', '<!--')
    xml_string = xml_string.replace('</xml_comment>', '-->')
 
    #2. Parse <cdata> and </cdata> back to <![CDATA[ and ]]> respectively.
    xml_string = xml_string.replace('<cdata>', '<![CDATA[')
    xml_string = xml_string.replace('</cdata>', ']]>')

    #3. Restore any escaped chars from pre-XML parsing
    xml_string = xml_string.replace('&amp;', '&')
    xml_string = xml_string.replace('&lt;', '<')
    xml_string = xml_string.replace('&gt;', '>')

    #4. Remove <root> tags (restore first <root> with <?xml_version?> tag
    xml_string = re.sub('<root.*', '<?xml version="1.0"?>', xml_string)
    xml_string = xml_string.replace('</root>', '') 

    #5. Remove instances of 'ns0:'; replace with 'xi:'
    xml_string = xml_string.replace('<ns0:', '<xi:')
    
    #6. Restore attribute xml:ns for the <experimentSuite> tag
    ns_line = re.search('<experimentSuite.*(?=\>)', xml_string).group()
    ns_att = ' xmlns:xi="http://www.w3.org/2001/XInclude"'
    xml_string = xml_string.replace(ns_line, ns_line + ns_att)

    #7. Replace "DO_DATABASE" and "DO_ANALYSIS" with "DB_SWITCH" and "ANALYSIS_SWITCH"
    xml_string = xml_string.replace('DO_ANALYSIS', 'ANALYSIS_SWITCH')
    xml_string = xml_string.replace('DO_DATABASE', 'DB_SWITCH')
 
    return xml_string 

#8. Restore original spacing between tag attributes
#9. Insert appropriate spacing and \n chars for blocks containing new tags

## ----------------------------- END POST-XML PARSING  --------------------------- ##

## ----------------------------- MAIN PROGRAM ------------------------------------ ##

if __name__ == '__main__':

    # GET THE COMMAND LINE ARGUMENTS AND READ IN THE INPUT XML #
    parser = argparse.ArgumentParser(prog='freconvert', description="A script that converts a user's XML to Bronx-13")
    parser.add_argument('-o', '--output_xml', help='Destination path of converted XML')
    parser.add_argument('-v', '--verbosity', help='Increase output verbosity.')
    parser.add_argument('-x', '--input_xml', type=str, help='Path of XML to be converted.')
    args = parser.parse_args()

    input_xml = args.input_xml
    file_dest = args.output_xml

    with open(input_xml, 'r') as f:
        input_content = f.read()

    # RUN THE PRE-XML PARSER AND TURN INTO ElementTree INSTANCE # 
    pre_parsed_xml = write_parsable_xml(input_content)

    tree = ET.ElementTree(ET.fromstring(pre_parsed_xml))
    root = tree.getroot()
   
    # PARSE AND MODIFY ELEMENTS #
    modify_components(root) # xyInterp modification
    do_fre_version(root)    # freVersion checking
    do_resources_main(root)    # Resource Tags - change namelists and create <resources>
    do_metadata_main(root)  # Create and/or modify metadata tags

    # CONVERT EVERYTHING BACK TO A STRING #
    xml_string = ET.tostring(root)

    # RUN THE POST-XML PARSER #
    final_xml = write_final_xml(xml_string)

    # WRITE THE FINAL XML TO STATED FILE DESTINATION
    with open('test_final_original_xml.xml', 'w') as f:
        f.write(final_xml)
    
    #    if file_dest is not None:
    #        tree.write(file_dest)
    #
    #    else:
    #        input_xml = input_xml.replace('.xml', '')
    #        file_dest = os.getcwd() + '/' + input_xml + '_converted.xml'
    #        tree.write(file_dest)
    #

#END SCRIPT   
