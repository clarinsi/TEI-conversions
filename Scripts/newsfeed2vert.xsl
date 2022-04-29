<?xml version="1.0"?>
<!-- Transform one TEI to CQP vertical format.
     Note that the output is still in XML, and needs another polish. -->
<!-- Needs the file with corpus teiHeader as a parameter -->
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

  <xsl:output method="xml" encoding="utf-8" indent="no" omit-xml-declaration="yes"/>
  
  <!-- File with corpus teiHeader for information about taxonomies, persons, parties -->
  <xsl:param name="hdr"/>

  <xsl:key name="id" match="tei:*" use="@xml:id"/>

  <xsl:variable name="corpusHeader">
    <xsl:choose>
      <xsl:when test="normalize-space($hdr) and doc-available($hdr)">
	<xsl:copy-of select="document($hdr)/tei:teiHeader"/>
      </xsl:when>
      <xsl:when test="/tei:teiCorpus/tei:teiHeader">
	<xsl:copy-of select="/tei:teiCorpus/tei:teiHeader"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:message terminate="yes">
	  <xsl:text>TEI header file </xsl:text>
	  <xsl:value-of select="$hdr"/>
	  <xsl:text> not found!</xsl:text>
	</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  
  <xsl:template match="@*"/>
  <xsl:template match="text()"/>

  <xsl:template match="tei:TEI">
    <xsl:variable name="id" select="@xml:id"/>
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

  <xsl:template match="tei:body//tei:p">
    <xsl:copy>
      <xsl:attribute name="id" select="@xml:id"/>
      <xsl:text>&#10;</xsl:text>
      <xsl:apply-templates/>
    </xsl:copy>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <xsl:template match="tei:s">
    <xsl:copy>
      <xsl:attribute name="id" select="@xml:id"/>
      <xsl:text>&#10;</xsl:text>
      <xsl:apply-templates/>
    </xsl:copy>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <xsl:template match="tei:seg[@type='name']">
    <name>
      <xsl:attribute name="type" select="@subtype"/>
      <xsl:text>&#10;</xsl:text>
      <xsl:apply-templates/>
    </name>
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

  <!-- TOKENS -->
  <xsl:template match="tei:pc | tei:w">
    <xsl:value-of select="concat(.,'&#9;',et:output-annotations(.))"/>
    <xsl:call-template name="deps"/>
    <xsl:text>&#10;</xsl:text>
    <xsl:if test="@join = 'right' or @join='both' or
		  following::tei:*[self::tei:w or self::tei:pc][1]/@join = 'left' or
		  following::tei:*[self::tei:w or self::tei:pc][1]/@join = 'both'">
      <g/>
      <xsl:text>&#10;</xsl:text>
    </xsl:if>
  </xsl:template>

  <!-- NAMED TEMPLATES -->

  <xsl:template name="deps">
    <xsl:param name="type">UD-SYN</xsl:param>
    <xsl:variable name="id" select="@xml:id"/>
    <xsl:variable name="s" select="ancestor::tei:s"/>
    <xsl:choose>
      <xsl:when test="$s/tei:linkGrp[@type=$type]">
	<xsl:variable name="link"
		      select="$s/tei:linkGrp[@type=$type]/tei:link
			      [ends-with(@target, concat(' #',$id))]"/>
	<xsl:if test="not(normalize-space($link/@ana))">
	  <xsl:message>
	    <xsl:text>ERROR: no syntactic link for token </xsl:text>
	    <xsl:value-of select="concat(ancestor::tei:TEI/@xml:id, ':', @xml:id)"/>
	  </xsl:message>
	</xsl:if>
	<xsl:variable name="syntacticTerm">
	  <xsl:variable name="id" select="et:ref2id($link/@ana, $corpusHeader)"/>
	  <xsl:value-of select="key('id', $id)//tei:term
				[ancestor-or-self::tei:*[@xml:lang][1]/@xml:lang = 'en']
				"/>
	</xsl:variable>
	<xsl:value-of select="concat('&#9;', $syntacticTerm)"/>
	
	<xsl:variable name="target" select="key('id', replace($link/@target,'#(.+?) #.*','$1'))"/>
	<xsl:choose>
	  <xsl:when test="$target/self::tei:s">
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
	<xsl:text>&#9;-&#9;-&#9;-&#9;-&#9;-&#9;-</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- FUNCTIONS -->

  <xsl:function name="et:output-annotations">
    <xsl:param name="token"/>
    <xsl:variable name="n" select="replace($token/@xml:id, '.+\.t?(\d+)$', 'tok$1')"/>
    <xsl:variable name="lemma">
      <xsl:choose>
	<xsl:when test="$token/@lemma">
	  <xsl:value-of select="$token/@lemma"/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:value-of select="substring($token,1,1)"/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="msd" select="replace($token/@ana, '.+?:', '')"/>
    <xsl:variable name="ud-pos" select="replace(replace($token/@msd, 'UPosTag=', ''), '\|.+', '')"/>
    <xsl:variable name="ud-feats">
      <xsl:variable name="fs" select="replace($token/@msd, 'UPosTag=[^|]+\|?', '')"/>
      <xsl:choose>
	<xsl:when test="normalize-space($fs)">
	  <!-- Change source pipe to whatever we have for multivalued attributes -->
	  <xsl:value-of select="replace($fs, '\|', ' ')"/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:text>_</xsl:text>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="concat($lemma, '&#9;', $msd, '&#9;', 
			  $ud-pos, '&#9;', $ud-feats, '&#9;', $n)"/>
  </xsl:function>

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
