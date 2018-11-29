#!/usr/bin/python

### INITIALIZE XML TREE ###

import xml.etree.ElementTree as ET
import os

#os.chdir('/home/Kristopher.Rand/xml') # -- GFDL workstation location
#os.chdir("C:\\Users\\Owner\\Documents\\Engility\\GFDL")# Windows Location
#print(os.getcwd())
#print("Hello world")
tree = ET.parse('CM2.5-bronx10.xml')
root = tree.getroot()
#print(tree)


### CHANGE 'cubicToLatLon' TO 'xyInterp' ###

#tree = ET.parse('CM2.5-bronx10.xml')
#root = tree.getroot()

for elem in root.iter('postProcess'):

    mylist = elem.findall('component')
    #print(mylist)
    for i in mylist:
        if 'cubicToLatLon' in i.keys():
            temp = i.attrib['cubicToLatLon']
            i.attrib.pop('cubicToLatLon')
            i.set('xyInterp', temp)
            print(i.items())


### CHANGE THE ATTRIBUTE OF 'freVersion' TO 'Bronx-13' ###

#tree = ET.parse('CM2.5-bronx10.xml')
#root = tree.getroot()

for prop in root.iter('property'):
    #print(prop)
    if prop.get("name") == "FRE_VERSION" and prop.get("value") != "bronx-13":
        prop.set("value", "bronx-13")
        break
    else:
        pass


### INSERT 'freVersion' TAG IF NONE EXIST ###

#tree = ET.parse('CM2.5-bronx10.xml')
#root = tree.getroot()

for platform in root.iter('platform'):
    if platform.find('freVersion') is None:
        freVersion_elem = ET.SubElement(platform, 'freVersion')
        freVersion_elem.text = '$(FRE_VERSION)'


### DELETE 'default' PLATFORMS IF THEY EXIST ###

#tree = ET.parse('CM2.5-bronx10.xml')
#root = tree.getroot()

setup_element = root.find('setup')
platform_list = root.find('setup').findall('platform')

for platform in platform_list:
    if 'default' in platform.get('name'):
        setup_element.remove(platform)
        
#platform_list_updated = root.find('setup').findall('platform')
#for platform in platform_list_updated:
    #print(platform)
    #print(platform.get('name'))

