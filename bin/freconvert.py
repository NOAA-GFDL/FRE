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
obsolete, designated as read-only, and scheduled for unmounting on    |
May 1, 2019. It was replaced by the F2 file system.                   |
                                                                      |
2. It was decided that the MOAB batch scheduler would be discontinued |
and be replaced by the Slurm scheduler on C3 and C4. The transition   |
date for Slurm on C3 took place on April 15, 2019. The transition date|
for Slurm on C4 took place May 13, 2019.                              |
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
Transitioning from Bronx-12, 13, 14 or 15 requires very few XML tag   |
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
import logging
import argparse
import xml.etree.ElementTree as ET

newest_fre_version = 'bronx-18'

configs_to_edit = ['atmos_npes', 'atmos_nthreads', 'ocean_npes',
                   'ocean_nthreads', 'layout', 'io_layout',
                   'ocean_mask_table', 'ice_mask_table', 
                   'land_mask_table', 'atm_mask_table']

nmls_to_edit = ["coupler_nml", "fv_core_nml", "ice_model_nml", 
                "land_model_nml", "ocean_model_nml"]

#---------------------------- XML PRE-PARSING --------------------------------#

def points_to_f2(xml_string):
    """
    Change all file paths in the XML pointing to F1 to point to F2

    Gaea uses environment variables to simplify locations in the file
    system. On F1, these were $CDATA, $CTMP, and $CPERM, which pointed
    to /lustre/f1/pdata, /lustre/f1, and /lustre/f1/unswept,
    respectively. In FRE XML's, users have the option of referencing
    these environment variables when inserting paths to files such as
    input files, diag tables, field tables, data tables, etc. Prior to
    a more recent change in FRE, users could also reference these
    environment variables the same way they could reference FRE-defined
    properties, i.e. with braces -- $(CTMP} instead of $CTMP. On F2, 
    the replacement environment variables are $PDATA, $SCRATCH, and 
    $DEV, pointing to the locations of /lustre/f2/pdata, 
    /lustre/f2/scratch, and /lustre/f2/dev, respectively. 

    This function maps these baseline locations together in two 
    dictionaries, one for the environment variables and one for
    hard-coded paths, and does a string replacement for every F1
    reference found in the original XML. The usage of braces is also
    removed in these string replacements.
    
    PARAMETERS (1)
    --------------
    xml_string (required): Input XML in string format.

    RETURNS
    -------
    A new xml_string variable with F2 references instead of F1

    """
    xml_string = xml_string.replace('$CTMP/unswept', '/lustre/f1/unswept')
    soft_filesystem_pointers = {'$CDATA': '$PDATA/gfdl', 
                                '${CDATA}': '$PDATA/gfdl', 
                                '$CTMP': '$SCRATCH', 
                                '${CTMP}': '$SCRATCH', 
                                '$CPERM': '$DEV', 
                                '${CPERM}': '$DEV'}

    hard_filesystem_pointers = {'/lustre/f1/$USER': '/lustre/f2/scratch/$USER',
                                '/lustre/f1/unswept': '/lustre/f2/dev',
                                '/lustre/f1/pdata': '/lustre/f2/pdata/gfdl'}

    for f1_soft_pointer, f2_soft_pointer in soft_filesystem_pointers.items(): 
        xml_string = xml_string.replace(f1_soft_pointer, f2_soft_pointer)

    for f1_hard_pointer, f2_hard_pointer in hard_filesystem_pointers.items():
        xml_string = xml_string.replace(f1_hard_pointer, f2_hard_pointer)

    #Cover hard-coded F1 swept locations that don't contain '$USER'
    xml_string = xml_string.replace('lustre/f1', 'lustre/f2/scratch')

    return xml_string


def convert_xml_text(xml_string, prev_version='bronx-12'):
    """
    Perform a series of string manipulations before XML is pre-parsed

    This function executes the points_to_f2 function and changes other
    strings in the XML, namely:

        1) ALL references to the old FRE version are changed to the 
           newest version.
        2) The -traceback option is removed for build experiments.
        3) 'DO_ANALYSIS' and 'DO_DATABASE' are updated to
           'ANALYSIS_SWITCH' and 'DB_SWITCH', respectively.
        4) The 'database_ingestor.csh' script is no longer necessary
        5) The 'gfdl_G' group has been changed to 'gfdl_sd'

    PARAMETERS (2)
    --------------
    xml_string (required): input XML in string format
    prev_version (optional): old XML version

    RETURNS
    -------
    A new XML string referencing F2, the new Bronx version, and other
    string manipulations

    """
    xml_string = points_to_f2(xml_string)
    xml_string = xml_string.replace(prev_version, newest_fre_version)
    xml_string = xml_string.replace('-traceback', '')
    xml_string = xml_string.replace('DO_ANALYSIS', 'ANALYSIS_SWITCH')
    xml_string = xml_string.replace('DO_DATABASE', 'DB_SWITCH')
    xml_string = xml_string.replace(' script="$FRE_CURATOR_HOME/share/bin/database_ingestor.csh"', '')
    xml_string = xml_string.replace('gfdl_G', 'gfdl_sd')

    return xml_string


def rreplace(string, old, new, occurrence=1):
    """
    Replace the last instances of a particular character or substring
    found, instead of the first

    This function is called by the write_parsable_xml function and is
    used to remove an extra XML declaration that ElementTree writes.

    PARAMETERS (4)
    --------------
    string (required): input string
    old (required): old substring/character to be removed
    new (required): new substring/character to be replace 'old'
    occurrence (optional): number of occurrences of the old subtring/
                           character to be replaced

    RETURNS
    -------
    A new string with the replaced substring/character.

    """    
    str_list = string.rsplit(old, occurrence)
    return new.join(str_list)


def fix_special_strings(regex_str, xml_string, char_to_replace, replacement):
    """
    Substitutes non-XML conforming characters with conforming
    substrings within specific tags of the XML, notably CDATA tags and
    comments.

    As mentioned in the docstring for the write_parsable_xml function, 
    ElementTree has a difficult time preserving comments and CDATA 
    tags. Therefore, temporary artificial tags are created to store 
    the content of these elements. Unfortunately, this exposes 
    another problem in that non-conforming XML characters, which may
    be perfectly legal in comments or CDATA tags, are now caught by
    the ElementTree parser and deemed illegal. Two notable characters
    that do such a thing in FRE XML's are '<' and '&'. The '&' symbol
    can easily be changed to its equivalent ('&amp;') with a simple 
    replace method, however, the '<' symbol (which is to be changed
    to '&lt;') requires regular expressions capturing only the '<'
    symbols that appear as text within the artificial tags. 
    Therefore, this function identifies all of the substrings within
    the artificial tags and replaces the illegal character with the
    legal equivalent. The function then returns the new XML string.

    PARAMETERS (4)
    --------------
    regex_str (required): Regular expression identifying the necessary
                          substrings that may need a replacement
    xml_string (required): The input XML in string format
    char_to_replace (required): The illegal character to be replaced
    replacement (required): The legal equivalent to replace the 
                            illegal character

    RETURNS
    -------
    The modified XML string with illegal characters removed

    """
    regex_matches = re.findall(regex_str, xml_string, re.DOTALL)
    for match in regex_matches:        
        xml_string = re.sub(re.escape(match), 
                            re.sub(char_to_replace, replacement, match), 
                            xml_string)

    return xml_string


