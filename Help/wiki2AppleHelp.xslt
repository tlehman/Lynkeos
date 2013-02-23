<?xml version='1.0' encoding='utf-8'?>
<xsl:stylesheet version='1.0' xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method='html' version='1.0' encoding='utf-8'
            doctype-public='-//IETF//DTD HTML//EN' indent='yes'/>

<!-- We need to strip spaces from UL sections to detect the TOC -->
<xsl:strip-space elements="ul li"/>

<!-- Add Apple help meta tags -->
<xsl:template match="/html/head">
   <xsl:copy>
      <!-- Substitute the title -->
      <title><xsl:value-of select="$title"/></title>
      <xsl:element name="meta">
         <xsl:attribute name="name">DESCRIPTION</xsl:attribute>
         <xsl:attribute name="content">
            <xsl:value-of select="$description"/>
         </xsl:attribute>
      </xsl:element>
      <link rel="stylesheet" href="main.css"/>
      <xsl:if test="$noindex != 0">
         <meta name="ROBOTS" content="NOINDEX"/>
      </xsl:if>
   </xsl:copy>
</xsl:template>

<!-- Suppress all id attributes in "a" tags -->
<xsl:template match="//a/@id">
</xsl:template>

<!-- Supress all attributes in "html" tag (makes xmlstarlet bug) -->
<xsl:template match="/html">
   <xsl:copy>
      <xsl:apply-templates select="node()"/>
   </xsl:copy>
</xsl:template>

<!-- Extract the body from the "content" section -->
<xsl:template match="/html/body">
   <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:attribute name="class">wiki</xsl:attribute>
      <xsl:apply-templates select="//div[@id='bodyContent']"/>
   </xsl:copy>
</xsl:template>

<!-- Suppress wiki specific items -->
<xsl:template match="//*[@id='siteSub' or @id='contentSub' or @id='jump-to-nav'
   or @id='catlinks' or @class='editsection' or @class='printfooter']">
</xsl:template>

<!-- Suppress languages links -->
<xsl:template match="//table[@class='nmbox']">
</xsl:template>

<!-- Quite contrived pattern needed to find the table of content,
     "the first UL section with text only in the A anchors" -->
<xsl:template match="/html/body//ul[count(.//*[local-name()!='a' and text()])=0 and position()=1]">
<xsl:if test="$stripTOC = 0">
   <xsl:copy>
   <xsl:apply-templates select="@*|node()"/>
   </xsl:copy>
</xsl:if>
</xsl:template>

<!-- Add a target="_top" to external HREFs -->
<xsl:template match="/html/body//a[starts-with(@href,'http://') or starts-with(@href,'https://')]">
<xsl:copy>
<xsl:attribute name="target">_top</xsl:attribute>
<xsl:apply-templates select="@*|node()"/>
</xsl:copy>
</xsl:template>

<!-- Include additional templates, if any -->
<xsl:include href="extraTemplates.xslt"/>

<!-- Default pattern to copy things unchanged -->
<xsl:template match="@*|node()">
  <xsl:copy>
    <xsl:apply-templates select="@*|node()"/>
  </xsl:copy>
</xsl:template>

</xsl:stylesheet>