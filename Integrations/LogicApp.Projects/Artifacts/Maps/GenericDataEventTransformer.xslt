<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"> 
    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="Attributes">
        <xsl:apply-templates select="key"/>
    </xsl:template>
    <xsl:template match="Attributes/key">
        <xsl:element name="{.}">
            <xsl:apply-templates select="../value"/>
        </xsl:element>
    </xsl:template>
</xsl:stylesheet>
