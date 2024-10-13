<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:var="http://schemas.microsoft.com/BizTalk/2003/var" version="1.0" xmlns:userCSharp="http://schemas.microsoft.com/BizTalk/2003/userCSharp" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
	<xsl:output omit-xml-declaration="yes" method="xml" version="1.0" />
	<xsl:template match="/">
		<xsl:apply-templates select="/" />
	</xsl:template>
	<xsl:template match="/">
		<DeviceBroadcast>
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
      <BroadcastIdentifier>DeviceBroadcast</BroadcastIdentifier>
      <SentAt><xsl:value-of select="/root/OperationCreatedOn"/></SentAt>
    </Context>

			<DeviceID>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_msauto_devicenumber/value"/>
			</DeviceID>

			<DeviceDescription>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_msauto_description/value"/>
			</DeviceDescription>

			<DeviceState>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_devicestate/value"/>
			</DeviceState>

			<DeviceType>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_devicetype/value"/>
			</DeviceType>

			<RegistrationNumber>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_msauto_registrationnumber/value"/>
			</RegistrationNumber>

			<DeviceBrand>
				<xsl:value-of select="/root/InputParameters[key='Target']/value/mserp_devicebrand/value"/>
			</DeviceBrand>

		</DeviceBroadcast>
	</xsl:template>
</xsl:stylesheet>
