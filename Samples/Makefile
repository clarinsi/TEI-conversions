test:
	$j ../Schema/tei_clarin.rng test-ssj500k.xml
	$s -xsl:../Scripts/check-links.xsl test-ssj500k.xml

conll2tei:
	$s -xsl:../Scripts/tei2conllu.xsl test-ssj500k.xml > test-ssj500k.conllu
	python3 ../Scripts/tools/validate.py --lang sl --level 1 test-ssj500k.conllu
	python3 ../Scripts/tools/validate.py --lang sl --level 2 test-ssj500k.conllu
	python3 ../Scripts/tools/validate.py --lang sl --level 3 test-ssj500k.conllu

all:	classla classla2tei validate

validate:
	$j ../Schema/tei_clarin.rng test-plain.xml
	$s -xsl:../Scripts/check-links.xsl test-plain.xml

# Convert CoNLL-U to XML
classla2tei:
	../Scripts/conllu2tei.pl < test-plain.conllu > test-plain.xml
	$s -xsl:../Scripts/copy.xsl test-plain.xml > test-plain.indent.xml

# Annotate plain text file
classla:
	python3 ../Scripts/anno.py < test-plain.txt > test-plain.conllu
	python3 ../Scripts/tools/validate.py --lang sl --level 1 test-plain.conllu
	python3 ../Scripts/tools/validate.py --lang sl --level 2 test-plain.conllu
	python3 ../Scripts/tools/validate.py --lang sl --level 3 test-plain.conllu

################################################
s = java -jar /usr/share/java/saxon.jar
j = java -jar /usr/share/java/jing.jar
P = parallel --gnu --halt 2
