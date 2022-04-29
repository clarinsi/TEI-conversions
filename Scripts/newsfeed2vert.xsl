<?xml version="1.0"?>
<!-- Transform one teiCorpus or TEI to CQP vertical format.
     This version made for newsfeed corpus, but could become more or less generic
     Note that the output is still in XML, and needs another polish. 

     If the teiCorpus is stored as 1 file for corpus root and separate TEI-rooted files
     than the TEI files can be processed separately, and the 'hdr' parameter should give 
     the corpus root file.
-->

<xsl:stylesheet 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns="http://www.tei-c.org/ns/1.0"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:fn="http://www.w3.org/2005/xpath-functions" 
    xmlns:et="http://nl.ijs.si/et"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xi="http://www.w3.org/2001/XInclude"
    exclude-result-prefixes="fn et tei xs xi"
    version="2.0">

  <!-- Indent is "no" and each tag explicitly followed by new line -->
  <xsl:output method="xml" encoding="utf-8" indent="no" omit-xml-declaration="yes"/>
  
  <!-- If not present in source XML, we need the file with corpus
       teiHeader for information about common meta-data, in particular 
       taxonomies for UD and MTE, prefix definitions, etc.
  -->
  <xsl:param name="hdr"/>

  <!-- Separator between UD morpho features (esp. relevant if they are multi-valued -->
  <xsl:param name="multiValueSeparator">&#32;</xsl:param>
  
  <xsl:key name="id" match="tei:*" use="@xml:id"/>

  <!-- Variable with corpus metadata -->
  <xsl:variable name="corpusHeader">
    <xsl:choose>
      <xsl:when test="normalize-space($hdr) and doc-available($hdr)">
	<xsl:copy-of select="document($hdr)//tei:teiHeader[1]"/>
      </xsl:when>
      <xsl:when test="/tei:teiCorpus/tei:teiHeader">
	<xsl:copy-of select="/tei:teiCorpus/tei:teiHeader"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:message terminate="yes"
		     select="concat('TEI header file ', $hdr, ' not found!')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- Kill all attributes and text, will output only selected ones -->
  <xsl:template match="@*"/>
  <xsl:template match="text()"/>

  <!-- One text -->
  <xsl:template match="tei:TEI">
    <xsl:variable name="id" select="@xml:id"/>
    <!-- All other metadata is in the source description -->
    <xsl:variable name="source" select="tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:bibl"/>
    <xsl:variable name="title" select="$source/tei:title"/>
    <xsl:variable name="author" select="$source/tei:author"/>
    <xsl:variable name="date" select="$source/tei:date"/>
    <xsl:variable name="time" select="$source/tei:time"/>
    <xsl:variable name="publisher" select="$source/tei:publisher"/>
    <xsl:variable name="url" select="$source/tei:ptr/@target"/>
    
    <text id="{$id}" title="{$title}" author="{$author}" publisher="{$publisher}" url="{$url}"
	  date="{$date}" time="{$time}">
      <xsl:text>&#10;</xsl:text>
      <xsl:apply-templates select="tei:text/tei:body/tei:p"/>
    </text>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <!-- One paragraph or sentence -->
  <xsl:template match="tei:body//tei:p | tei:s">
    <xsl:copy>
      <xsl:attribute name="id" select="@xml:id"/>
      <xsl:text>&#10;</xsl:text>
      <xsl:apply-templates/>
    </xsl:copy>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <!-- One name -->
  <xsl:template match="tei:name">
    <xsl:copy>
      <xsl:attribute name="type" select="@type"/>
      <xsl:text>&#10;</xsl:text>
      <xsl:apply-templates/>
    </xsl:copy>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <!-- One name, the Simon way -->
  <xsl:template match="tei:seg[@type='name']">
    <name>
      <xsl:attribute name="type" select="@subtype"/>
      <xsl:text>&#10;</xsl:text>
      <xsl:apply-templates/>
    </name>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <!-- One token -->
  <xsl:template match="tei:pc | tei:w">
    <!-- Output the token and its basic annotations -->
    <xsl:value-of select="concat(.,'&#9;',
			  et:output-annotations(.))"/>
    <!-- Output the syntatic dependency, incl. the basic annotations of the head -->
    <xsl:call-template name="deps"/>
    <xsl:text>&#10;</xsl:text>
    <!-- Glue next token? -->
    <xsl:if test="@join = 'right' or @join='both' or
		  following::tei:*[self::tei:w or self::tei:pc][1]/@join = 'left' or
		  following::tei:*[self::tei:w or self::tei:pc][1]/@join = 'both'">
      <g/>
      <xsl:text>&#10;</xsl:text>
    </xsl:if>
  </xsl:template>

  <!-- FUNCTIONS -->

  <!-- Basic annotations of the token:
       lemma, msd, UD PoS, UD morpho features, token number 
  -->
  <xsl:function name="et:output-annotations">
    <xsl:param name="token"/>
    <!-- The number of the token in the sentence, assumes it is the last part of the ID, after . -->
    <xsl:variable name="n" select="replace($token/@xml:id, '.+\.t?(\d+)$', 'tok$1')"/>
    <xsl:variable name="lemma">
      <xsl:choose>
	<xsl:when test="$token/@lemma">
	  <xsl:value-of select="$token/@lemma"/>
	</xsl:when>
	<xsl:otherwise>
	  <!-- For punctuation we take the first char as its lemma -->
	  <xsl:value-of select="substring($token,1,1)"/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <!-- This is sloppy, as we just assume @ana holds msd, and that it has the prefix msd! -->
    <xsl:variable name="msd" select="replace($token/@ana, '.+?:', '')"/>
    
    <!-- UD PoS: in TEI it is packed as a morphological feature 'UPosTag' -->
    <xsl:variable name="ud-pos" select="replace(replace($token/@msd, 'UPosTag=', ''), '\|.+', '')"/>
    
    <!-- UD morpho features: all except UPosTag 
         They are assumed to be multi-valued -->
    <xsl:variable name="ud-feats">
      <xsl:variable name="fs" select="replace($token/@msd, 'UPosTag=[^|]+\|?', '')"/>
      <xsl:choose>
	<xsl:when test="normalize-space($fs)">
	  <!-- Change UD pipe separator to whatever is specified -->
	  <xsl:value-of select="replace($fs, '\|', $multiValueSeparator)"/>
	</xsl:when>
	<xsl:otherwise>
	  <!-- We put underscore as the empty feature -->
	  <xsl:text>_</xsl:text>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <!-- Return lemma, msd, UD PoS, UD morpho features, token number -->
    <xsl:sequence select="concat($lemma, '&#9;', $msd, '&#9;', 
			  $ud-pos, '&#9;', $ud-feats, '&#9;', $n)"/>
  </xsl:function>

  <!-- Output syntactic dependency of the token in a sentence 
       It is assumed that this template is called with the token (w | pc) context node -->
  <xsl:template name="deps">
    <!-- What is the type of syntactic annotation? 
	 Its labels should be specificed in the corresponding taxonomy.
         Standard ones are UD-SYN and JOS-SYN -->
    <xsl:param name="type">UD-SYN</xsl:param>
    <!-- ID of the token -->
    <xsl:variable name="id" select="@xml:id"/>
    <!-- The complete sentence node, assumed to contain the syntactic ling group -->
    <xsl:variable name="s" select="ancestor::tei:s"/>
    <xsl:choose>
      <!-- Do we have the syntactic parse -->
      <xsl:when test="$s/tei:linkGrp[@type=$type]">
	<!-- The link with the token as the argument -->
	<xsl:variable name="link"
		      select="$s/tei:linkGrp[@type=$type]/tei:link
			      [ends-with(@target, concat(' #',$id))]"/>
	<xsl:if test="not(normalize-space($link/@ana))">
	  <xsl:message>
	    <xsl:text>ERROR: no syntactic link for token </xsl:text>
	    <xsl:value-of select="concat(ancestor::tei:TEI/@xml:id, ':', @xml:id)"/>
	  </xsl:message>
	</xsl:if>
	<!-- The official name of the syntactic relation: taken to be as the first term in the 
	     relation category of the syntactic relation taxonomy -->
	<xsl:variable name="syntacticTerm">
	  <xsl:variable name="id" select="et:ref2id($link/@ana, $corpusHeader)"/>
	  <xsl:value-of select="key('id', $id)//tei:term
				[ancestor-or-self::tei:*[@xml:lang][1]/@xml:lang = 'en']
				"/>
	</xsl:variable>
	<xsl:value-of select="concat('&#9;', $syntacticTerm)"/>
	
	<!-- The head node of the relation -->
	<xsl:variable name="target" select="key('id', replace($link/@target,'#(.+?) #.*','$1'))"/>
	<xsl:choose>
	  <!-- If it is the Root, output hyphyens -->
	  <xsl:when test="$target/self::tei:s">
	    <!-- This is fragile, if we change the number of positional attributes! -->
	    <xsl:text>&#9;-&#9;-&#9;-&#9;-&#9;-&#9;-</xsl:text>
	  </xsl:when>
	  <xsl:otherwise>
	    <xsl:value-of select="concat('&#9;', et:output-annotations($target))"/>
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:when>
      <xsl:otherwise>
	<xsl:message>
	  <xsl:text>ERROR: no linkGroup for sentence </xsl:text>
	  <xsl:value-of select="ancestor::tei:s/@xml:id"/>
	</xsl:message>
	<!-- This is fragile, if we change the number of positional attributes! -->
	<!--xsl:text>&#9;-&#9;-&#9;-&#9;-&#9;-&#9;-</xsl:text-->
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