"""
### INSERT RESOURCE TAGS ###

#tree = ET.parse('CM2.5-bronx10.xml')
#root = tree.getroot()


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

    str_list = nml.text.replace(' ', '').splitlines()
    return str_list


def modify_namelist(nml, nml_name):

    str_list = get_str_list(nml)
    new_nml_str = get_new_nml_str(nml_name, str_list)
    nml.text = new_nml_str

#END FUNCTION: modify_namelist


#Below function returns a string of the new namelist text to be inserted.

def get_new_nml_str(nml_name, old_nml_str_list):

    configs_to_edit = ['atmos_npes', 'atmos_nthreads', 'ocean_npes', 'layout', 'io_layout', \
                      'ocean_mask_table', 'ice_mask_table', 'land_mask_table', 'atm_mask_table']

    for index, substr in enumerate(old_nml_str_list):

        #Checking only the string to the LEFT of the equal sign
        str_to_check = substr[:substr.find('=')]

        if str_to_check not in configs_to_edit:
            #print(substr)
            continue

        #Anything right of the '=' sign will be replaced
        if nml_name == 'coupler_nml':

            if str_to_check == 'atmos_npes':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$atm_ranks')
            elif str_to_check == 'atmos_nthreads':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$atm_threads')
            elif str_to_check == 'atmos_mask_table':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$atm_mask_table'    )
            elif str_to_check == 'ocean_npes':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$ocn_ranks')
            elif str_to_check == 'ocean_nthreads':
                old_nml_str_list[index] = substr.replace(substr[substr.find('=')+1:], '$ocn_threads')
            else:
                pass

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

#END FUNCTION: get_new_nml_str

###3.2 - EXTRACT VALUES FROM NAMELISTS###

class Namelist(object):
    def __init__(self):
        self.nml_vars = {}

    def set_var(self, nml_dict, nml_name, set_layout=False, set_io_layout=False, layout_group="", io_layout_group=""):
        try:
            if set_layout == True:
                self.nml_vars[layout_group + "_" + nml_name] = nml_dict[nml_name]
            elif set_io_layout == True:
                self.nml_vars[io_layout_group + "_" + nml_name] = nml_dict[nml_name]
            else:
                self.nml_vars[nml_name] = nml_dict[nml_name]


        except KeyError as e:
            pass

    def print_vars(self):
        for key, value in self.nml_vars.items():
            print("%s = %s" % (key, value))

    def get_var(self, var):

        return self.nml_vars[var]


class Resource(object):
    def __init__(self):
        self.nml_list = []
        self.jobWallclock = ""
        self.segRuntime = ""
        self.site = ""

    def add_namelist(nml_obj):
        self.nml_list.append(nml_obj)

#END CLASSES AND FUNCTIONS

### Begin Main 3.1 ###


for exp in root.iter('experiment'):

    if exp.get("name") == 'CM2.5_FLOR_A06_p1_ECDA_2.1Rv3.1_01_MON__YEAR_':
        for nml in exp.iter('namelist'):

            nml_name = nml.get("name")
            print("\t\t\t --- NAMELIST " + nml_name + " BEFORE MODIFICATION ---" )
            print(nml.text)
            modify_namelist(nml, nml_name)
            print("\t\t\t --- NAMELIST " + nml_name + " AFTER MODIFICATION ---")
            print(nml.text)




### End Main 3.1 ###


### Begin Main 3.2 ###

nmls_to_edit = ["coupler_nml", "fv_core_nml", "ice_model_nml", "land_model_nml", "ocean_model_nml"]
#key_value_relationship = {"atm": "atm", "ice": "ice", "land": "lnd", "ocean", "ocn"}


for exp in root.iter('experiment'):

    #resource_container = Resource() #1 resource object per experiment. It will hold all necessary resource values per exp
    if exp.get("name") == 'CM2.5_FLOR_A06_p1_ECDA_2.1Rv3.1_01_MON__YEAR_':
        resrc_container = Resource()
        nml_container = Namelist() #1 namelist object per experiment. It will hold all necessary namelist values per key.
        for nml in exp.iter('namelist'):

            nml_name = nml.get("name")
            if nml_name in nmls_to_edit:
                nml_container.name = nml_name
                nml_dict = nml_to_dict(nml)

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

        break #Leaves the loop after getting through the experiment conditional

print("\n\n")
nml_container.print_vars()

### End Main 3.2 ###


### Begin Main 3.3 ###

###CREATE RESOURCE TAGS###

for exp in root.iter('experiment'):
    if exp.get('name') == 'CM2.5_FLOR_A06_p1_ECDA_2.1Rv3.1_01_MON__YEAR_':
        try:
            exp.find('runtime').find('production').attrib.pop('npes')
        except KeyError as e:
            pass
        
        try:
            exp.find('runtime').find('production').attrib.pop('runTime')
        except KeyError as e:
            pass
        
        try:
            exp.find('runtime').find('production').find('segment').attrib.pop('runTime')
        except KeyError as e:
            pass
        
        print(exp.find('runtime').find('production').attrib)
        print(exp.find('runtime').find('production').find('segment').attrib)

        #IGNORING attributes that don't exist, like mask_table and ice/land ranks and threads.
        #Need to build in exceptions for attributes that don't exist but need checking.
        if exp.find('runtime').find('production').find('resources') is None:
            print("\nResource content: " + str(exp.find('resources')))
            print("\nBefore resource line\n")
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
                                   'layout': nml_container.get_var('ocn_layout'), \
                                   'io_layout': nml_container.get_var('ocn_io_layout')})

            lnd = ET.SubElement(exp.find('runtime').find('production').find('resources'), 'lnd', \
                                attrib={'layout': nml_container.get_var('lnd_layout'), \
                                   'io_layout': nml_container.get_var('lnd_io_layout')})

            ice = ET.SubElement(exp.find('runtime').find('production').find('resources'), 'ice', \
                                attrib={'layout': nml_container.get_var('ice_layout'), \
                                   'io_layout': nml_container.get_var('ice_io_layout')})

        else:
            pass
        
        print(exp.find('runtime').find('production').find('resources'))
        

        print(ET.dump(exp.find('runtime')))

#END MAIN 3.3#


### INSERT 'publicMetadata' TAGS ###

#tree = ET.parse('CM2.5-bronx10.xml')
#root = tree.getroot()

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

    #def sanity_check(self, experiment_element):
    #
    #    try:


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



#--MAIN--#

for exp in root.iter('experiment'):

    if exp.get('name') == 'CM2.5_FLOR_A06_p1_ECDA_2.1Rv3.1_01_MON__YEAR_':
        test = Metadata()

        experiment_name = exp.get('name')

        #Sanity check -- make sure no publicMetadata tags are intermingled with description attributes,
        #scenario tags, or communityComment tags

        if (exp.find('publicMetadata') is not None) and ((exp.find('scenario') is not None) \
        or (exp.find('communityComment') is not None) or (exp.find('description').attrib != {})):

            print("\nCondtion truth table\n\n")
            
            print("publicMetadata: " + str(exp.find('publicMetadata')) + "\n")
            print("scenario: " + str(exp.find('scenario')) + "\n")
            print("communityComment: " + str(exp.find('communityComment')) + "\n")
            print("description: " + str(exp.find('description')) + "\n")
            
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
                    print("Old tag: " + elem.tag)
                    elem.tag = test.convert_to_tag(elem.tag, bronx_version=11)
                    print("New tag: " + elem.tag)

            print("\nHere's the new metadata section\n")

            ET.dump(metadata_head)
            continue #No need to do Bronx-10 metadata checks. We already did that above. Go to next experiment.

        #------------Bronx-10 metadata checks------------#


        if exp.find('scenario') is not None:
            scenario_element = exp.find('scenario')
            print(scenario_element.attrib)
            print("\n")
            test.set_tags_from_element(scenario_element)
            test.delete_attributes(scenario_element)
            exp.remove(scenario_element)
            #print(scenario_element.attrib)
            print("After deletion: " + str(scenario_element.attrib))


        if exp.find('description') is not None:
            description_element = exp.find('description')
            print(description_element.attrib)
            print("\n")
            test.set_tags_from_element(description_element)
            test.delete_attributes(description_element)
            print("After deletion: " + str(description_element.attrib))
            print("Description text: " + description_element.text)

        if exp.find('communityComment') is not None:
            comment_element = exp.find('communityComment')
            test.set_comment(comment_element)
            exp.remove(comment_element)


        test.print_metadata()
        print("\nBelow is the new metadata xml section\n\n")

        test.build_metadata_xml(exp)

        ET.dump(exp.find('publicMetadata'))
        continue


# END publicMetadata Tags


### ADD 'sourceGrid' ATTRIBUTE TO 'postProcess' TAGS WHEN 'xyInterp' ATTRIBUTE IS USED ###

#Choices for sourceGrid#
# atmos-latlon
# atmos-cubedsphere
# land-cubedsphere
# ocean-tripolar
"""
### Output final XML ###

#tree.write('test_converter.xml')

### IMPORTANT ### 

#I need to be able to capture the CDATA tags within the XML and output them
#back into CDATA tags. ElementTree does not support this. Will need to hack around
#csh_text = []

tree = ET.parse('CM2.5-bronx10.xml')
root = tree.getroot()

for csh_block in root.iter('csh'):
    print(csh_block)
    csh_text = csh_block.text
    #new_text = ET.tostring(csh_block)
    #print(new_text)
    new_text = "<![CDATA[\n" + csh_text + "\n]]>"
    csh_block.text = new_text
    #print(csh_block.text)
    ET.dump(csh_block)
    #csh_text.append(csh_block.text)

tree.write('temp.xml')

    

#print(csh_text)


with open('temp.xml', 'r') as f:
    data = f.read()
    if '&gt;' in data:
        data = data.replace('&gt;', '>')
    if '&lt;' in data:
        data = data.replace('&lt;', '<')
    if '&amp;' in data:
        data = data.replace('&amp;', '&')
    if 'ns0:' in data:
        data = data.replace('ns0:', 'xi:')
    if ':ns0' in data:
        data = data.replace(':ns0', ':xi')

print(data)
with open('newCM2-5.xml', 'w') as f:
    f.write(data)

