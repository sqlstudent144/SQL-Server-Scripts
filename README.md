# SQL Server Scripts
**Standard disclaimer: You use scripts off of the web at your own risk.
I fully expect this script to work without issue but I've been known to be wrong before.**

Instruction Video: https://www.youtube.com/watch?v=dQw4w9WgXcQ


## sp_SrvPermissions
This stored procedure returns 3 data sets.  The first dataset is the list of server
principals, the second is role membership, and the third is server level permissions.

The final 2 columns of each query are "Un-Do"/"Do" scripts.  For example removing a member
from a role or adding them to a role.  I am fairly confident in the role scripts, however, 
the scripts in the server principals query and server permissions query are works in
progress.  In particular certificates and keys are not scripted out.  Also while the scripts 
have worked flawlessly on the systems I've tested them on, these systems are fairly similar 
when it comes to security so I can't say that in a more complicated system there won't be 
the odd bug.
   
Notes on the create script for server principals:
1. I have included a hashed version of the password and the sid.
This means that when run on another server the password and the sid will remain the same.  
2. In SQL 2005 the create script on the server principals query DOES NOT WORK.  This is 
because the conversion of the sid (in varbinary) to character doesn't appear to work
as I expected in SQL 2005.  It works fine in SQL 2008 and above.  If you want to use
this script in SQL 2005 you can change the CONVERTs in the principal script to
`master.sys.fn_varbintohexstr`
    
```
Parameters:
    @Principal
        If NOT NULL then all three queries only pull for that server principal.  @Principal
        is a pattern check.  The queries check for any row where the passed in value exists.
        It uses the pattern '%' + @Principal + '%'
    @Role
        If NOT NULL then the roles query will pull members of the role.  If it is NOT NULL and
        @Principal is NULL then Server principal and permissions query will pull the principal 
        row for the role and the permissions for the role.  @Role is a pattern check.  The 
        queries check for any row where the passed in value exists.  It uses the pattern 
        '%' + @Role + '%'
    @Type
        If NOT NULL then all three queries will only pull principals of that type.  
        S = SQL login
        U = Windows login
        G = Windows group
        R = Server role
        C = Login mapped to a certificate
        K = Login mapped to an asymmetric key
    @DBName
        If NOT NULL then only return those principals and information about them where the 
        principal exists within the DB specified.
	@UseLikeSearch
		When this is set to 1 (the default) then the search parameters will use LIKE (and 
		%'s will be added around the @Principal and @Role parameters).  
        When set to 0 searchs will use =.
	@IncludeMSShipped
		When this is set to 1 (the default) then all principals will be included.  When set 
		to 0 the fixed server roles and SA and Public principals will be excluded.
	@DropTempTables
		When this is set to 1 (the default) the temp tables used are dropped.  If it's 0
		then the tempt ables are kept for references after the code has finished.
		The temp tables are:
			##SrvPrincipals
			##SrvRoles 
			##SrvPermissions
	@Output
		What type of output is desired.
		Default - Either 'Default' or it doesn't match any of the allowed values then the SP
					will return the standard 3 outputs.
		None - No output at all.  Usually used if you keeping the temp tables to do your own
					reporting.
		CreateOnly - Only return the create scripts where they aren't NULL.
		DropOnly - Only return the drop scripts where they aren't NULL.
		ScriptsOnly - Return drop and create scripts where they aren't NULL.
		Report - Returns one output with one row per principal and a comma delimited list of
					roles the principal is a member of and a comma delimited list of the 
					individual permissions they have.
    @Print
        Defaults to 0, but if a 1 is passed in then the queries are not run but printed
        out instead.  This is primarily for debugging.
        
Data is ordered as follows
    1st result set: SrvPrincipal
    2nd result set: RoleName, LoginName if the parameter @Role is used else
                    LoginName, RoleName
    3rd result set: GranteeName 
```


## sp_DBPermissions
This stored procedure returns 3 data sets. The first dataset is the list of database
principals, the second is role membership, and the third is object and database level
permissions.
    