def write_parsable_xml(xml_string):
    """
    Pre-parses the XML into a new string that preserves special tags
    and the content within them

    One of the issues with ElementTree is its lack of functionality
    and preservation when it comes to special tags. The ElementTree
    module may also inadvertently add or duplicate particular tags,
    which may cause anomalous effects down the line. Two elements 
    that caused the biggest of problems were the tags for comments,
    initiated by '<!--' and ended by '-->', and the tags for CDATA 
    strings (normally in FRE within a <csh> block), initiated by
    '<![CDATA[' and ended by ']]>'. Other tags that caused problems
    were DOCTYPE and ENTITY opening and closing tags, the addition
    of <root> and </root> tags at the beginning and ending of the
    XML (potentially also conflicting with the <root> tags defined 
    in the FRE schema), and the duplication of an XML declaration
    statement.

    To combat these issues, it was decided that a slightly modified
    XML was needed to behave properly as an ElementTree object. Thus,
    "pre-parsing" the XML required a manipulation of existing tags
    into temporary artificial tags that more easily preserved content.
    This function performs the following string changes:

    1) '<![CDATA[' ---> <cdata>
    2) ']]>' ---> </cdata>
    3) '<!--' ---> <xml_comment>
    4) '-->' ---> </xml_comment>
    5) '<root>' ---> <xml_root>
    6) '</root>' ---> </xml_root>
    7) '<!DOCTYPE' ---> <doctype>
    8) ']>' ---> </doctype>
    9) '<!ENTITY' ---> <entity>
    10) '>' ---> </entity>

    In addition, this pre-parser calls a function called
    'fix_special_strings' to resolve illegal characters that are not
    normally caught by the ElementTree parser in FRE XML's (they are 
    usually hidden within the comment and CDATA blocks), but which are
    temporarily exposed as text elements of regular XML tags.

    On occasion, the backslash character must also be escaped, as its
    usage may produce unexpected results.

    Finally, the <description> tag is essentially a free-text element
    within a FRE XML that may contain a sequence of characters that
    would normally have to be pre-parsed, but in this case, isn't 
    necessary. The strings '-->', ']>', and ']]>' would normally be 
    temporarily converted via the string translation above, but this
    case is an exception.

    PARAMETERS (1)
    --------------
    xml_string (required): input XML in string format

    RETURNS
    -------
    A new XML string that is ready to be parsed by ElementTree

    """ 
    xml_string = xml_string.replace('\\', 'BACKSLASH')
    xml_string = xml_string.replace('cubicToLatLon', 'xyInterp')  
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
    description_regex = r'<description>(.*?)</description>'

    description_exceptions = {'</xml_comment>': '-->', '</cdata>': ']]&gt;', 
                              '</doctype>': ']>'}

    #Fix pre-parser exceptions that may be present in description text elements
    for initial, replacement in description_exceptions.items():
        xml_string = fix_special_strings(description_regex, xml_string,
                                         initial, replacement)

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
    
    
#------------------------ PARSE XML THROUGH ElementTree -----------------------#


def do_properties(etree_root):
    """
    Retrieves the current FRE version of the XML and checks/modifies 
    specific FRE properties

    This function performs the following tasks:

        1) Get the old XML FRE version value, obtained from the 
           "FRE_VERSION" property. 
        2) If the FRE_VERSION property doesn't exist, the default FRE
           version is kept to 'bronx-10' and returned.
        3) The FRE_VERSION property should be set to 'bronx-##' with 
           '##' indicating the version number. If the property is set
           to 'fre/bronx-##', remove the 'fre/' string.
        4) Looks for the MDBIswitch property and adds it, if needed

    PARAMETERS (1)
    --------------
    etree_root (required): An ElementTree object

    RETURNS
    -------
    A string containing the version of the input XML, i.e. 'bronx-10'

    """
    old_ver = "bronx-10" # Default setting for initialization
    fre_prop_exists = False
    mdbi_switch = False

    #Loop through all of the 'property' elements
    for prop in etree_root.iter('property'):
         
        if prop.get("name").upper() == "FRE_VERSION":

            if 'fre/' in prop.get("value").lower():
                prop.set("value", prop.get("value").lower().replace('fre/', ''))

            old_ver = prop.get("value")
            fre_prop_exists = True
        
        # Check if the MDBI switch property exists. 
        if prop.get("name") == "MDBIswitch" or prop.get("name") == "DB_SWITCH":
            mdbi_switch = True

        else:
            pass

    #If no MDBIswitch property tag exists, add one as a property tag
    if not mdbi_switch:
        db_property = ET.Element('property', attrib={'name': 'MDBIswitch',
                                                     'value': 'off'})
        db_property.tail = '\n  '
        parent = etree_root.find('experimentSuite')

        #setup_include XML's won't have an 'experimentSuite' root
        if parent is None:
            parent = etree_root.find('setup')

        parent.insert(0, db_property)
 
    #If no FRE_VERSION property tag exists, add one as the first property tag
    if not fre_prop_exists:
        fre_version_property = ET.Element('property', attrib={'name': 'FRE_VERSION',
                                                              'value': old_ver})
        fre_version_property.tail = '\n  '
        parent = etree_root.find('experimentSuite')

        if parent is None:
            parent = etree_root.find('setup')

        parent.insert(0, fre_version_property)

    return old_ver


def add_fre_version_tag(etree_root):
    """
    Adds needed <freVersion> tags to platform elements

    This function loops through all of the platforms (i.e. ncrc3.intel,
    gfdl.ncrc4-intel, etc.) and inserts <freVersion> tags wherever
    necessary. It inserts the tag on the line directly below where
    the platform is defined. This function skips over xi:include
    statements, as there is no need to add freVersion elements there.

    PARAMETERS (1)
    --------------
    etree_root (required): An ElementTree object

    RETURNS
    -------
    None

    """
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
                

def do_land_f90(etree_root):
    """
    Removes land <csh> block from build experiments and adds an
    attribute named 'doF90Cpp="yes"' to the land <compile> tag.

    In the past, a semi-lengthy <csh> block was needed to build the 
    land component for build experiments. In later versions of FRE,
    this is no longer necessary. Instead, an attribute was added to 
    the <compile> tag for the land component called 'doF90Cpp'. If
    this was invoked, users could delete these <csh> blocks. This 
    function adds the needed attribute and deletes the <csh>.

    PARAMETERS (1)
    --------------
    etree_root (required): An ElementTree object

    RETURNS
    -------
    None

    """
    for experiment in etree_root.iter('experiment'):

        for component_elem in experiment.iter('component'):
            
            try:
                if 'land' in component_elem.get('name'):
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

                        #Shouldn't get here very often, but if no <csh> exists, exit
                        else:
                            return

                    #Exit if 'doF90Cpp' already exists
                    else:
                        return

            #If not on land component, check next component
                else:
                    continue

            #In the case of no build experiments, but a postProcess section,
            #a 'component' element will be caught, but not the one we wanted,
            #so in this case, just catch the error and pass.
            except TypeError as e:
                pass
    

