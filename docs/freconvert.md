# FRE XML Conversion Tool - Summary and Usage

## Why Use this tool?

The purpose of this Python script is to facilitate the transition of 
FRE XML documents into the latest version of Bronx. Two events        
preceded the need for this tool.                                      
                                                                      
1. On March 12, 2019, Gaea's F1 file system was officially rendered   
obsolete, designated as read-only, and scheduled for removal in       
April, 2019. It was replaced by the F2 file system.                   
                                                                      
2. It was decided that the MOAB batch scheduler would be discontinued 
and be replaced by the Slurm scheduler. That transition is expected to
be completed by May, 2019.                                            
                                                                      
Many components of FRE had explicitly referenced F1 file locations or 
the MOAB scheduler, prompting the decision to push a new FRE upgrade  
that instead referenced F2 and Slurm. In doing this, the decision was 
also made to end support for all FRE versions that referenced F1 and  
(soon) MOAB. Thus, as of March 12, 2019, Bronx-10, Bronx-11,          
and Bronx-12 are no longer supported. This converter script was       
created to ease the pain of converting XML's to a version that        
supports F2 and Slurm, particularly harder conversions such as from   
Bronx-10.                                                             

## How does this tool work?

The core functionality of this script is parsing the original input   
XML, modifying its elements, and writing out the newly converted file.
Transitioning from Bronx-12, Bronx-13, or Bronx-14 requires very few
XML tag manipulations and is done via simple string substitution. On the other
hand, Bronx-10 and Bronx-11 XML's require more extensive work. Thus,  
the built-in Python module, ElementTree, is used to carry out major   
XML tag changes, additions, or subtractions. ElementTree, however,    
comes with several drawbacks, namely:                                 
                                                                      
    1) ElementTree doesn't preserve comments from the input XML       
    2) FRE XML's may contain non-conforming characters within <csh>   
       blocks, which are preserved in special CDATA tags and tend to  
       break ElementTree.                                             
    3) XML declarations are not consistently preserved.               
    4) XML namespaces are not easily preserved                        
    5) The order of tag attributes are not preserved.                 
    6) Many other anomalies occur when trying to correct 1-5,         
       particularly during the preservation of comment and CDATA tags.
                                                                      
To overcome the drawbacks, this script implements a 4-step approach   
towards writing out a converted XML.                                  
                                                                      
    1) Pre-parse the original XML into a slightly customized string   
       that ElementTree can understand, without running into errors,  
       i.e. an ElementTree object.                                    
    2) Modify the existing XML tags and attributes and adding or      
       removing tags where necessary.                                 
    3) Post-parse the modified ElementTree object back into an XML    
       conforming string.                                             
    4. Write out the modified XML string into a new file.             
                                                                      
Non-conforming input XML's will cause the script to throw an error    
and write out the pre-parsed XML to a new file, which may be used     
for identifying the cause of the non-conformance.                     

## How to use this tool

This script can be run using Python 2.7 or Python 3 and is designed to
be invoked on the command line interface. The user must specify a minimum
of one argument (or 2 circumstantially), as noted below:

### ARGUMENTS

-x    --input_xml    (required)

-s    --setup        (required if using a setup_include XML)

-o    --output_xml   (optional)

-v    --verbose      (optional)

-q    --quiet        (optional)

### EXAMPLES

Example 1: Bronx-10 XML (no verbosity)

Input XML: /ncrc/home1/Kristopher.Rand/input_b10.xml
```
> freconvert.py -x input_b10.xml
Converting XML from bronx-10 to bronx-15... 
Converted XML written to /ncrc/home1/Kristopher.Rand/input_b10_bronx-15.xml
```

Example 2: Bronx-10 XML (with verbosity)

Input XML: /ncrc/home1/Kristopher.Rand/input_b10.xml
```
> freconvert.py -x input_b10.xml -v -o output_bronx15.xml
INFO:root:XML is being pre-parsed...
Converting XML from bronx-10 to bronx-15...
INFO:root:Checking for land F90 <csh> block...
INFO:root:Checking for 'default' platforms (will be removed)...
INFO:root:Adding <freVersion> tags...
INFO:root:Checking for existence of 'compiler' tag in platforms
INFO:root:Checking for sourceGrid attributes...
INFO:root:Adding resources tags...
INFO:root:Checking for metadata...
INFO:root:Writing new XML...
Converted XML written to /ncrc/home1/Kristopher.Rand/output_bronx15.xml
```

Example 3: setup_include XML's

