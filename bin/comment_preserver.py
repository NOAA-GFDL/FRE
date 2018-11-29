#!/usr/bin/python

#Condition: If there are 2 or more comments per line, then there MUST be a closing comment instance
#           before a new opening comment instance, however, the last end comment instance CAN span
#           into a multiline comment.
#
#For example, you cannot do this: "<!--<!-- --> -->
#            but you can do this: "<!-- 

#with open('CM2.5-bronx10.xml', 'r') as f:
    #data1 = f.read()

def get_substring(original_string, start):
    
    end = original_string.find("\n")
    substring = original_string[start:end]
    return substring


def print_substrings(original_string, in_comment=True, multiline=False):
    
    first_instance_index = original_string.find("<!--") # Some numeric value
    for i in range(original_string.count("<!--")): #Will not run if this equals 0
        start = original_string.find("<!--", first_instance_index)
    
        if '-->' in original_string[start:]: #If we're here, either single line comment or multiple comments exist on one line
            end = original_string.find("-->", start) + 3
            substring = original_string[start:end]
            print("Line %d: %s | Start: %d | End: %d" % (index + 1, substring, start, end - 1))
            in_comment = False
            first_instance_index = start + 1 #Set next instance of comment in single line, if it exists.
                
        else: #multiline comment; go to next line
            end = original_string.find("\n")
            substring = original_string[start:end]
            print("Line %d: %s | Start: %d | End: %d" % (index + 1, substring, start, end - 1))
            in_comment = True
            multiline = True
            break
    
    
    
    
    
    

with open('CM2.5-bronx10.xml', 'r') as f:
    data2 = f.readlines()
    
in_comment = False
multiline = False

for index, string in enumerate(data2):
    
    #Process comment - check if multiline or single-line
    if ('<!--' in string) and (multiline == False):
        num_comment_beginnings_per_line = string.count("<!--")
        in_comment = True
        first_instance_index = string.find("<!--") # Some numeric value
        #print_substrings(string)
        
        
        for i in range(num_comment_beginnings_per_line):
            start = string.find("<!--", first_instance_index)
            
            if '-->' in string[start:]: #If we're here, either single line comment or multiple comments exist on one line
                end = string.find("-->", start) + 3
                substring = string[start:end]
                print("Line %d: %s | Start: %d | End: %d" % (index + 1, substring, start, end - 1))
                in_comment = False
                first_instance_index = start + 1 #Set next instance of comment in single line, if it exists.
                
            else: #multiline comment; go to next line
                end = string.find("\n")
                substring = string[start:end]
                print("Line %d: %s | Start: %d | End: %d" % (index + 1, substring, start, end - 1))
                in_comment = True
                multiline = True
                break 
        
    else:
        if in_comment and multiline:
        
            if '-->' in string: #Is end of multi-line comment reached?
                start = 0
                end = string.find("-->") + 3
                substring = string[start:end]
                print("Line %d: %s | Start: %d | End: %d" % (index + 1, substring, start, end - 1))
                #in_comment = False
                multiline = False
                
                #Check for other comments on same line after multiline comment ends
                #print_substrings(string)
                
                
                
                first_instance_index = string.find("<!--")
                for i in range(string.count("<!--")): #Will not run if this equals 0
                    start = string.find("<!--", first_instance_index)
                    
                    if '-->' in string[start:]: #If we're here, either single line comment or multiple comments exist on one line
                        end = string.find("-->", start) + 3
                        substring = string[start:end]
                        print("Line %d: %s | Start: %d | End: %d" % (index + 1, substring, start, end - 1))
                        in_comment = False
                        first_instance_index = start + 1 #Set next instance of comment in single line, if it exists.
                
                    else: #multiline comment; go to next line
                        end = string.find("\n")
                        substring = string[start:end]
                        print("Line %d: %s | Start: %d | End: %d" % (index + 1, substring, start, end - 1))
                        in_comment = True
                        multiline = True
                        break 
                 
            else:
                start = 0
                end = string.find("\n")
                substring = string[start:end]
                print("Line %d: %s | Start: %d | End: %d" % (index + 1, substring, start, end - 1))
                