def delete_default_platforms(etree_root):
    """
    Deletes all platforms with attached name '.default or -default'.

    The usage of 'default' platforms was removed from FRE in Bronx-12,
    therefore, this function facilitates the deletion of such named
    platforms. It works for both regular XML's and 'setup_include'
    XML's (XML's with the 'setup' tag as the root element, which is
    xi:included into the main XML).

    PARAMETERS (1)
    --------------
    etree_root (required): An ElementTree object

    RETURNS 
    -------
    None

    """
    try:
        setup_element = etree_root.find('experimentSuite').find('setup')
    except AttributeError as e:
        setup_element = etree_root.find('setup')

    try:
        platform_list = setup_element.findall('platform')
    except AttributeError as e:

        if setup_element is None:
            logging.info("Setup tag doesn't exist. Skipping...")
            return
        else:
            logging.info("No platforms listed under setup. Skipping...")
            return

    for i in range(len(platform_list)):
        platform_name = platform_list[i].get('name')

        if '.default' in platform_name or '-default' in platform_name:
            logging.info("Deleting platform: %s" % platform_name)
            setup_element.remove(platform_list[i])


def add_compiler_tag(etree_root, compiler_type='intel', 
                     compiler_version='16.0.3.210'):
    """
    Inserts a <compiler> tag within a platform

    Prior to Bronx-11, users would need to specify the compiler used
    for a build experiment within a <csh> block, typically by using
    the 'module swap' command. The need for this <csh> block was 
    removed and replaced with its own defined tag. The default setting
    in this function for the compiler type is 'intel' and is set to a 
    default of '16.0.3.210' for the version. The compiler tag is set 
    for all platforms, including GFDL platforms (which are usually not
    necessary).

    PARAMETERS (3)
    --------------
    etree_root (required): An ElementTree object
    compiler_type (optional): A string specifying the type of compiler
                              used for building the experiment
    compiler_version (optional): A string specifying the version of 
                                 compiler used for building the
                                 experiment.

    RETURNS
    -------
    None

    """
    try:
        platform_list = etree_root.find('experimentSuite').find('setup').findall('platform')
    except AttributeError as e:

        if etree_root.find('setup') is not None:
            platform_list = etree_root.find('setup').findall('platform')
        else:
            return

    for platform in platform_list:
        
        if platform.find('compiler') is None:
            xi_include = ET.iselement(platform.find('{http://www.w3.org/2001/XInclude}include'))

            if xi_include:
                continue
            else:
                logging.info("Writing compiler tag for platform %s" % platform.get("name"))
                compiler_tag = ET.SubElement(platform, 'compiler', 
                                             attrib={'type': compiler_type,
                                                     'version': compiler_version})
                compiler_tag.tail = "\n    "
        else:
            continue
        

def add_sourceGrid_attribute(etree_root):
    """
    Adds a sourceGrid attribute to post-process <component> elements
    that use the 'xyInterp' attribute (or previously, 'cubicToLatLon')

    When the 'cubicToLatLon' attribute was officially retired and 
    substituted with 'xyInterp' in later versions of Bronx, there was
    another attribute that was required to be added to the <component>
    tags before running the post-processing step. This attribute is the
    'sourceGrid' attribute. For re-gridding purposes, if this attribute
    is not specified, failures will occur during a frepp session. The 
    most common values for 'sourceGrid' are 'atmos-cubedsphere' and
    'land-cubedsphere', which, for conversion purposes, can be captured
    through extracting the 'type' attribute of the <component> tag. 
    This function checks to see if a component contains an 'xyInterp' 
    attribute, and if it does, checks again to see if a 'sourceGrid'
    attribute exists. If it doesn't, the function adds one to a
    <component> element based upon the 'type' attribute that SHOULD
    also exist.

    PARAMETERS (1)
    --------------
    etree_root (required): An ElementTree object

    RETURNS
    -------
    None

    """
    for exp in etree_root.iter('experiment'):

        pp_elem = exp.find('postProcess')
        
        if pp_elem is None:
            continue
        else:
            
            for pp_comp in pp_elem.findall('component'):

                if 'xyInterp' in pp_comp.keys() and \
                   'sourceGrid' not in pp_comp.keys():
                    comp_type = pp_comp.get('type') # Set to None if not found

                    if comp_type is not None and comp_type != 'stocks':
                        logging.info("Adding sourceGrid attribute...")

                        if 'atmos' in comp_type:
                            pp_comp.set('sourceGrid', 'atmos-cubedsphere')
                        elif 'land' in comp_type:
                            pp_comp.set('sourceGrid', 'land-cubedsphere')
                    

# --------------------------- BUILD RESOURCE TAGS --------------------------- #
"""
The following section of code builds <resource> tags for the user's XML.
As the transition to <resource> tags was implemented in Bronx-11, these 
code segments will only be relevant for Bronx-10 XML's. 

Prior to Bronx-11, parameters for setting the number of processors,
number of threads, setting the layouts, setting the io_layouts, and
setting mask tables were initialized in the namelist. For example, the 
parameter 'atmos_npes' would set the number of processors for the 
'atmos' component and would itself be set in the 'fv_core_nml' namelist. 
As another example, the 'layout' parameter could be set for the 'atmos',
'ocean', 'ice', or 'land' components, and would be initialized in the 
'coupler_nml', 'ocean_model_nml', 'ice_model_nml' or 'land_model'nml'
namelists, respectively. 

In addition, other parameters that would define the model run would be
set in either <production> or <regression> tags as children of the 
<runtime> element. Such attributes would include 'npes' (total 
processors for experiment run), 'runTime', 'runTimePerJob', 
'simTime', as well as the model run's temporal resolution level,
i.e. months, days, years. 

With Bronx-11, these values are either added or redefined in new 
elements called <resources>. A complete summary and visual of the 
changes can be found here:

https://wiki.gfdl.noaa.gov/index.php/FRE_Version_History#fre.2Fbronx-11

These sets of functions attempt to preserve model run 'resource' 
parameters by extracting them from the namelists and inserting them
into these newly defined <resources> tags (as well as those child
tags) inside both production and regression model runs.

"""


