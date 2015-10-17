<cfcomponent>
	
	<cfset this.name = "BugSnagTest"/>
	<cfset this.sessionManagement = true/>
	<cfset this.clientManagement = true/>

	<cfset this.bugSnag = createObject("component","BugSnag").init(
		APIKey = "xxxxxxxxxxxx", <!--- Your API key here --->
		releaseStage = "development",
		notifyReleaseStages = "development",
		autoNotify = true,
		useSSL = true
	)/> 

	<cffunction name="onError" returntype="void" output="false">

		<cfargument name="exception" type="any" required="true"/>
	    
	    <cfset var app = structNew()/>
		<cfset var user = structNew()/>
		<cfset var metadata = structNew()/>

		<!--- Set test values in client & session scopes --->
		<cfset session.testValue = 123/>
		<cfset client.testValue = 456/>

		<!--- Create app data --->
		<cfset app["appData1"] = "One"/>
		<cfset app["appData2"] = "Two"/>

		<!--- Create user data --->
	   	<cfset user["id"] = 1/>
		<cfset user["username"] = "John Doe"/>

		<!--- Create meta data 1 --->		
		<cfset metadata["something"] = structNew()/>
		<cfset metadata["something"]["test"] = 123/>
		<cfset metadata["something"]["hi"] = "Hi!"/>

		<!--- Create meta data 2 --->	
		<cfset metadata["else"] = structNew()/>
		<cfset metadata["something"]["test"] = 123/>

		<!--- Notify BugSnag --->
		<cfset this.bugSnag.notifyError(exception = arguments.exception, app = app, user = user, metaData = metaData)/>

	</cffunction>

</cfcomponent>