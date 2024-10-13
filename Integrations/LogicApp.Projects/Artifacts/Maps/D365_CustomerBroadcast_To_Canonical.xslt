<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:var="http://schemas.microsoft.com/BizTalk/2003/var" version="1.0" xmlns:userCSharp="http://schemas.microsoft.com/BizTalk/2003/userCSharp" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	<xsl:output omit-xml-declaration="yes" method="xml" version="1.0" />
	<xsl:template match="/">
		<xsl:apply-templates select="/" />
	</xsl:template>
	<xsl:template match="/">
		<CustomerBroadcast>
      <Context>
      <SourceSystem>D365</SourceSystem>
			<BroadcastType>
				<xsl:choose>
					<xsl:when test="/root/MessageName = 'OnExternalUpdated'">
						<xsl:text>Update</xsl:text>
					</xsl:when>
					<xsl:when test="/root/MessageName = 'OnExternalDeleted'">
						<xsl:text>Delete</xsl:text>
					</xsl:when>
					<xsl:when test="/root/MessageName = 'OnExternalCreated'">
						<xsl:text>Create</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>unknown</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
			</BroadcastType>
      <BroadcastIdentifier>CustomerBroadcast</BroadcastIdentifier>
      <SentAt><xsl:value-of select="/root/OperationCreatedOn"/></SentAt>
    </Context>

			<CustomerID>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_customeraccount/value"/>
			</CustomerID>

			<CustomerDisplayName>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_organizationname/value"/>
			</CustomerDisplayName>

			<CustomerGroupID>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_customergroupid/value"/>
			</CustomerGroupID>

			<PrimaryAddress>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_fullprimaryaddress/value"/>
			</PrimaryAddress>

			<EmployeeResponsibleID>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_employeeresponsiblenumber/value"/>
			</EmployeeResponsibleID>

			<SalesTaxGroup>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_salestaxgroup/value"/>
			</SalesTaxGroup>
			<Currency><xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_salescurrencycode/value"/></Currency>
		</CustomerBroadcast>
	</xsl:template>
</xsl:stylesheet>