class Namelist(object):
    """
    The Namelist class serves as a container for values extracted
    from namelists that display information regarding the parameters 
    of a model run (either for production or regression). 

    METHODS
    -------
    __init__: Initialize an instance of the class
   
    set_var: Store the namelist parameter in a class-defined dictionary

    print_vars: Used for debugging

    get_var: Retrieve the namelist parameter from the class-defined 
             dictionary.

    """
    def __init__(self):
        """
        Initialize a new Namelist object. Define the container dict.

        PARAMETERS
        ----------
        self

        RETURNS
        -------
        None

        """
        self.nml_vars = {}


    def set_var(self, nml_dict, nml_field, set_layout=False, set_io_layout=False,
                layout_group="", io_layout_group=""):
        """
        Store the namelist parameter into the class dictionary for 
        later retrieval

        Each namelist is parsed as its own dictionary out of the main
        XML string. Those dictionary's contents are then examined and
        stored via this set_var function. The values for more specific
        field are easier to set, such as 'atmos_npes' or 'ocean_npes',
        however, 'layout' and 'io_layout' can be named as a field for 
        any component, i.e. atmos, ocean, model, or land. To prevent
        a duplication of keys within the class dictionary, 4 additional
        parameters are set as keyword arguments:

            set_layout (bool)
            set_io_layout (bool)
            layout_group (str)
            io_layout_group (str)

        The two boolean parameters will execute if the given namelist 
        field equals 'layout' or 'io_layout'. The 'layout_group' and
        'io_layout_group' string parameters specify the component
        to which the given 'layout' or 'io_layout' is referring to
        and then creates a unique 'layout' or 'io_layout' key in the
        class dictionary for the extracted value.

        A few anomalous characters may also exist in the namelist that
        we don't want in the <resources> tags. These include namelist
        comments (defined by a '!') and commas (typically defined at
        the end of a line in the namelist). This method prevents
        the storage of these characters.

        PARAMETERS (7)
        --------------
        self (required within class): Referring to class-defined object
        nml_dict (required): Namelist defined as a dictionary
        nml_field (required): The namelist parameter (key)
        set_layout (optional): A boolean to indicate a line containing
                               the parameter 'layout'
        set_io_layout (optional): A boolean to indicate a line 
                                  containing the parameter 'io_layout'
        layout_group (optional): A string referencing the namelist that
                                 a particular 'layout' is referring to
        io_layout_group (optional): A string referencing the namelist 
                                    that a particular 'io_layout' is 
                                    referring to

        RETURNS
        -------
        None

        """

        try:
            value = nml_dict[nml_field]

        except KeyError as e:
            return 

        #Next 3 'if' statements quality-check the values 
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
        """
        Mainly used for debugging. Prints out the items of the class
        dictionary

        PARAMETERS (1)
        --------------
        self (required within class): Referring to class-defined object

        RETURNS
        -------
        None

        """
        for key, value in self.nml_vars.items():

            print("%s = %s" % (key, value))


    def get_var(self, var):
        """
        Returns the namelist value stored in the class dictionary

        After set_var extracts the value of the field for a particular
        namelist, get_var returns it back. Expected values may not
        always exist, however. In the XML schema for <resource> tags,
        'atmos' and 'ocean' model run parameters are typically
        required. In some cases within Bronx-10 XMLs, these may not
        exist in the namelist. In some cases, they may even be set in
        <csh> blocks! Values of '0' are also not acceptable. To combat
        these problems, arbitrary default values are stored inside
        the class dictionary and returned if a resource-specific 
        field isn't defined or contains a value of '0.'

        PARAMETERS (2)
        --------------
        self (required within class): Referring to class-defined object
        var (required): The namelist field (key) that is referenced
                        when extracting from the class dictionary

        RETURNS
        -------
        self.nml_vars[var]: The class dictionary value of key 'var'

        """        
        #There will be instances where attributes won't exist, so test a 
        #dummy variable in a Try-Except to determine which fields exist/don't exist.
        try:
            foo = self.nml_vars[var]
    
        #Sometimes, there will be namelist keys that will not be displayed in namelist, 
        #but we need it in the resource tags. Set default values to be returned.
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


def nml_to_dict(nml):
    """
    Transform a string containing a namelist into a dictionary

    This function extracts key, value pairs from a list of lines 
    defining an XML namelist and places them into a dictionary to be
    used later.

    PARAMETERS (1)
    --------------
    nml (required): A list of line-separated strings that define an XML namelist

    RETURNS
    -------
    nml_dict: A dictionary representation of the XML namelist

    """
    str_list = get_str_list(nml)
    nml_dict = {}

    for substr in str_list:            
        key = substr[:substr.find('=')]
        value = substr[substr.find('=')+1:]
        nml_dict[key] = value

    return nml_dict


def get_str_list(nml_string):
    """
    Splits a string containing a namelist into a list of 
    line-separating strings. Returns the list.

    PARAMETERS (1)
    --------------
    nml_string (required): String containing the namelist

    RETURNS
    -------
    str_list: A list of line-separated strings defining the namelist

    """
    str_list = nml_string.text.splitlines()
    return str_list


def modify_namelist(nml, nml_name):
    """
    Changes any namelist values that were extracted for resource tags
    to variables references.

    Examples:

        'atmos_npes = 30' --> 'atmos_npes = $atm_ranks'
        'ocean_nthreads = 1' --> 'ocean_nthreads = $ocn_threads'
        (land) 'layout = 1,1' --> (land) 'layout = $lnd_layout'
        (ice) 'io_layout = 1,1' --> (ice) 'io_layout = $ice_io_layout'

    With resource tags, it is no longer necessary to specify the model
    parameters directly within the namelist. They must still be 
    referenced by variables, however, as stated in the examples above.

    PARAMETERS (2)
    --------------
    nml (required): The given namelist string
    nml_name (required): The name of the particular namelist

    RETURNS
    -------
    None

    """
    str_list = get_str_list(nml)
    new_nml_str = get_new_nml_str(nml_name, str_list)
    nml.text = new_nml_str


def nml_text_replace(str_to_check, namelist_dict, namelist_substr, old_nml_str_list,
                     loop_index):
    """
    Helper function for the get_new_nml_str function. Returns a line of
    modified namelist text

    PARAMETERS (5)
    --------------
    str_to_check (required): The string containing the namelist field
                             we are operating on
    namelist_dict (required): Dictionary of parameters tobe modified 
                              for a particular namelist
    namelist_substr (required): The entire line of the namelist 
                                parameter to be modified
    old_nml_str_list (required): A list of the original namelist, 
                                 separated via newline characters
    loop_index (required): Index to keep track of location of 
                           modifications within old_nml_str_list

    RETURNS
    -------
    old_nml_str_list[loop_index]: The new namelist line for a specific
                                  parameter

    """
    for old_str, new_str in namelist_dict.items():

        if str_to_check == old_str:
            old_nml_str_list[loop_index] = re.sub('(?<=\=).*',
                                                  new_str, 
                                                  namelist_substr)
            break

    return old_nml_str_list[loop_index]


def get_new_nml_str(nml_name, old_nml_str_list):
    """
    Operates on a list of line-separated namelist strings and returns
    a single modified namelist string

    This function changes the values of certain parameters within
    particular namelists to reference variables within the <resources>
    tags. It starts by defining key/value pairs for parameters of 
    specific namelist names, where the 'key' is a parameter for that
    particular namelist, and the 'value' is the variable-referenced 
    field value to that parameter. It loops through a list of 
    line-separated strings containing the old namelist parameter values
    and replaces it with the new values. 

    PARAMETERS (2)
    --------------
    nml_name (required): Name of given namelist
    old_nml_str_list (required): A list of the original namelist, 
                                 separated via newline characters

    RETURNS
    -------
    final_str: The modified namelist as a single string.

    """
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


