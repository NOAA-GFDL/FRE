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
```
> freconvert.py -x input_b10.xml
```





