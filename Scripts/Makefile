newsfeed:
	$j ../Schema/tei_clarin.rng ../Samples/test-newsfeed.xml
	$s -xsl:check-links.xsl ../Samples/test-newsfeed.xml
	$s -xsl:newsfeed2vert.xsl ../Samples/test-newsfeed.xml > ../Samples/test-newsfeed.vert.xml
	xml2vert.pl < ../Samples/test-newsfeed.vert.xml > ../Samples/test-newsfeed.vert

all:	plain ssj500k
ssj500k:
	$j ../Schema/tei_clarin.rng ../Samples/test-ssj500k.xml
	$s -xsl:check-links.xsl ../Samples/test-ssj500k.xml
	python3 tools/validate.py --lang sl --level 1 ../Samples/test-ssj500k.conllu
	python3 tools/validate.py --lang sl --level 2 ../Samples/test-ssj500k.conllu
	python3 tools/validate.py --lang sl --level 3 ../Samples/test-ssj500k.conllu

plain:
	$j ../Schema/tei_clarin.rng ../Samples/test-plain.xml
	$s -xsl:check-links.xsl ../Samples/test-plain.xml
	python3 tools/validate.py --lang sl --level 1 ../Samples/test-plain.conllu
	python3 tools/validate.py --lang sl --level 2 ../Samples/test-plain.conllu
	python3 tools/validate.py --lang sl --level 3 ../Samples/test-plain.conllu


################################################
s = java -jar /usr/share/java/saxon.jar
j = java -jar /usr/share/java/jing.jar
P = parallel --gnu --halt 2