def strip_dict_whitespace(nml_dict):
    """
    Strips all whitespace from the namelist dictionary.

    This function gets rid of any whitespace that was stored as a key
    or value within the namelist dictionary.

    PARAMETERS (1)
    --------------
    nml_dict: A dictionary containing the raw key/value pairs from the 
              original namelist string

    RETURNS 
    -------
    new_dict: A dictionary containing the key/value pairs with the 
              whitespace removed.

    """
    new_dict = {}
    for key, value in nml_dict.items():
    
        new_key = key.replace(' ', '')
        new_value = value.replace(' ', '')
        new_dict[new_key] = new_value

    return new_dict


def do_resources_main(etree_root):
    """
    The central function for modifying the namelists and inserting
    <resources> tags.

    This function can be divided into 2 sections:

        1) Extract from and modify namelist parameters
        2) Create <resources> tags for production and regression 
           elements
    
    For Section 1,

    This function loops through each experiment and identifies the 
    appropriate namelists to modify, that is, namelists that contain
    parameters which can be inserted into <resources> tags. Those 
    namelists are defined in the nmls_to_edit list at the beginning of
    this script. If a namelist that is known to contain resource
    parameters is found, the function will strip the namelist into a
    dictionary and store the necessary values within a Namelist object.
    Regardless of whether or not the parameter exists or not, the 
    object will attempt to call the set_var method. It will not store
    anything if the parameter is not defined. Afterwards, the 
    function modify_namelist is called, which does the work of
    replacing the namelist values with variable references within the 
    <resources> tags. 

    For Section 2,

    Continuing the loop and on the same experiment, this function 
    creates a series of dictionaries containing the values of the 
    modified namelists. The method get_var is called within the
    dictionary to obtain the value stored in the object. If the 
    value does not exist and was stored as '' or None in the object,
    that key/value pair will be deleted from the final dictionary, i.e.
    the dictionary that gets used in the <resources> tags. For 
    production and regression runs, other information is extracted from
    the existing <production> and <regression> tags and renamed, such
    as 'runTime', 'runTimePerJob', or 'npes'. 

    Production runs are fairly easy to set up. Regression runs are a 
    different story. What complicates regression runs is the existence
    of the 'overrideParams' attribute, which, as it says in the name,
    overrides the given namelist parameters that originally defined
    the <resources>. Thus, regression and production <resources> tags
    must be processed separately, leading to this script's usage of 
    separate dictionaries for production and regression resources.
    The parse_overrides function is called when an 'overrideParams'
    attribute is discovered within the original <regression> tags.

    Final side note: the build experiment is skipped when building
    <resources> tags. The build experiments are uniquely identified
    by a <compile> element, which will then cause the loop to go to 
    the next experiment. Not really that necessary...more of a time
    saver than anything.

    PARAMETERS (1)
    --------------
    etree_root (required): An ElementTree object

    RETURNS
    -------
    None
    
    """
    # SECTION 1, STORE AND MODIFY NAMELIST PARAMETERS #

    for exp in etree_root.iter('experiment'):
        subelements = [elem.tag for elem in exp.iter() if elem is not exp]
        logging.info("Inserting resources tags for experiment " + str(exp.get('name')))

        if not 'compile' in subelements: 
            nml_container = Namelist() 

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

                #Empty Namelist elements might contain the value "None" for the 
                #text. Make sure to catch this.
                try:
                    modify_namelist(nml, nml_name)
                except AttributeError as e:
                    pass

            
            # SECTION 2, BUILD THE <resources> TAGS FOR PRODUCTION AND REGRESSION RUNS #

            runtime_element = exp.find('runtime') # Set to None if it doesn't exist
            prod_element = None                   # Initialize production element as None
            reg_element_list = []                 # Initialize regression element as None
            runtime_hours = '10:00:00'            # Default setting
            segment_hours = '10:00:00'            # Default setting

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
            

            if runtime_element is not None:
                prod_element = runtime_element.find('production')
                reg_element_list = runtime_element.findall('regression')

            # ---------------------------------------- PRODUCTION RUNS --------------------------------------------- #

                try:
                    total_npes = prod_element.attrib.pop('npes')
                except (AttributeError, KeyError) as e:
                    pass
        
                try:
                    if 'runTime'.lower() in prod_element.attrib.keys():
                        runtime_hours = prod_element.attrib.pop('runtime')
                    else:
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
                    atm_prod = ET.SubElement(resource_prod_element, 'atm', 
                                             attrib=atm_attribs) if len(atm_attribs) > 0 else None
                    atm_prod.tail = "\n              "
                    ocn_prod = ET.SubElement(resource_prod_element, 'ocn', 
                                             attrib=ocn_attribs) if len(ocn_attribs) > 0 else None
                    ocn_prod.tail = "\n              "
                    lnd_prod = ET.SubElement(resource_prod_element, 'lnd', 
                                             attrib=lnd_attribs) if len(lnd_attribs) > 0 else None

                    if lnd_prod is not None:
                        lnd_prod.tail = "\n              "

                    ice_prod = ET.SubElement(resource_prod_element, 'ice', 
                                             attrib=ice_attribs) if len(ice_attribs) > 0 else None

                    if ice_prod is not None:
                        ice_prod.tail = "\n            "


                # --------------------------------------- REGRESSION RUNS ------------------------------------------ #

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
                                atm_reg = ET.SubElement(resource_reg_element, 'atm', 
                                                        attrib=atm_attribs) if len(atm_attribs) > 0 else None
                                atm_reg.tail = "\n                    "
                                ocn_reg = ET.SubElement(resource_reg_element, 'ocn', 
                                                        attrib=ocn_attribs) if len(ocn_attribs) > 0 else None
                                ocn_reg.tail = "\n                    "
                                lnd_reg = ET.SubElement(resource_reg_element, 'lnd', 
                                                        attrib=lnd_attribs) if len(lnd_attribs) > 0 else None
                                if lnd_reg is not None:
                                    lnd_reg.tail = "\n                    "

                                ice_reg = ET.SubElement(resource_reg_element, 'ice', 
                                                        attrib=ice_attribs) if len(ice_attribs) > 0 else None

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

                                atm_reg_ovr = ET.SubElement(resource_reg_element, 'atm', 
                                                            attrib=atm_overrides) if len(atm_overrides) > 0 else None
                                atm_reg_ovr.tail = "\n                "
                                ocn_reg_ovr = ET.SubElement(resource_reg_element, 'ocn', 
                                                            attrib=ocn_overrides) if len(ocn_overrides) > 0 else None
                                ocn_reg_ovr.tail = "\n                "
                                lnd_reg_ovr = ET.SubElement(resource_reg_element, 'lnd', 
                                                            attrib=lnd_overrides) if len(lnd_overrides) > 0 else None

                                if lnd_reg_ovr is not None:
                                    lnd_reg_ovr.tail = "\n                "

                                ice_reg_ovr = ET.SubElement(resource_reg_element, 'ice', 
                                                            attrib=ice_overrides) if len(ice_overrides) > 0 else None

                                if ice_reg_ovr is not None:
                                    ice_reg_ovr.tail = "\n              "               

                        # No <run> tag inside <regression> = Do nothing!
                        else:
                            pass

            # No <runtime> tag = Do nothing!
            else:
                pass

        # Don't do Build experiments
        else: 
            pass
        

