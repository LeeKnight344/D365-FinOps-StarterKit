<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:var="http://schemas.microsoft.com/BizTalk/2003/var" version="1.0"
    xmlns:userCSharp="http://schemas.microsoft.com/BizTalk/2003/userCSharp"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <xsl:param name="SentAt" />
    <xsl:param name="SourceMessageId" />
    <xsl:output omit-xml-declaration="yes" method="xml" version="1.0" />
    <xsl:template match="/">
        <xsl:apply-templates select="/" />
    </xsl:template>
    <xsl:template match="/">
        <CustomerBroadcast>
            <Context>
                <SourceSystem>D365</SourceSystem>
                <BroadcastIdentifier>CustomerQueryResponse</BroadcastIdentifier>
                <SourceMessageId>
                    <xsl:value-of select="$SourceMessageId" />
                </SourceMessageId>
                <SentAt>
                    <xsl:value-of select="$SentAt" />
                </SentAt>
            </Context>
            <CustomerID>
                <xsl:value-of select="//mserp_customeraccount" />
            </CustomerID>

            <CustomerDisplayName>
                <xsl:value-of select="//mserp_namealias" />
            </CustomerDisplayName>

            <CustomerGroupID>
                <xsl:value-of select="//mserp_customergroupid" />
            </CustomerGroupID>

            <PrimaryAddress>
                <xsl:value-of select="//mserp_fullprimaryaddress" />
            </PrimaryAddress>

            <EmployeeResponsibleID>
                <xsl:value-of select="//mserp_employeeresponsiblenumber" />
            </EmployeeResponsibleID>

            <SalesTaxGroup>
                <xsl:value-of select="//mserp_salestaxgroup" />
            </SalesTaxGroup>
            <Currency>
                <xsl:value-of select="//mserp_salescurrencycode" />
            </Currency>
        </CustomerBroadcast>
    </xsl:template>
</xsl:stylesheet>