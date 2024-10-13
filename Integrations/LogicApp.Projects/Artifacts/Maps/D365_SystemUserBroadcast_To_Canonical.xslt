<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:var="http://schemas.microsoft.com/BizTalk/2003/var" version="1.0" xmlns:userCSharp="http://schemas.microsoft.com/BizTalk/2003/userCSharp" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	<xsl:output omit-xml-declaration="yes" method="xml" version="1.0" />
	<xsl:template match="/">
		<xsl:apply-templates select="/" />
	</xsl:template>
	<xsl:template match="/">
		<SystemUserBroadcast>
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
      <BroadcastIdentifier>SystemUserBroadcast</BroadcastIdentifier>
      <SentAt><xsl:value-of select="/root/OperationCreatedOn"/></SentAt>
    </Context>

			<UserID>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_userid/value"/>
			</UserID>

			<UserDisplayName>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_username/value"/>
			</UserDisplayName>

			<Email>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_alias/value"/>
			</Email>

			<LegalEntity>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_company/value"/>
			</LegalEntity>

			<Language>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_userinfo_language/value"/>
			</Language>

			<AutoLogOff>
				<xsl:choose>
					<xsl:when test="/root/InputParameters[key='Target']/value/mserp_autologoff/value = '0'">
						<xsl:text>Disabled</xsl:text>
					</xsl:when>
					<xsl:when test="/root/InputParameters[key='Target']/value/mserp_autologoff/value = '1'">
						<xsl:text>Enabled</xsl:text>
					</xsl:when>
					<xsl:otherwise>
						<xsl:text>unknown</xsl:text>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_autologoff/value"/>
			</AutoLogOff>
			<Enabled><xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_enabled/value/Value"/></Enabled>
		</SystemUserBroadcast>
	</xsl:template>
</xsl:stylesheet>