def parse_overrides(override_str, override_container):
    """
    Obtains the string from an 'overrideParams' attribute and stores
    resource parameters/values within a Namelist object

    Override parameters are are sometimes stored within a regression
    experiment and are formatted in the following way:

        name_of_namelist:field=value;

    These series of parameters may or may not contain resource 
    elements. If an override is not to be stored in a <resources> tag,
    whether it is comprised of a different namelist or a different
    field name, it is not changed. If an override is to be stored, the
    value is extracted and the override is removed from the 
    overrideParams attribute. Each override definition is to be 
    terminated with a semicolon (';') symbol. If not, the overrides are
    completely skipped in the regression. The values that are extracted
    are stored in a Namelist object to be called upon later.

    PARAMETERS (2)
    --------------
    override_str (required): The raw string containing the override
                             parameters
    override_container (required): A Namelist object for storing any
                                   override parameters

    RETURNS
    -------
    None

    """
    nml_regex = r';\s*(.*?)\s*:'
    param_regex = r':\s*(.*?)\s*='
    value_regex = r'=\s*(.*?)\s*;'

    foo_override = ';' + override_str
    if override_str[-1] != ';':
       override_str = override_str + ';'

    namelists = re.findall(nml_regex, foo_override)
    params = re.findall(param_regex, override_str)
    values = re.findall(value_regex, override_str)

    #Sanity check - length of namelists, params, and values should be the same
    if not len(namelists) == len(params) == len(values):
        logging.warning("The overrideParams attribute is not set up correctly! \
Skipping regression.")
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
    """
    Returns a modified string that contains valid override parameters

    Newer XML's no longer support an 'overrideParams' attribute that 
    contain 'npes', 'nthreads' or 'layout' in the text. This function
    removes those references.

    PARAMETERS (1)
    --------------
    override_str (required): A string that contains the override
                             parameters

    RETURNS
    -------
    modified_overrides_str: A string that contains the new override
                            parameters

    """
    override_list = override_str.split(';')
    modified_overrides_list = [item for item in override_list if not \
                              ('npes' in item \
                               or 'nthreads' in item \
                               or 'layout' in item)]
    modified_overrides_str = ';'.join(modified_overrides_list)
    modified_overrides_str = modified_overrides_str.replace(' ', '') # Remove whitespace
    return modified_overrides_str


# INSERT / MODIFY <publicMetadata> TAGS

### We will ignore any community tags or attributes in the build experiment
### Primary attributes seen in many bronx-10 XMLs are for database insertion. These
### include the following attributes: "communityProject", "communityModel", "communityModelID",
### "communityExperimentName", "communityExperimentID", "communityForcing" -- <scenario tag>,
### "startTime" -- <scenario tag>, "endTime" -- <scenario tag>, "parentExperimentID" -- <scenario tag>,
### "parentExperimentID" -- <scenario tag>, and "branch_time" -- <scenario tag>
###
### The tags to be replaced are <scenario> and <communityComment>.
### The tags that may need modification are <realization> and <description.

### Key changes:
###              communityProject attribute ---------> project tag
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
#   There are 3 tiers of database entry. 
#       First tier in bronx-10 with the community tags.
#       Second tier is bronx-11 with publicMetadata tags, but outdated tags.
#       Third tier is Bronx-12+ with correct publicMetadata tags in place.


