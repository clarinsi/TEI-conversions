all:	classla conll2tei validate

validate:
	$j ../Schema/tei_clarin.rng test-plain.xml
	$s -xsl:../Scripts/check-links.xsl test-plain.xml

# Convert CoNLL-U to XML
conll2tei:
	../Scripts/conllu2tei.pl < test-plain.conllu > test-plain.xml
	$s -xsl:../Scripts/copy.xsl test-plain.xml > test-plain.indent.xml

# Annotate plain text file
classla:
	python3 ../Scripts/anno.py < test-plain.txt > test-plain.conllu

################################################
s = java -jar /usr/share/java/saxon.jar
j = java -jar /usr/share/java/jing.jar
P = parallel --gnu --halt 2
