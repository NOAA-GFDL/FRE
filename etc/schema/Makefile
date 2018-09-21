# The schemaDocumentation.sh is part of the Oxygen XML Editor
# (https://www.oxygenxml.com/). 
SCHEMA_DOC=schemaDocumentation.sh

SRC_XSD = fre.xsd curator.xsd postprocessing.xsd xi.xsd xml.xsd

pdf: fre-schema-documentation.pdf
html: html/index.html

fre-schema-documentation.pdf: $(SRC_XSD)
	$(SCHEMA_DOC) $< -out:$@ -format:pdf -split:location
	$(RM) -r img

html/index.html: $(SRC_XSD)
	$(SCHEMA_DOC) $< -out:$@ -format:html -split:location

clean:
	$(RM) -r html
	$(RM) fre-schema-documentation.pdf
	$(RM) -r img