class Metadata(object):
    """
    The Metadata class serves as a container for conversion for old
    Bronx-10 or Bronx-11 metadata tags. A common denominator for nearly
    every old metadata conversion exists, with the exception of 
    'communityVersion' and 'communityGrid', which are converted to an
    arbitrary value of 'not_applicable_1' and 'not_applicable_2',
    respectively. A special list holding the newest tags, named
    __slots__ is used to save on memory, though may be changed to a 
    normal list in the future.

    METHODS
    -------
    __init__: Initialize the Metadata class object with the full list
               of the newest metadata tags

    print_metadata: Prints out the converted metadata. Mainly for debug

    set_metadata: Set the old metadata parameter into a class variable

    get_value_from_tag: Retrieve metadata parameter

    set_comment: Preserves the communityComment attribute

    convert_to_tag: Translates old text/attributes into an Element

    set_tags_from_element: Convert scenario element into separate tags

    delete_attributes: Remove attributes from old metadata elements

    build_metadata: Creates the <publicMetadata> section

    """
    #"not_applicable_1" and "not_applicable_2" refer to "communityVersion" and "communityGrid" respectively
    #They are tagged as N/A, but it's not possible to use a '/' in __slots__

    #NOTE: ORDER IS VERY IMPORTANT HERE!

    __slots__ = ["project", "realization", "source", "source_id", "source_type",
                 "experiment_name", "experiment_id", "comment", "variant_info", 
                 "start_time", "end_time", "parent_experiment_id", 
                 "parent_variant_label", "parent_activity_id", 
                 "parent_time_units", "parent_source_id", 
                 "branch_time_in_parent", "branch_time_in_child", "activity_id",
                 "sub_experiment", "sub_experiment_id", "name1", "name2", 
                 "not_applicable_1", "not_applicable_2"]

    conversion_table_bronx_10 = dict(zip(["communityProject", "realization", 
                                          "communityModel", "communityModelID",
                                          "source_type", "communityExperimentName", 
                                          "communityExperimentID", "comment",
                                          "communityForcing", "startTime", 
                                          "endTime", "parentExperimentID",
                                          "parentExperimentRIP", "parent_activity_id", 
                                          "parent_time_units", "parent_source_id", 
                                          "branch_time", "branch_time_in_child", 
                                          "activity_id", "sub_experiment", 
                                          "sub_experiment_id", "domainName", 
                                          "communityName", "communityVersion", 
                                          "communityGrid"], __slots__))

    conversion_table_bronx_11 = dict(zip(["project", "realization", 
                                          "model", "modelID", 
                                          "source_type", "experimentName",
                                          "experimentID", "comment", 
                                          "forcing", "startTime", 
                                          "endTime", "parentExperimentID", 
                                          "parentExperimentRIP", "parent_activity_id",
                                          "parent_time_units", "parent_source_id", 
                                          "branchTime", "branch_time_in_child",
                                          "activity_id", "sub_experiment", 
                                          "sub_experiment_id", "name1", 
                                          "name2", "not_applicable_1", 
                                          "not_applicable_2"], __slots__))


    def __init__(self):
        """
        Initialize a Metadata object by setting up a class dictionary
        based upon the __slots__ list

        PARAMETERS (1)
        --------------
        self (requried): Refers to a class-defined object

        RETURNS
        -------
        None

        """
        for tag in self.__slots__:

             setattr(self, tag, None)


    def print_metadata(self):
        """
        For debugging purposes. Visualize the class dictionary 
        containing the Metadata class attributes.

        PARAMETERS (1)
        --------------
        self (required): Referes to a class-defined object

        RETURNS
        -------
        None

        """
        print("\t  Tag\t\t\t\t\t Value\n\t________\t\t\t\t________\n")
        for tag in self.__slots__:

            print("\t%-22s\t\t\t%-22s" % (tag, getattr(self, tag)))


    def set_metadata(self, meta_key, meta_value):
        """
        Stores metadata parameter and value into a Metadata object

        PARAMETERS (3)
        --------------
        self (required): Refers to class-defined object
        meta_key (required): Metadata parameter as a string
        meta_value (required): Metadata value as a string

        RETURNS
        -------
        None

        """
        setattr(self, meta_key, meta_value)


    def get_value_from_tag(self, tag):
        """
        Retrive the metadata parameter stored in a Metadata object

        PARAMETERS (2)
        --------------
        self (requried): Refers to class-defined object
        tag (required): A string containing the name of metadata tag

        RETURNS 
        -------
        getattr(self,tag): The stored metadata value for a given tag

        """
        return getattr(self, tag)


    def set_comment(self, communityComment_element):
        """
        Stores the comment text from a communityComment element

        PARAMETERS (2)
        --------------
        self (required): Refers to class-defined object
        communityComment_element: An Element object representative of
                                  a metadata comment

        RETURNS
        -------
        None

        """
        self.set_metadata("comment", communityComment_element.text)


    def convert_to_tag(self, attrib, bronx_version=10):
        """
        Helper function for set_tags_from_element. Returns the new name
        name for an attribute that will eventually be used as a 
        metadata tag, based upon Bronx version of original XML

        PARAMETERS (3)
        --------------
        self (required): Refers to class-defined object
        attrib (required): Name of attribute to be converted to a tag
        bronx_version: Bronx version of original XML. Can either be
        10 or 11.

        RETURNS
        -------
        self.conversion_table_bronx_##[attrib]: Equivalent tag name of 
                                                a given attribute

        """
        if bronx_version == 10:
            return self.conversion_table_bronx_10[attrib]
        else:
            return self.conversion_table_bronx_11[attrib]


    def set_tags_from_element(self, element):
        """
        Calls convert_to_tag and stores new Metadata object information

        PARAMETERS (2)
        ---------------
        self (required): Refers to class-defined object
        element (required): Element object that contains attributes to 
                            be converted a new name (tag)
 
        RETURNS
        -------
        None

        """
        for attrib, value in element.items():

            new_key = self.convert_to_tag(attrib, bronx_version=10)
            self.set_metadata(new_key, value)


    def delete_attributes(self, element):
        """
        Removes attributes from an Element object

        PARAMETERS (2)
        --------------
        self (required): Refers to class-defined object
        element (required): Element object that contains attributes to
                            be deleted from the Element object

        RETURNS
        -------
        None

        """
        for attrib in element.keys():
            element.attrib.pop(attrib)
            

    def build_metadata_xml(self, experiment_element):
        """
        Creates <publicMetadata> tags and children underneath it

        This function takes in an experiment Element object and inserts
        metadata tags directly underneath the 'experiment' tag. It
        calls the get_value_from_tag method to retrieve the stored 
        metadata values from the class attribute table. It loops 
        through every possible metadata parameter, therefore, if it
        doesn't exist (or wasn't stored), no tag is created. The 
        'realization' tag is special, as it was stored as its own
        separate tag prior to Bronx-11. This function thus a new
        'realization' tag underneath 'publicMetadata' and deletes the 
        old 'realization' element.

        PARAMETERS (2)
        --------------
        self (required): Refers to class-defined object
        experiment_element: An Element object that references a FRE XML
                            experiment 

        RETURNS
        -------
        None

        """
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
    """
    The primary function that builds the metadata tags. Creates a new
    Metadata object, stores particular attributes as tags, and then
    deletes unneeded elements.

    The meat and potatoes of metadata transformation from Bronx-10 and
    Bronx-11 XMLs. The tags named 'scenario', 'communityComment', and
    'description' used to contain metadata information that a database
    ingestor .csh script would extract from the XML and put into
    the Curator database. With recent XMLs, all metadata is taken care
    of via <publicMetadata> tags. The 'scenario' and 'description' tags
    in particular contained several attributes of metadata, which are
    reborn as metadata tags in newer XMLs under <publicMetadata>. Thus,
    'scenario' and 'communityComment' elements are deleted. The
    'description' tag is still relevant, but now only contains tags. 
    There are no longer any attributes for 'description' tags.

    This function checks for the existence of 'publicMetadata' tags and
    will perform particular checks depending on if the XML is Bronx-10
    or Bronx-11. Rarely, there will be XMLs containing both Bronx-10
    and Bronx-11 metadata elements. If that happens, the metadata
    section is skipped entirely and a warning is thrown.

    PARAMETERS (1)
    --------------
    etree_root (required): An ElementTree object

    RETURNS
    -------
    None

    """
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

                logging.warning("You have a mix of Bronx-10 and Bronx-11/12 metadata elements")
                logging.warning("Skipping experiment %s" % experiment_name)
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

        else: #Don't do Build Experiments
            pass

    if not executed_metadata:
        logging.info("No metadata to parse. Skipping...")


# ----------------------------- XML POST-PARSING  --------------------------- #

