<cfcomponent>

	<cfset variables.version = "0.1"/>
	<cfset variables.APIKey = ""/>
	
	<cffunction name="init" returntype="any">
	
		<cfargument name="APIKey" type="string" required="true"/>
		<cfargument name="releaseStage" type="string" required="false" default="development"/>
		<cfargument name="notifyReleaseStages" type="string" required="false" default="development"/>
		<cfargument name="autoNotify" type="boolean" required="false" default="true"/>
		<cfargument name="useSSL" type="boolean" required="false" default="true"/>

		<cfset structAppend(variables,arguments,true)/>

		<cfreturn this/>

	</cffunction>

	<cffunction name="setAPIKey" returntype="void">
	
		<cfargument name="APIKey" type="string" required="true"/>
		
		<cfset variables.apiKey = arguments.APIKey/>

	</cffunction>

	<cffunction name="notifyError" returntype="void">
		
		<cfargument name="exception" type="any" required="true"/>
		<cfargument name="context" type="string" required="false" default="#CGI.REQUEST_METHOD# #CGI.PATH_INFO#"/>
		<cfargument name="severity" type="string" required="false" default="error"/>
		<cfargument name="app" type="struct" required="false" default="#structNew()#"/>
		<cfargument name="user" type="struct" required="false" default="#structNew()#"/>
		<cfargument name="metaData" type="struct" required="false" default="#structNew()#"/>
		
		<cfset var payload = ""/>
		<cfset var tagContext = structNew()/>
		<cfset var protocol = "https"/>
		<cfset var applicationSettings = structNew()/>
		<cfset var appScopeEnabled = false/>
		<cfset var sessionScopeEnabled = false/>
		<cfset var clientScopeEnabled = false/>

		<!--- Test if there is an application scope --->
		<cftry>
			<cfset applicationSettings = application.getApplicationSettings()/>
			<cfset appScopeEnabled = true/>
			<cfset sessionScopeEnabled = applicationSettings.sessionManagement/>
			<cfset clientScopeEnabled = applicationSettings.clientManagement/>
			<cfcatch>
				<!--- Nothing, no app scope --->
			</cfcatch>
		</cftry>

		<cfif variables.autoNotify AND listFindNoCase(variables.notifyReleaseStages,variables.releaseStage)>
	
			<cfif structKeyExists(exception,"tagContext")>
				<cfset tagContext = exception.tagContext/>
			<cfelseif  structKeyExists(exception.cause,"tagContext")>
				<cfset tagContext = exception.cause.tagContext/>
			</cfif>

			<cfsavecontent variable="payload">
				<cfoutput>
					{  
						"apiKey":"#variables.APIKey#",
						"notifier":{  
							"name":"bugsnag-coldfusion",
							"version":"#variables.version#",
							"url":"#JSStringFormat("https://github.com/RickGroenewegen/bugsnag-coldfusion")#"
						},
						"events":[  
							{  
								"app":{  
									<cfloop collection="#arguments.app#" item="item">
										"#item#":"#arguments.app[item]#",
									</cfloop>
									"name":"#application.applicationName#",
									"releaseStage":"#variables.releaseStage#"
								},
						
								<cfif structCount(arguments.user)>
								"user":{
									<cfset counter = 1/>
									<cfloop collection="#arguments.user#" item="item">
										"#item#":"#arguments.user[item]#"<cfif counter LT structCount(arguments.user)>,</cfif><cfset counter++/>
									</cfloop>	
								},
								</cfif>			        
						
								"context":"#arguments.context#",
								"payloadVersion":"2",
								"severity":"error",

								"exceptions":[  
									{  
										"errorClass":"Exception",
										"message":"#exception.message# #exception.detail#",
										"stacktrace":[ 
											<cfset counter = 1/>
											<cfloop array="#tagContext#" index="item">
												{  
													"lineNumber":#item.line#,
													#getCodeBlock(item)#
													"inProject":true,
													"file":"#replace(item.template,'\','\\','all')#"
												}<cfif counter LT arrayLen(tagContext)>,</cfif><cfset counter++/>
											</cfloop>
										]
									}
								],
						
								"metaData":{
									<cfloop collection="#arguments.metaData#" item="item">
									"#item#": #serializeScope(arguments.metaData[item])#,
									</cfloop>
									"headers" : #serializeScope(scope = GetHttpRequestData().headers)#,   
									"form" : #serializeScope(scope = form)#,   
									"url" : #serializeScope(scope = url)#,   
									"request" : #serializeScope(scope = request)#,   
									<cfif appScopeEnabled>"application" : #serializeScope(scope = application)#,</cfif>
									<cfif sessionScopeEnabled>"session" : #serializeScope(scope = session)#,</cfif>
									<cfif clientScopeEnabled>"client" : #serializeScope(scope = client)#,</cfif>   			             
									"CGI" : #serializeScope(scope = cgi)#,
									"cookie" : #serializeScope(scope = cookie)#
								}
							}
						]
					}
				</cfoutput>
			</cfsavecontent>

			<cfset payload = stripWhiteSpace(payload)/>
			<cfset payload = replace(payload,"\'","'","all")/>

			<cfif NOT variables.useSSL>
				<cfset protocol = "http"/>
			</cfif>

			<cfhttp method="post" url="#protocol#://notify.bugsnag.com">
				<cfhttpparam type="header" name="Content-Type" value="application/json"/>
				<cfhttpparam type="body" name="field" value="#payload#"/>
			</cfhttp>

		</cfif>

	</cffunction>

	<cffunction name="getCodeBlock" returntype="string">
		
		<cfargument name="item" type="struct" required="true"/>

		<cfset var codeBlock = ""/>
		<cfset var lineContent = ""/>
		<cfset var numberOfLines = 0/>
		<cfset var startPosition = 0/>
		<cfset var endPosition = 0/>
		<cfset var i = 0/>
		<cfset var dataFile = ""/>
		<cfset var margin = 7/> <!--- Number of lines to display in the stack trace --->

		<cfsavecontent variable="codeBlock">
			<cfoutput>
				<cfif fileExists(arguments.item.template)>

					<!--- Open it to count the number of lines --->
					<cfset dataFile = fileOpen( arguments.item.template, "read" ) />
					<cfloop condition="!fileIsEOF(dataFile)">
						<cfset fileReadLine( dataFile )/>
						<cfset numberOfLines++/>
					</cfloop>

					<!--- Open it again --->
					<cfset dataFile = fileOpen( arguments.item.template, "read" ) />

					<!--- Determine starting position. If less then 1, set it to 1 --->
					<cfset startPosition = max(item.line - (fix(margin/2)),1)/>

					<!--- Determine ending position. If more then total number of lines, set to total number of lines --->
					<cfset endPosition = min(startPosition + (margin - 1),numberOfLines)/>
					
					<!--- If the endPosition is the last line, and the difference between start and end is not the margin, 
					then pull the starting position further back --->
					<cfif endPosition EQ numberOfLines AND endPosition - startPosition LT margin>
						<cfset startPosition = endPosition - (margin - 1)/>
					</cfif> 

					<!--- Output the code block --->
					"code" : {
						<cfset i = 1/>
						<cfloop condition="!fileIsEOF(dataFile)">
							<cfset lineContent = fileReadLine( dataFile )/>
							<cfif i GTE startPosition AND i LTE endPosition>
								"#i#":"#jsStringFormat(lineContent)#"<cfif i LT endPosition>,</cfif>
							</cfif>
							<cfset i++/>
    					</cfloop>
					}
				</cfif>
			</cfoutput>
		</cfsavecontent>

		<cfif len(trim(codeBlock))>
			<cfset codeBlock = trim(codeBlock) & ","/>
		</cfif>

		<cfreturn codeBlock/>

	</cffunction>

	<cffunction name="serializeScope" returntype="string">
		
		<cfargument name="scope" type="struct" required="true"/>
		<cfargument name="ignore" type="string" required="false" default=""/>

		<cfset var sScope = duplicate(arguments.scope)/>
		<cfset var returnString = ""/>
		<cfset var item = ""/>
		
		<cfloop list="#arguments.ignore#" index="item">
			<cfset structDelete(sScope,item)/>
		</cfloop>

		<cfloop collection="#sScope#" item="item">
			<cftry>
				<cfset sScope[item] = deserializeJSON(serializeJSON(sScope[item]))/>
				<cfcatch>
					<cfset sScope[item] = "Contains complex values. Could not be serialized"/>
				</cfcatch>
			</cftry>
		</cfloop>
		
		<cfset returnString = serializeJSON(sScope)/>

		<cfreturn returnString/>

	</cffunction>

	<cffunction name="stripWhiteSpace" returnType="string" output="false">

		<cfargument name="theString" required="true" type="string">
		<cfargument name="andTabs" required="false" type="boolean" default="false">

		<cfset var returnString = ""/>

		<cfif arguments.andTabs>
			<cfset returnString = replace(replace(replace(arguments.theString,"#chr(10)#","","all"),"#chr(13)#","","all"),"#chr(9)#","","all")/>
		<cfelse>
			<cfset returnString = REReplace(arguments.theString, "[[:space:]]{2,}"," ","ALL")>

		</cfif>

		<cfreturn returnString/>

	</cffunction>

</cfcomponent>