The final 2 columns of each query are "Un-Do"/"Do" scripts.  For example removing a member
from a role or adding them to a role.  I am fairly confident in the role scripts, however, 
the scripts in the database principals query and database/object permissions query are 
works in progress.  In particular certificates, keys and column level permissions are not
scripted out.  Also while the scripts have worked flawlessly on the systems I've tested 
them on, these systems are fairly similar when it comes to security so I can't say that 
in a more complicated system there won't be the odd bug.

```
Parameters:
    @DBName
        If NULL use the current database, otherwise give permissions based on the parameter.
    
        There is a special case where you pass in ALL to the @DBName.  In this case the SP
        will loop through (yes I'm using a cursor) all of the DBs in sysdatabases and run
        the queries into temp tables before returning the results.  WARNINGS: If you use
        this option and have a large number of databases it will be SLOW.  If you use this
        option and don't specify any other parameters (say a specific @Principal) and have
        even a medium number of databases it will be SLOW.  Also the undo/do scripts do 
        not have USE statements in them so please take that into account.
    @Principal
        If NOT NULL then all three queries only pull for that database principal.  @Principal
        is a pattern check.  The queries check for any row where the passed in value exists.
        It uses the pattern '%' + @Principal + '%'
    @Role
        If NOT NULL then the roles query will pull members of the role.  If it is NOT NULL and
        @DBName is NULL then DB principal and permissions query will pull the principal row for
        the role and the permissions for the role.  @Role is a pattern check.  The queries 
        check for any row where the passed in value exists.  It uses the pattern '%' + @Role +
        '%'
    @Type
        If NOT NULL then all three queries will only pull principals of that type.  
        S = SQL login
        U = Windows login
        G = Windows group
        R = Server role
        C = Login mapped to a certificate
        K = Login mapped to an asymmetric key
    @ObjectName
        If NOT NULL then the third query will display permissions specific to the object 
        specified and the first two queries will display only those users with those specific
        permissions.  Unfortunately at this point only objects in sys.all_objects will work.
        This parameter uses the pattern '%' + @ObjectName + '%'
    @Permission
        If NOT NULL then the third query will display only permissions that match what is in
        the parameter.  The first two queries will display only those users with that specific
        permission.
    @LoginName
        If NOT NULL then each of the queries will only pull back database principals that
        have the same SID as a login that matches the pattern '%' + @LoginName + '%'
	@UseLikeSearch
		When this is set to 1 (the default) then the search parameters will use LIKE (and 
		%'s will be added around the @Principal, @Role, @ObjectName, and @LoginName parameters).  
        When set to 0 searchs will use =.
	@IncludeMSShipped
		When this is set to 1 (the default) then all principals will be included.  When set 
		to 0 the fixed server roles and SA and Public principals will be excluded.
	@DropTempTables
		When this is set to 1 (the default) the temp tables used are dropped.  If it's 0
		then the tempt ables are kept for references after the code has finished.
		The temp tables are:
			##DBPrincipals
			##DBRoles 
			##DBPermissions
	@Output
		What type of output is desired.
		Default - Either 'Default' or it doesn't match any of the allowed values then the SP
					will return the standard 3 outputs.
		None - No output at all.  Usually used if you keeping the temp tables to do your own
					reporting.
		CreateOnly - Only return the create scripts where they aren't NULL.
		DropOnly - Only return the drop scripts where they aren't NULL.
		ScriptsOnly - Return drop and create scripts where they aren't NULL.
		Report - Returns one output with one row per principal and a comma delimited list of
					roles the principal is a member of and a comma delimited list of the 
					individual permissions they have.
    @Print
        Defaults to 0, but if a 1 is passed in then the queries are not run but printed
        out instead.  This is primarily for debugging.
    
Data is ordered as follows
    1st result set: DBPrincipal
    2nd result set: RoleName, UserName if the parameter @Role is used else
                    UserName, RoleName
    3rd result set: ObjectName then Grantee_Name if the parameter @ObjectName
                    is used otherwise Grantee_Name, ObjectName
```