def write_final_xml(xml_string, setup_include=False):
    """
    Parse a modified XML string back into regular form

    Basically the reverse of the write_parsable_xml function. 
    Translates comments and CDATA tags back into their original form.
    Restores native backslash characters.
    Restores '&lt;' back into '<' symbols.
    Restores particular '&gt;' back into '>' symbols.
    Restores DOCTYPE and ENTITY strings.
    Fixes namespace renaming that ElementTree does by default.
    Remove extra <root> tags that ElementTree creates by default.
    Perform other cleanups.

    PARAMETERS (2)
    --------------
    xml_string (required): A string containing the modified XML elements
    setup_include (required): A boolean indicating if XML is a 
                              setup_include XML

    RETURNS
    -------
    xml_string: The final XML string to be written out

    """
    # Parse back the backslashes, '<', and '>' symbols
    xml_string = xml_string.replace('BACKSLASH', '\\')
    xml_string = xml_string.replace('&lt;', '<')
    xml_string = xml_string.replace('&gt;', '>')
 
    # Parse <xml_comment> and </xml_comment> back to <!-- and --> respectively
    xml_string = xml_string.replace('<xml_comment>', '<!--')
    xml_string = xml_string.replace('</xml_comment>', '-->')
 
    # Parse <cdata> and </cdata> back to <![CDATA[ and ]]> respectively.
    xml_string = xml_string.replace('<cdata>', '<![CDATA[')
    xml_string = xml_string.replace('</cdata>', ']]>')

    # Parse <doctype> and </doctype> back to '<!DOCTYPE' and ']>' respectively
    xml_string = xml_string.replace('<doctype>', '<!DOCTYPE')
    xml_string = xml_string.replace('</doctype>', ']>')

    # Parse <entity> and </entity> back to '<!ENTITY' and '>' respectively
    xml_string = xml_string.replace('<entity>', '<!ENTITY')
    xml_string = xml_string.replace('</entity>', '>')

    # Restore any escaped chars from pre-XML parsing
    xml_string = xml_string.replace('&amp;', '&')
    xml_string = xml_string.replace('&gt;', '>')

    # Remove <root> tags (restore first <root> with <?xml_version?> tag
    xml_string = re.sub('<root.*', '<?xml version="1.0"?>', xml_string)
    xml_string = xml_string.replace('</root>', '') 
   
    xml_string = xml_string.replace('<xml_root>', '<root>')
    xml_string = xml_string.replace('</xml_root>', '</root>')

    # Remove instances of 'ns0:'; replace with 'xi:'
    xml_string = xml_string.replace('<ns0:', '<xi:')
    
    # Restore attribute xml:ns for the <experimentSuite> tag or <setup> tag
    if setup_include:
        ns_line = re.search('<setup.*(?=\>)', xml_string).group()
    else:
        ns_line = re.search('<experimentSuite.*(?=\>)', xml_string).group()

    ns_att = ' xmlns:xi="http://www.w3.org/2001/XInclude"'
    xml_string = xml_string.replace(ns_line, ns_line + ns_att)

    # Remove two whitespace characters before closing </publicMetadata> tag
    xml_string = xml_string.replace('      </publicMetadata>',
                                    '    </publicMetadata>')

    # Get rid of extra space between end tag slash.
    xml_string = xml_string.replace(' />', '/>')

    return xml_string 


# ------------------------ END POST-XML PARSING  ----------------------- #

# ---------------------------- MAIN PROGRAM ---------------------------- #

if __name__ == '__main__':

    # GET THE COMMAND LINE ARGUMENTS AND READ IN THE INPUT XML #
    # OPTION -x IS REQUIRED FOR ALL INPUT XMLs                 #
    # OPTION -s IS REQUIRED IF THE XML IS A SETUP_INCLUDE XML  #
    parser = argparse.ArgumentParser(prog='freconvert', 
                                     description="A Python script that converts \
                                                  a user's XML to the latest \
                                                  FRE version (bronx-15)")
    parser.add_argument('-x', '--input_xml', required=True, type=str, 
                        help='Path of XML to be converted.')
    parser.add_argument('-o', '--output_xml', type=str, 
                        help='Destination path of converted XML')
    parser.add_argument('-s', '--setup', action='store_true', 
                        help='Specifies a setup_include XML')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Increase output verbosity.')
    parser.add_argument('-q', '--quiet', action='store_true', 
                        help='Very little verbosity')
 
    args = parser.parse_args()
    if args.verbose:
        logging.basicConfig(level=logging.INFO)
    elif args.quiet:
        logging.basicConfig(level=logging.ERROR)

    if not os.path.exists(args.input_xml):
        logging.error("The file path for the input XML does not exist")
        sys.exit(1) 
    elif not args.input_xml.endswith('.xml'):
        logging.error("Not a valid XML file (Bad extension)")
        sys.exit(1)

    input_xml = args.input_xml
    file_dest = args.output_xml

    if file_dest is None:
        modified_input_path = os.path.abspath(input_xml).replace('.xml', '')
        file_dest = modified_input_path + '_' + newest_fre_version + '.xml'
    else:
        pass
    
    with open(input_xml, 'r') as f:
        input_content = f.read()

    logging.info("XML is being pre-parsed...")
    pre_parsed_xml = write_parsable_xml(input_content)
    
    try:
        tree = ET.ElementTree(ET.fromstring(pre_parsed_xml))
    except ET.ParseError as e:
        logging.exception("The XML is non-conforming! Please correct \
issues and re-run freconvert.py")
        print("Writing out the pre-parsed file for debugging.")
        file_dest = file_dest.replace(newest_fre_version + '.xml', 'pre_parsed_error.xml')

        with open(file_dest, 'w') as f:
            f.write(pre_parsed_xml)
        print("Path to Pre-Parsed XML: %s" % file_dest)

        sys.exit(1)
    
    root = tree.getroot()
    
    old_version = do_properties(root)
    print("Converting XML from %s to %s..." % (old_version, newest_fre_version))
    time.sleep(1)

    if old_version == 'bronx-10':
        logging.info("Checking for land F90 <csh> block...")
        do_land_f90(root)

        logging.info("Checking for 'default' platforms (will be removed)...")
        delete_default_platforms(root)

        logging.info("Adding <freVersion> tags...")
        add_fre_version_tag(root)

        logging.info("Checking for existence of 'compiler' tag in platforms")
        add_compiler_tag(root)

        logging.info("Checking for sourceGrid attributes...")
        add_sourceGrid_attribute(root)

        logging.info("Adding resources tags...")
        do_resources_main(root)

        logging.info("Checking for metadata...")
        do_metadata_main(root)

        xml_string = ET.tostring(root)
        xml_string = convert_xml_text(xml_string, prev_version=old_version)
        final_xml = write_final_xml(xml_string, args.setup)

    elif old_version == 'bronx-11':
        logging.info("Checking for 'default' platforms (will be removed)...")
        delete_default_platforms(root)

        logging.info("Checking for metadata. Updating tags if necessary...")
        do_metadata_main(root)

        xml_string = ET.tostring(root)
        xml_string = convert_xml_text(xml_string, prev_version=old_version)
        final_xml = write_final_xml(xml_string, args.setup)

    # Just do string replacements if input XML is Bronx-12, 13, or 14.
    elif old_version == 'bronx-12':
        logging.info("Linking paths to F2. Performing final XML manipulations...")
        final_xml = convert_xml_text(input_content, prev_version=old_version)
    
    elif old_version == 'bronx-13' or old_version == 'bronx-14' or old_version == 'bronx-15' or old_version == 'bronx-16' or old_version == 'bronx-17':
        logging.info("Making Slurm compatible/Updating XML...")
        final_xml = convert_xml_text(input_content, prev_version=old_version)
    
    elif old_version == newest_fre_version:
        logging.warning("XML is already at the newest version (%s)" % newest_fre_version)
        sys.exit(1)

    else:
        logging.error("This version of FRE (%s) isn't supported for conversion!" % old_version)
        sys.exit(1)
   
    logging.info("Writing new XML...")

    with open(file_dest, 'w') as f:
        f.write(final_xml)

    print("Converted XML written to %s" % (os.path.abspath(file_dest)))

