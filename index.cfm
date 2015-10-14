<cfoutput>

	<cfif structKeyExists(url,"error") AND url.error>
		<cfthrow message="Custom exception to test BugSnag123!"/>
	</cfif>

	<h1>BugSnag</h1>

	Click <a href="index.cfm?error=true">HERE</a> to trigger an exception.

</cfoutput>