<!-- Resolve a pointer (IDREF or TEI extended pointer) to an ID 
     Not that it has to resolve localy, oterwise throws an error -->
  <xsl:function name="et:ref2id">
    <xsl:param name="ptr"/>
    <xsl:param name="listPrefix"/>
    <xsl:choose>
      <!-- Extended TEI pointer -->
      <xsl:when test="contains($ptr, ':')">
	<xsl:variable name="prefix" select="substring-before($ptr, ':')"/>
	<xsl:variable name="prefixDef" select="$listPrefix//tei:prefixDef[@ident=$prefix]"/>
	<xsl:variable name="id" select="substring-after($ptr, ':')"/>
	<xsl:choose>
	  <xsl:when test="$prefixDef">
	    <xsl:variable name="xml-ptr"
			  select="replace($id, 
				  $prefixDef/@matchPattern, 
				  $prefixDef/@replacementPattern)"/>
	    <!-- We could even have several! -->
	    <xsl:value-of select="et:ref2id($xml-ptr, $listPrefix)"/>
	  </xsl:when>
	  <xsl:otherwise>
	    <xsl:message select="concat('Extended pointer ', $ptr, 
				 ' but no prefixDef for prefix ', $prefix, ' found!')"/>
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:when>
      <!-- Local pointer -->
      <xsl:when test="matches($ptr, '^#.+')">
	<xsl:value-of select="substring-after($ptr, '#')"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:message select="concat('Strange pointer ', $ptr)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

</xsl:stylesheet>