Input XML: /ncrc/home1/Kristopher.Rand/setup_include.xml
```
> freconvert.py -x setup_include.xml -s -o setup_include_testbronx15.xml --verbose
INFO:root:XML is being pre-parsed...
Converting XML from bronx-10 to bronx-15...
INFO:root:Checking for land F90 <csh> block...
INFO:root:Checking for 'default' platforms (will be removed)...
INFO:root:Deleting platform: gfdl.ncrc3-default
INFO:root:Deleting platform: gfdl-ws.default
INFO:root:Deleting platform: theia.default
INFO:root:Adding <freVersion> tags...
INFO:root:Checking for existence of 'compiler' tag in platforms
INFO:root:Writing compiler tag for platform gfdl-ws.intel
INFO:root:Checking for sourceGrid attributes...
INFO:root:Adding resources tags...
INFO:root:Checking for metadata...
INFO:root:No metadata to parse. Skipping...
INFO:root:Writing new XML...
Converted XML written to /ncrc/home1/Kristopher.Rand/setup_include_testbronx15.xml
```

Example 4: Bronx-12 conversion

Input XML: /home/$USER/test/mybronx12.xml
```
> freconvert.py -x /home/$USER/test/mybronx12.xml -o ../testb15.xml -v
INFO:root:XML is being pre-parsed...
Converting XML from bronx-12 to bronx-15
INFO:root:Linking paths to F2. Performing final XML manipulations...
INFO:root:Writing new XML...
Converted XML written to /home/Kristopher.Rand/testb15.xml
```

## Notable Caveats

There are several issues to be aware of when using this tool. In general, it is
highly recommended that the input XML is conforming to its version of FRE, i.e.
passes without failures from the XML validator and when frerun is invoked. One
can run the validator by calling `frelist -C` on your input XML. It is recommended
to run `frelist -C` and then `frerun` on the converted XML as well, to not only
scan for validation failures, but to also check the existence of file path locations.
In general, the user is to be aware of the following:

- By not invoking the '-o' argument, freconvert.py will store the path of the 
converted XML in the directory of the original XML and will be named the same as
the original XML, except with a '_bronx-15' before the .xml extension.
Ex. /home/$USER/foo.xml --> /home/$USER/foo_bronx-15.xml
- If you use the '-o' argument, be careful not to rename your converted XML the
same as your original XML. The script will overwrite the original copy!
- Converting a setup_include XML without the '-s' may cause the script to fail
- Many XML's contain `<csh>` blocks that may reference characters that the script
might interpret as escape characters. This may lead to unexpected results within
the converted `<csh>` block, or worse, may even cause the script to fail during 
the pre-parsing step.
- XML's that are non-conforming may fail during the pre-parsing step and produce
a series of errors, such as this:
```
INFO:root:XML is being pre-parsed...
ERROR:root:The XML is non-conforming! Please correct issues and re-run freconvert.py
Traceback (most recent call last):
  File "/ncrc/home2/fms/local/opt/fre-commands/test/bin/freconvert.py", line 2188, in <module>
    tree = ET.ElementTree(ET.fromstring(pre_parsed_xml))
  File "/usr/lib64/python2.7/xml/etree/ElementTree.py", line 1311, in XML
    parser.feed(text)
  File "/usr/lib64/python2.7/xml/etree/ElementTree.py", line 1653, in feed
    self._raiseerror(v)
  File "/usr/lib64/python2.7/xml/etree/ElementTree.py", line 1517, in _raiseerror
    raise err
ParseError: not well-formed (invalid token): line 573, column 57
Writing out the pre-parsed file for debugging.
Path to Pre-Parsed XML: /home/$USER/myinputxml_pre_parsed_error.xml
```
- `<csh>` blocks may also cause discrepancies in the <resource> tags. The functionality
of this script is to extract `<resources>` tag values from that experiment's namelist
parameters and not from any other source. As it is always a good idea to check 
the converted elements, it is highly recommended to do a check if there are <csh>
blocks that were supposed to define computing resources in the past.
- Mixing Bronx-10 and Bronx-11 metadata elements within the original XML will cause
the script to throw a warning and skip the metadata conversion for that experiment.
Thus, it is required that Bronx-11 XML's do not contain a combination of `<scenario>`
tags and `<publicMetadata>` tags. 
- This script does not do well with inheritance. If an experiment is inherited from
another experiment within the XML and resource parameters aren't specified, a very
limited 'default' list of `<resources>` tags will be created. Again, make sure to check
the resources after conversion.
- `<resources>` tags set up a 'site' attribute of 'ncrc3' by default. To use C4, these
site references will need to be manually edited.
- File locations will point to F2, but not necessarily indicate a path that truly
exists, as only the base path is changed. i.e. /lustre/f1/unswept/$USER/... -->
/lustre/f2/dev/$USER/... Use `frerun` after conversion to scan for the existence
of file path locations.

## Additional Resources

This tool contains thorough documentation regarding each function that facilitates
the conversion, which can be viewed by opening the source code in a text editor.

Please send inquiries regarding XML conversion through the GFDL Help Desk