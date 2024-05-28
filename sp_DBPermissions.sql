USE master
GO
IF OBJECT_ID('dbo.sp_DBPermissions') IS NULL
    EXEC sp_executesql N'CREATE PROCEDURE dbo.sp_DBPermissions AS PRINT ''Stub'';'
GO
/*********************************************************************************************
sp_DBPermissions V7.0
Kenneth Fisher
 
http://www.sqlstudies.com
https://github.com/sqlstudent144/SQL-Server-Scripts/blob/master/sp_DBPermissions.sql
 
This stored procedure returns 3 data sets.  The first dataset is the list of database
principals, the second is role membership, and the third is object and database level
permissions.
    
The final 2 columns of each query are "Un-Do"/"Do" scripts.  For example removing a member
from a role or adding them to a role.  I am fairly confident in the role scripts, however, 
the scripts in the database principals query and database/object permissions query are 
works in progress.  In particular certificates, keys and column level permissions are not
scripted out.  Also while the scripts have worked flawlessly on the systems I've tested 
them on, these systems are fairly similar when it comes to security so I can't say that 
in a more complicated system there won't be the odd bug.
    
Standard disclaimer: You use scripts off of the web at your own risk.  I fully expect this
     script to work without issue but I've been known to be wrong before.
    
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
    @CopyTo
        If @Principal is filled in then the value in @CopyTo is used in the drop and create
        scripts instead of @Principal. In the case of the CREATE USER statement @CopyTo 
        also replaces the name of the server level principal, however it does not affect the
        default schema name.
        NOTE: It is very important to note that if @CopyTo is not a valid name the drop/create
        scripts may fail.
    @DropTempTables
        When this is set to 1 (the default) the temp tables used are dropped.  If it's 0
        then the tempt ables are kept for references after the code has finished.
        The temp tables are:
            ##DBPrincipals
            ##DBRoles 
            ##DBPermissions
    @ShowOrphans
        By default this is 0. If it is 1 then it shows only orphaned principals and scripts to fix them.
                  Note: This option is 2012 and up only.
    @Output
        What type of output is desired.
        Default - Either 'Default' or it doesn't match any of the allowed values then the SP
                    will return the standard 3 outputs.
        None - No output at all.  Usually used if you keeping the temp tables to do your own
                    reporting.
        CreateOnly - Only return the create scripts where they aren't NULL.
        DropOnly - Only return the drop scripts where they aren't NULL.
        ScriptOnly - Return drop and create scripts where they aren't NULL.
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
    3rd result set: If @ObjectName is used then DBName, SchemaName, ObjectName, Grantee_Name, permission_name
                    otherwise DBName, GranteeName, SchemaName, ObjectName, permission_name
    
-- V2.0
-- 8/18/2013 – Create a stub if the SP doesn’t exist, then always do an alter
-- 8/18/2013 - Use instance collation for all concatenated strings
-- 9/04/2013 - dbo can’t be added or removed from roles.  Don’t script.
-- 9/04/2013 - Fix scripts for schema level permissions.
-- 9/04/2013 – Change print option to show values of variables not the 
--             Variable names.
-- V3.0
-- 10/5/2013 - Added @Type parameter to pull only principals of a given type.
-- 10/10/2013 - Added @ObjectName parameter to pull only permissions for a given object.
-- V4.0
-- 11/18/2013 - Added parameter names to sp_addrolemember and sp_droprolemember.
-- 11/19/2013 - Added an ORDER BY to each of the result sets.  See above for details.
-- 01/04/2014 - Add an ALL option to the DBName parameter.
-- V4.1
-- 02/07/2014 - Fix bug scripting permissions where object and schema have the same ID
-- 02/15/2014 - Add support for user defined types
-- 02/15/2014 - Fix: Add schema to object GRANT and REVOKE scripts
-- V5.0
-- 4/29/2014 - Fix: Removed extra print statements
-- 4/29/2014 - Fix: Added SET NOCOUNT ON
-- 4/29/2014 - Added a USE statement to the scripts when using the @DBName = 'All' option
-- 5/01/2014 - Added @Permission parameter
-- 5/14/2014 - Added additional permissions based on information from Kendal Van Dyke's
        post http://www.kendalvandyke.com/2014/02/using-sysobjects-when-scripting.html
-- 6/02/2014 - Added @LoginName parameter
-- V5.5
-- 7/15/2014 - Bunch of changes recommended by @SQLSoldier/"https://twitter.com/SQLSoldier"
                Primarily changing the strings to unicode & adding QUOTENAME in a few places
                I'd missed it.
-- V6.0
-- 10/19/2014 - Add @UserLikeSearch and @IncludeMSShipped parameters. 
-- 11/29/2016 - Fixed permissions for symmetric keys
--              Found and fixed by Brenda Grossnickle
-- 03/25/2017 - Move SID towards the end of the first output so the more important 
--              columns are closer to the front.
-- 03/25/2017 - Add IF Exists to drop and create user scripts
-- 03/25/2017 - Remove create/drop user scripts for guest, public, sys and INFORMATION_SCHEMA
-- 03/25/2017 - Add @DropTempTables to keep the temp tables after the SP is run.
-- 03/26/2017 - Add @Output to allow different types of output.
-- V6.1
-- 06/25/2018 - Skip snapshots
-- 02/13/2019 - Fix to direct permissions column in the report output to show schema permissions correctly
-- 04/05/2019 - For 'All' DB parameter fix to only look at ONLINE and EMERGENCY DBs.
-- 06/04/2019 - Add SchemaName and permission_name to the order of the third data set.
                This makes the order more reliable.
-- 06/04/2019 - Begin cleanup of the dynamic SQL (specifically removing carrage return & extra quotes)
-- 06/04/2019 - Fix @print where part of the permissions query was being truncated.
-- V6.2
-- 07/15/2022 - Add @CopyTo parameter to handle requests like "Please copy permissions from x to y."
-- 07/15/2022 - Clean up dyanmic formatting to remove most of the N' and "' + CHAR(13) + " strings.
-- 07/31/2022 - Formatting: Replace tabs with spaces
-- 01/14/2023 - Fixes for unicode strings
-- V7.0
-- 08/15/2023 - Add orphan functionality with @ShowOrphans parameter.
*********************************************************************************************/

ALTER PROCEDURE dbo.sp_DBPermissions 
(
    @DBName sysname = NULL, 
    @Principal sysname = NULL, 
    @Role sysname = NULL, 
    @Type nvarchar(30) = NULL,
    @ObjectName sysname = NULL,
    @Permission sysname = NULL,
    @LoginName sysname = NULL,
    @UseLikeSearch bit = 1,
    @IncludeMSShipped bit = 1,
    @CopyTo sysname = NULL,
    @DropTempTables bit = 1,
    @ShowOrphans bit = 0,
    @Output varchar(30) = 'Default',
    @Print bit = 0
)
AS

SET NOCOUNT ON
    
DECLARE @Collation nvarchar(75) 
SET @Collation = N' COLLATE ' + CAST(SERVERPROPERTY('Collation') AS nvarchar(50))
    
DECLARE @sql nvarchar(max)
DECLARE @sql2 nvarchar(max)
DECLARE @ObjectList nvarchar(max)
DECLARE @ObjectList2 nvarchar(max)
DECLARE @use nvarchar(500)
DECLARE @AllDBNames sysname
    
IF @DBName IS NULL OR @DBName = N'All'
    BEGIN
        SET @use = ''
        IF @DBName IS NULL
            SET @DBName = DB_NAME()
            --SELECT @DBName = db_name(database_id) 
            --FROM sys.dm_exec_requests 
            --WHERE session_id = @@SPID
    END
ELSE
--    IF EXISTS (SELECT 1 FROM sys.databases WHERE name = @DBName)
    IF db_id(@DBName) IS NOT NULL
        SET @use = N'USE ' + QUOTENAME(@DBName) + N';' + NCHAR(13)
    ELSE
        BEGIN
            RAISERROR (N'%s is not a valid database name.',
                            16, 
                            1,
                            @DBName)
            RETURN
        END

DECLARE @LikeOperator nvarchar(4)

IF @UseLikeSearch = 1
    SET @LikeOperator = N'LIKE'
ELSE 
    SET @LikeOperator = N'='
    
IF @UseLikeSearch = 1
BEGIN 
    IF LEN(ISNULL(@Principal,'')) > 0
        SET @Principal = N'%' + @Principal + N'%'
        
    IF LEN(ISNULL(@Role,'')) > 0
        SET @Role = N'%' + @Role + N'%'
    
    IF LEN(ISNULL(@ObjectName,'')) > 0
        SET @ObjectName = N'%' + @ObjectName + N'%'
  
    IF LEN(ISNULL(@LoginName,'')) > 0
        SET @LoginName = N'%' + @LoginName + N'%'
END

IF (@Principal IS NULL AND @CopyTo IS NOT NULL) OR LEN(@CopyTo) = 0
    SET @CopyTo = NULL
  
IF @Print = 1 AND @DBName = N'All'
    BEGIN
        PRINT 'DECLARE @AllDBNames sysname'
        PRINT 'SET @AllDBNames = ''master'''
        PRINT ''
    END
--=========================================================================
-- Database Principals
SET @sql =   
    N'SELECT ' + CASE WHEN @DBName = 'All' THEN N'@AllDBNames' ELSE N'N''' + @DBName + N'''' END + N' AS DBName,
       DBPrincipals.principal_id AS DBPrincipalId, DBPrincipals.name AS DBPrincipal, SrvPrincipals.name AS SrvPrincipal, 
       DBPrincipals.type, DBPrincipals.type_desc, DBPrincipals.default_schema_name, DBPrincipals.create_date,  
       DBPrincipals.modify_date, DBPrincipals.is_fixed_role, 
       Authorizations.name AS RoleAuthorization, DBPrincipals.sid, 
       CASE WHEN DBPrincipals.is_fixed_role = 0 AND DBPrincipals.name NOT IN (''dbo'',''guest'', ''INFORMATION_SCHEMA'', ''public'', ''sys'') THEN ' + NCHAR(13) + 
    CASE WHEN @DBName = 'All' THEN N'   ''USE '' + QUOTENAME(@AllDBNames) + ''; '' + ' + NCHAR(13) ELSE N'' END + 
    N'            ''IF DATABASE_PRINCIPAL_ID(N'''''' + ' + ISNULL('N'+QUOTENAME(@CopyTo,''''),'DBPrincipals.name') + ' + '''''') IS NOT NULL '' + 
               ''DROP '' + CASE DBPrincipals.[type] WHEN ''C'' THEN NULL 
                   WHEN ''K'' THEN NULL 
                   WHEN ''R'' THEN ''ROLE''  
                   WHEN ''A'' THEN ''APPLICATION ROLE'' 
                   ELSE ''USER'' END + 
               '' ''+QUOTENAME(' + ISNULL('N'+QUOTENAME(@CopyTo,''''),'DBPrincipals.name') + '' + @Collation + N') + '';'' ELSE NULL END AS DropScript, 
       CASE WHEN DBPrincipals.is_fixed_role = 0 AND DBPrincipals.name NOT IN (''dbo'',''guest'', ''INFORMATION_SCHEMA'', ''public'', ''sys'') THEN ' + NCHAR(13) + 
    CASE WHEN @DBName = 'All' THEN N'   ''USE '' + QUOTENAME(@AllDBNames) + ''; '' + ' +NCHAR(13) ELSE N'' END + 
    N'            ''IF DATABASE_PRINCIPAL_ID(N'''''' + ' + ISNULL('N'+QUOTENAME(@CopyTo,''''),'DBPrincipals.name') + ' + '''''') IS NULL '' + 
               ''CREATE '' + CASE DBPrincipals.[type] WHEN ''C'' THEN NULL 
                   WHEN ''K'' THEN NULL 
                   WHEN ''R'' THEN ''ROLE''  
                   WHEN ''A'' THEN ''APPLICATION ROLE''  
                   ELSE ''USER'' END + 
               '' ''+QUOTENAME(' + ISNULL('N'+QUOTENAME(@CopyTo,''''),'DBPrincipals.name') + '' + @Collation + N') END + 
               CASE WHEN DBPrincipals.[type] = ''R'' THEN 
                   ISNULL('' AUTHORIZATION ''+QUOTENAME(Authorizations.name' + @Collation + N'),'''') 
                   WHEN DBPrincipals.[type] = ''A'' THEN 
                       ''''  
                   WHEN DBPrincipals.[type] NOT IN (''C'',''K'') THEN 
                       ISNULL('' FOR LOGIN '' + 
                            QUOTENAME(' + ISNULL('N'+QUOTENAME(@CopyTo,''''),'SrvPrincipals.name') + '' + @Collation + N'),'' WITHOUT LOGIN'') +  
                       ISNULL('' WITH DEFAULT_SCHEMA =  ''+
                            QUOTENAME(DBPrincipals.default_schema_name' + @Collation + N'),'''') 
               ELSE '''' 
               END + '';'' +  
               CASE WHEN DBPrincipals.[type] NOT IN (''C'',''K'',''R'',''A'') 
                   AND SrvPrincipals.name IS NULL 
                   AND DBPrincipals.sid IS NOT NULL 
                   AND DBPrincipals.sid NOT IN (0x00, 0x01)  
                   THEN '' -- Possible missing server principal''  
                   ELSE '''' END 
           AS CreateScript' + 
    CASE WHEN SERVERPROPERTY('ProductVersion') >= '12' AND @ShowOrphans = 1 THEN N', 
        CASE WHEN DBPrincipals.name = ''dbo'' THEN ''NULL'' ELSE  
        ''IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'' + QUOTENAME(DBPrincipals.name,'''''''') + '') ' +  
               N'CREATE LOGIN '' + QUOTENAME(DBPrincipals.name) +
               CASE WHEN DBPrincipals.type = (''S'') THEN '' WITH PASSWORD = ''''<Insert Strong Password Here '+ CAST(NEWID() AS nvarchar(36))+'>'''', '' + 
                    '' SID = '' + CONVERT(varchar(85), DBPrincipals.sid, 1) 
               WHEN DBPrincipals.type IN (''U'',''G'') THEN '' FROM WINDOWS ''  
               ELSE '''' END END AS CreateLogin, ' +
    CASE WHEN @DBName = 'All' THEN N'   ''USE '' + QUOTENAME(@AllDBNames) + ''; '' + ' +NCHAR(13) ELSE N'' END + 
    N'        CASE WHEN DBPrincipals.name = ''dbo'' THEN ''EXEC sp_changedbowner ''''<existing login>'''';'' ELSE  
        ''ALTER USER '' + QUOTENAME(DBPrincipals.name) + '' WITH LOGIN = '' + QUOTENAME(DBPrincipals.name) + '';'' END AS AlterUser' ELSE '' END + '
    FROM sys.database_principals DBPrincipals 
    LEFT OUTER JOIN sys.database_principals Authorizations 
       ON DBPrincipals.owning_principal_id = Authorizations.principal_id 
    LEFT OUTER JOIN sys.server_principals SrvPrincipals 
       ON DBPrincipals.sid = SrvPrincipals.sid 
       AND DBPrincipals.sid NOT IN (0x00, 0x01) 
    WHERE 1=1 '
    
IF SERVERPROPERTY('ProductVersion') >= '12' AND @ShowOrphans = 1
    SET @sql = @sql + NCHAR(13) + N'  AND DBPrincipals.authentication_type_desc <> ''NONE'' 
    AND SrvPrincipals.principal_id IS NULL 
    AND DBPrincipals.sid NOT IN (0x00, 0x01)'

IF LEN(ISNULL(@Principal,@Role)) > 0 
    IF @Print = 1
        SET @sql = @sql + NCHAR(13) + N'  AND DBPrincipals.name ' + @LikeOperator + N' N' + 
            ISNULL(QUOTENAME(@Principal,N''''),QUOTENAME(@Role,'''')) 
    ELSE
        SET @sql = @sql + NCHAR(13) + N'  AND DBPrincipals.name ' + @LikeOperator + N' ISNULL(@Principal,@Role) '
    
IF LEN(@Type) > 0
    IF @Print = 1
        SET @sql = @sql + NCHAR(13) + N'  AND DBPrincipals.type ' + @LikeOperator + N' N' + QUOTENAME(@Type,'''')
    ELSE
        SET @sql = @sql + NCHAR(13) + N'  AND DBPrincipals.type ' + @LikeOperator + N' @Type'
    
IF LEN(@LoginName) > 0
    IF @Print = 1
        SET @sql = @sql + NCHAR(13) + N'  AND SrvPrincipals.name ' + @LikeOperator + N' N' + QUOTENAME(@LoginName,'''')
    ELSE
        SET @sql = @sql + NCHAR(13) + N'  AND SrvPrincipals.name ' + @LikeOperator + N' @LoginName'
  
IF LEN(@ObjectName) > 0
    BEGIN
        SET @sql = @sql + NCHAR(13) + 
        N'   AND EXISTS (SELECT 1 ' + NCHAR(13) + 
        N'               FROM sys.all_objects [Objects] ' + NCHAR(13) + 
        N'               INNER JOIN sys.database_permissions Permission ' + NCHAR(13) +  
        N'                   ON Permission.major_id = [Objects].object_id ' + NCHAR(13) + 
        N'               WHERE Permission.major_id = [Objects].object_id ' + NCHAR(13) + 
        N'                 AND Permission.grantee_principal_id = DBPrincipals.principal_id ' + NCHAR(13)
          
        IF @Print = 1
            SET @sql = @sql + N'                 AND [Objects].name ' + @LikeOperator + N' N' + QUOTENAME(@ObjectName,'''') 
        ELSE
            SET @sql = @sql + N'                 AND [Objects].name ' + @LikeOperator + N' @ObjectName'
  
        SET @sql = @sql + N')'
    END
  
IF LEN(@Permission) > 0
    BEGIN
        SET @sql = @sql + NCHAR(13) + 
        N'   AND EXISTS (SELECT 1 ' + NCHAR(13) + 
        N'               FROM sys.database_permissions Permission ' + NCHAR(13) +  
        N'               WHERE Permission.grantee_principal_id = DBPrincipals.principal_id ' + NCHAR(13)
          
        IF @Print = 1
            SET @sql = @sql + N'                 AND Permission.permission_name ' + @LikeOperator + N' N' + QUOTENAME(@Permission,'''') 
        ELSE
            SET @sql = @sql + N'                 AND Permission.permission_name ' + @LikeOperator + N' @Permission'
  
        SET @sql = @sql + N')'
    END

IF @IncludeMSShipped = 0
    SET @sql = @sql + NCHAR(13) + N'  AND DBPrincipals.is_fixed_role = 0 ' + NCHAR(13) + 
                '  AND DBPrincipals.name NOT IN (''dbo'',''public'',''INFORMATION_SCHEMA'',''guest'',''sys'') '

IF @Print = 1
BEGIN
    PRINT N'-- Database Principals'
    PRINT CAST(@sql AS nvarchar(max))
    PRINT '' -- Spacing before the next print
    PRINT ''
END
ELSE
BEGIN
    IF object_id('tempdb..##DBPrincipals') IS NOT NULL
        DROP TABLE ##DBPrincipals

    -- Create temp table to store the data in
    CREATE TABLE ##DBPrincipals (
        DBName sysname NULL,
        DBPrincipalId int NULL,
        DBPrincipal sysname NULL,
        SrvPrincipal sysname NULL,
        type char(1) NULL,
        type_desc NVARCHAR (60) NULL, /* type_desc nchar(60) NULL, to remove extra space */
        default_schema_name sysname NULL,
        create_date datetime NULL,
        modify_date datetime NULL,
        is_fixed_role bit NULL,
        RoleAuthorization sysname NULL,
        sid varbinary(85) NULL,
        DropScript nvarchar(max) NULL,
        CreateScript nvarchar(max) NULL
        )

    IF SERVERPROPERTY('ProductVersion') >= '12' AND @ShowOrphans = 1
    BEGIN
        ALTER TABLE ##DBPrincipals ADD CreateLogin nvarchar(max) NULL
        ALTER TABLE ##DBPrincipals ADD AlterUser nvarchar(max) NULL
    END

    SET @sql =  @use + N'INSERT INTO ##DBPrincipals ' + NCHAR(13) + @sql

    IF @DBName = 'All'
        BEGIN
            -- Declare a READ_ONLY cursor to loop through the databases
            DECLARE cur_DBList CURSOR
            READ_ONLY
            FOR SELECT name FROM sys.databases 
            WHERE state IN (0,5)
              AND source_database_id IS NULL
            ORDER BY name
    
            OPEN cur_DBList
    
            FETCH NEXT FROM cur_DBList INTO @AllDBNames
            WHILE (@@fetch_status <> -1)
            BEGIN
                IF (@@fetch_status <> -2)
                BEGIN
                    SET @sql2 = N'USE ' + QUOTENAME(@AllDBNames) + N';' + NCHAR(13) + @sql
                    EXEC sp_executesql @sql2, 
                        N'@Principal sysname, @Role sysname, @Type nvarchar(30), @ObjectName sysname, 
                        @AllDBNames sysname, @Permission sysname, @LoginName sysname', 
                        @Principal, @Role, @Type, @ObjectName, @AllDBNames, @Permission, @LoginName
                    -- PRINT @sql2
                END
                FETCH NEXT FROM cur_DBList INTO @AllDBNames
            END
    
            CLOSE cur_DBList
            DEALLOCATE cur_DBList
        END
    ELSE
        EXEC sp_executesql @sql, N'@Principal sysname, @Role sysname, @Type nvarchar(30), 
            @ObjectName sysname, @Permission sysname, @LoginName sysname', 
            @Principal, @Role, @Type, @ObjectName, @Permission, @LoginName
END  
--=========================================================================
-- Database Role Members
IF NOT (SERVERPROPERTY('ProductVersion') >= '12' AND @ShowOrphans = 1)
BEGIN
SET @sql =  
    N'SELECT ' + CASE WHEN @DBName = 'All' THEN N'@AllDBNames' ELSE N'N''' + @DBName + N'''' END + N' AS DBName,
     Users.principal_id AS UserPrincipalId, Users.name AS UserName, Roles.name AS RoleName, ' + NCHAR(13) + 
    CASE WHEN @DBName = 'All' THEN N'   ''USE '' + QUOTENAME(@AllDBNames) + ''; '' + ' + NCHAR(13) ELSE N'' END + 
    N'   CASE WHEN Users.is_fixed_role = 0 AND Users.name <> ''dbo'' THEN 
       ''EXEC sp_droprolemember @rolename = N''+QUOTENAME(Roles.name' + @Collation + 
                N','''''''')+'', @membername = N''+QUOTENAME(CASE WHEN Users.name = ''dbo'' THEN NULL
                ELSE ' + ISNULL('N'+QUOTENAME(@CopyTo,''''),'Users.name') + ' END' + @Collation + 
                N','''''''')+'';'' END AS DropScript, ' + NCHAR(13) + 
    CASE WHEN @DBName = 'All' THEN N'   ''USE '' + QUOTENAME(@AllDBNames) + ''; '' + ' + NCHAR(13) ELSE N'' END + 
    N'   CASE WHEN Users.is_fixed_role = 0 AND Users.name <> ''dbo'' THEN 
       ''EXEC sp_addrolemember @rolename = N''+QUOTENAME(Roles.name' + @Collation + 
                N','''''''')+'', @membername = N''+QUOTENAME(CASE WHEN Users.name = ''dbo'' THEN NULL
                ELSE ' + ISNULL('N'+QUOTENAME(@CopyTo,''''),'Users.name') + ' END' + @Collation + 
                N','''''''')+'';'' END AS AddScript 
    FROM sys.database_role_members RoleMembers 
    JOIN sys.database_principals Users 
       ON RoleMembers.member_principal_id = Users.principal_id  
    JOIN sys.database_principals Roles 
       ON RoleMembers.role_principal_id = Roles.principal_id  
    WHERE 1=1 '
        
IF LEN(ISNULL(@Principal,'')) > 0
    IF @Print = 1
        SET @sql = @sql + NCHAR(13) + N'  AND Users.name ' + @LikeOperator + N' N'+QUOTENAME(@Principal,'''')
    ELSE
        SET @sql = @sql + NCHAR(13) + N'  AND Users.name ' + @LikeOperator + N' @Principal'
    
IF LEN(ISNULL(@Role,'')) > 0
    IF @Print = 1
        SET @sql = @sql + NCHAR(13) + N'  AND Roles.name ' + @LikeOperator + N' N'+QUOTENAME(@Role,'''')
    ELSE
        SET @sql = @sql + NCHAR(13) + N'  AND Roles.name ' + @LikeOperator + N' @Role'
    
IF LEN(@Type) > 0 
    IF @Print = 1
        SET @sql = @sql + NCHAR(13) + N'  AND Users.type ' + @LikeOperator + N' N' + QUOTENAME(@Type,'''')
    ELSE
        SET @sql = @sql + NCHAR(13) + N'  AND Users.type ' + @LikeOperator + N' @Type'
  
IF LEN(@LoginName) > 0
    BEGIN
        SET @sql = @sql + NCHAR(13) + 
        N'   AND EXISTS (SELECT 1 
                       FROM sys.server_principals SrvPrincipals
                       WHERE Users.sid NOT IN (0x00, 0x01)
                         AND SrvPrincipals.sid = Users.sid
                         AND Users.type NOT IN (''R'') ' + NCHAR(13) 
        IF @Print = 1
            SET @sql = @sql + NCHAR(13) + '  AND SrvPrincipals.name ' + @LikeOperator + N' N' + QUOTENAME(@LoginName,'''')
        ELSE
            SET @sql = @sql + NCHAR(13) + '  AND SrvPrincipals.name ' + @LikeOperator + N' @LoginName'
  
        SET @sql = @sql + N')'
    END
  
IF LEN(@ObjectName) > 0
    BEGIN
        SET @sql = @sql + NCHAR(13) + 
        N'   AND EXISTS (SELECT 1 
                       FROM sys.all_objects [Objects] 
                       INNER JOIN sys.database_permissions Permission  
                           ON Permission.major_id = [Objects].object_id 
                       WHERE Permission.major_id = [Objects].object_id 
                         AND Permission.grantee_principal_id = Users.principal_id ' + NCHAR(13)
          
        IF @Print = 1
            SET @sql = @sql + N'                 AND [Objects].name ' + @LikeOperator + N' N' + QUOTENAME(@ObjectName,'''') 
        ELSE
            SET @sql = @sql + N'                 AND [Objects].name ' + @LikeOperator + N' @ObjectName'
  
        SET @sql = @sql + N')'
    END
  
IF LEN(@Permission) > 0
    BEGIN
        SET @sql = @sql + NCHAR(13) + 
        N'   AND EXISTS (SELECT 1 
                       FROM sys.database_permissions Permission  
                       WHERE Permission.grantee_principal_id = Users.principal_id ' + NCHAR(13)
          
        IF @Print = 1
            SET @sql = @sql + N'                 AND Permission.permission_name ' + @LikeOperator + N' N' + QUOTENAME(@Permission,'''') 
        ELSE
            SET @sql = @sql + N'                 AND Permission.permission_name ' + @LikeOperator + N' @Permission'
  
        SET @sql = @sql + N')'
    END
  
IF @IncludeMSShipped = 0
    SET @sql = @sql + NCHAR(13) + N'  AND Users.is_fixed_role = 0 ' + NCHAR(13) + 
                '  AND Users.name NOT IN (''dbo'',''public'',''INFORMATION_SCHEMA'',''guest'',''sys'') '

IF @Print = 1
BEGIN
    PRINT N'-- Database Role Members'
    PRINT CAST(@sql AS nvarchar(max))
    PRINT '' -- Spacing before the next print
    PRINT '' 
END
ELSE
BEGIN
    IF object_id('tempdb..##DBRoles') IS NOT NULL
        DROP TABLE ##DBRoles

    -- Create temp table to store the data in
    CREATE TABLE ##DBRoles (
        DBName sysname NULL,
        UserPrincipalId int NULL,
        UserName sysname NULL,
        RoleName sysname NULL,
        DropScript nvarchar(max) NULL,
        AddScript nvarchar(max) NULL
        )

    SET @sql =  @use + NCHAR(13) + 'INSERT INTO ##DBRoles ' + NCHAR(13) + @sql
    
    IF @DBName = 'All'
        BEGIN
            -- Declare a READ_ONLY cursor to loop through the databases
            DECLARE cur_DBList CURSOR
            READ_ONLY
            FOR SELECT name FROM sys.databases 
            WHERE state IN (0,5)
              AND source_database_id IS NULL
            ORDER BY name
    
            OPEN cur_DBList
    
            FETCH NEXT FROM cur_DBList INTO @AllDBNames
            WHILE (@@fetch_status <> -1)
            BEGIN
                IF (@@fetch_status <> -2)
                BEGIN
                    SET @sql2 = 'USE ' + QUOTENAME(@AllDBNames) + ';' + NCHAR(13) + @sql
                    EXEC sp_executesql @sql2, 
                        N'@Principal sysname, @Role sysname, @Type nvarchar(30), @ObjectName sysname, 
                        @AllDBNames sysname, @Permission sysname, @LoginName sysname', 
                        @Principal, @Role, @Type, @ObjectName, @AllDBNames, @Permission, @LoginName
                    -- PRINT @sql2
                END
                FETCH NEXT FROM cur_DBList INTO @AllDBNames
            END
    
            CLOSE cur_DBList
            DEALLOCATE cur_DBList
        END
    ELSE
        EXEC sp_executesql @sql, N'@Principal sysname, @Role sysname, @Type nvarchar(30), 
            @ObjectName sysname, @Permission sysname, @LoginName sysname', 
            @Principal, @Role, @Type, @ObjectName, @Permission, @LoginName
END
END    
--=========================================================================
-- Database & object Permissions
IF NOT (SERVERPROPERTY('ProductVersion') >= '12' AND @ShowOrphans = 1)
BEGIN
SET @ObjectList =
    N'; WITH ObjectList AS (
       SELECT NULL AS SchemaName , 
           name ' + @Collation + ' AS name, 
           database_id AS id, 
           ''DATABASE'' AS class_desc,
           '''' AS class 
       FROM master.sys.databases
       UNION ALL
       SELECT SCHEMA_NAME(sys.all_objects.schema_id) ' + @Collation + N' AS SchemaName,
           name ' + @Collation + N' AS name, 
           object_id AS id, 
           ''OBJECT_OR_COLUMN'' AS class_desc,
           ''OBJECT'' AS class 
       FROM sys.all_objects
       UNION ALL
       SELECT name ' + @Collation + N' AS SchemaName, 
           NULL AS name, 
           schema_id AS id, 
           ''SCHEMA'' AS class_desc,
           ''SCHEMA'' AS class 
       FROM sys.schemas
       UNION ALL
       SELECT NULL AS SchemaName, 
           name ' + @Collation + N' AS name, 
           principal_id AS id, 
           ''DATABASE_PRINCIPAL'' AS class_desc,
           CASE type_desc 
               WHEN ''APPLICATION_ROLE'' THEN ''APPLICATION ROLE'' 
               WHEN ''DATABASE_ROLE'' THEN ''ROLE'' 
               ELSE ''USER'' END AS class 
       FROM sys.database_principals
       UNION ALL
       SELECT SCHEMA_NAME(schema_id) ' + @Collation + N' AS SchemaName, 
           name ' + @Collation + N' AS name, 
           xml_collection_id AS id, 
           ''XML_SCHEMA_COLLECTION'' AS class_desc,
           ''XML SCHEMA COLLECTION'' AS class 
       FROM sys.xml_schema_collections
       UNION ALL
       SELECT NULL AS SchemaName, 
           name ' + @Collation + N' AS name, 
           message_type_id AS id, 
           ''MESSAGE_TYPE'' AS class_desc,
           ''MESSAGE TYPE'' AS class 
       FROM sys.service_message_types
       UNION ALL
       SELECT NULL AS SchemaName, 
           name ' + @Collation + N' AS name, 
           assembly_id AS id, 
           ''ASSEMBLY'' AS class_desc,
           ''ASSEMBLY'' AS class 
       FROM sys.assemblies
       UNION ALL'

SET @ObjectList2 =  N'
       SELECT SCHEMA_NAME(sys.types.schema_id) ' + @Collation + N' AS SchemaName, 
           name ' + @Collation + N' AS name, 
           user_type_id AS id, 
           ''TYPE'' AS class_desc,
           ''TYPE'' AS class 
       FROM sys.types
       UNION ALL
       SELECT NULL AS SchemaName, 
           name ' + @Collation + N' AS name, 
           service_contract_id AS id, 
           ''SERVICE_CONTRACT'' AS class_desc,
           ''CONTRACT'' AS class 
       FROM sys.service_contracts
       UNION ALL
       SELECT NULL AS SchemaName, 
           name ' + @Collation + N' AS name, 
           service_id AS id, 
           ''SERVICE'' AS class_desc,
           ''SERVICE'' AS class 
       FROM sys.services
       UNION ALL
       SELECT NULL AS SchemaName, 
           name ' + @Collation + N' AS name, 
           remote_service_binding_id AS id, 
           ''REMOTE_SERVICE_BINDING'' AS class_desc,
           ''REMOTE SERVICE BINDING'' AS class 
       FROM sys.remote_service_bindings
       UNION ALL
       SELECT NULL AS SchemaName, 
           name ' + @Collation + N' AS name, 
           route_id AS id, 
           ''ROUTE'' AS class_desc,
           ''ROUTE'' AS class 
       FROM sys.routes
       UNION ALL
       SELECT NULL AS SchemaName, 
           name ' + @Collation + N' AS name, 
           fulltext_catalog_id AS id, 
           ''FULLTEXT_CATALOG'' AS class_desc,
           ''FULLTEXT CATALOG'' AS class 
       FROM sys.fulltext_catalogs
       UNION ALL
       SELECT NULL AS SchemaName, 
           name ' + @Collation + N' AS name, 
           symmetric_key_id AS id, 
           ''SYMMETRIC_KEYS'' AS class_desc,
           ''SYMMETRIC KEY'' AS class 
       FROM sys.symmetric_keys
       UNION ALL
       SELECT NULL AS SchemaName, 
           name ' + @Collation + N' AS name, 
           certificate_id AS id, 
           ''CERTIFICATE'' AS class_desc,
           ''CERTIFICATE'' AS class 
       FROM sys.certificates
       UNION ALL
       SELECT NULL AS SchemaName, 
           name ' + @Collation + N' AS name, 
           asymmetric_key_id AS id, 
           ''ASYMMETRIC_KEY'' AS class_desc,
           ''ASYMMETRIC KEY'' AS class 
       FROM sys.asymmetric_keys 
       ) ' + NCHAR(13)

    SET @sql =
    N'SELECT ' + CASE WHEN @DBName = 'All' THEN N'@AllDBNames' ELSE N'N''' + @DBName + N'''' END + N' AS DBName, 
       Grantee.principal_id AS GranteePrincipalId, Grantee.name AS GranteeName, Grantor.name AS GrantorName, 
       Permission.class_desc, Permission.permission_name, 
       ObjectList.name + CASE WHEN Columns.name IS NOT NULL THEN '' ('' + Columns.name + '')'' ELSE '''' END AS ObjectName, 
       ObjectList.SchemaName, 
       Permission.state_desc,  
       CASE WHEN Grantee.is_fixed_role = 0 AND Grantee.name <> ''dbo'' THEN ' + NCHAR(13) + 
    CASE WHEN @DBName = 'All' THEN N'   ''USE '' + QUOTENAME(@AllDBNames) + ''; '' + ' + NCHAR(13) ELSE N'' END + 
    N'   ''REVOKE '' + 
       CASE WHEN Permission.[state]  = ''W'' THEN ''GRANT OPTION FOR '' ELSE '''' END + 
       '' '' + Permission.permission_name' + @Collation + N' +  
           CASE WHEN Permission.major_id <> 0 THEN '' ON '' + 
               ObjectList.class + ''::'' +  
               ISNULL(QUOTENAME(ObjectList.SchemaName),'''') + 
               CASE WHEN ObjectList.SchemaName + ObjectList.name IS NULL THEN '''' ELSE ''.'' END + 
               ISNULL(QUOTENAME(ObjectList.name),'''') + ISNULL('' (''+ QUOTENAME(Columns.name) + '')'','''') 
               ' + @Collation + ' + '' '' ELSE '''' END + 
           '' FROM '' + QUOTENAME(' + ISNULL('N'+QUOTENAME(@CopyTo,''''),'Grantee.name') + '' + @Collation + N')  + ''; '' END AS RevokeScript, 
       CASE WHEN Grantee.is_fixed_role = 0 AND Grantee.name <> ''dbo'' THEN ' + NCHAR(13) + 
    CASE WHEN @DBName = 'All' THEN N'   ''USE '' + QUOTENAME(@AllDBNames) + ''; '' + ' + NCHAR(13) ELSE N'' END + 
    N'   CASE WHEN Permission.[state]  = ''W'' THEN ''GRANT'' ELSE Permission.state_desc' + @Collation + 
            N' END + 
           '' '' + Permission.permission_name' + @Collation + N' + 
           CASE WHEN Permission.major_id <> 0 THEN '' ON '' + 
               ObjectList.class + ''::'' +  
               ISNULL(QUOTENAME(ObjectList.SchemaName),'''') + 
               CASE WHEN ObjectList.SchemaName + ObjectList.name IS NULL THEN '''' ELSE ''.'' END + 
               ISNULL(QUOTENAME(ObjectList.name),'''') + ISNULL('' (''+ QUOTENAME(Columns.name) + '')'','''') 
               ' + @Collation + N' + '' '' ELSE '''' END + 
           '' TO '' + QUOTENAME(' + ISNULL('N'+QUOTENAME(@CopyTo,''''),'Grantee.name') + '' + @Collation + N')  + '' '' +  
           CASE WHEN Permission.[state]  = ''W'' THEN '' WITH GRANT OPTION '' ELSE '''' END +  
           '' AS ''+ QUOTENAME(Grantor.name' + @Collation + N')+'';'' END AS GrantScript 
    FROM sys.database_permissions Permission 
    JOIN sys.database_principals Grantee 
       ON Permission.grantee_principal_id = Grantee.principal_id 
    JOIN sys.database_principals Grantor 
       ON Permission.grantor_principal_id = Grantor.principal_id 
    LEFT OUTER JOIN ObjectList 
       ON Permission.major_id = ObjectList.id 
       AND Permission.class_desc = ObjectList.class_desc 
    LEFT OUTER JOIN sys.columns AS Columns 
       ON Permission.major_id = Columns.object_id 
       AND Permission.minor_id = Columns.column_id 
    WHERE 1=1 '
    
IF LEN(ISNULL(@Principal,@Role)) > 0
    IF @Print = 1
        SET @sql = @sql + NCHAR(13) + N'  AND Grantee.name ' + @LikeOperator + N' N' + ISNULL(QUOTENAME(@Principal,''''),QUOTENAME(@Role,'''')) 
    ELSE
        SET @sql = @sql + NCHAR(13) + N'  AND Grantee.name ' + @LikeOperator + N' ISNULL(@Principal,@Role) '
            
IF LEN(@Type) > 0
    IF @Print = 1
        SET @sql = @sql + NCHAR(13) + N'  AND Grantee.type ' + @LikeOperator + N' N' + QUOTENAME(@Type,'''')
    ELSE
        SET @sql = @sql + NCHAR(13) + N'  AND Grantee.type ' + @LikeOperator + N' @Type'
    
IF LEN(@ObjectName) > 0
    IF @Print = 1
        SET @sql = @sql + NCHAR(13) + N'  AND ObjectList.name ' + @LikeOperator + N' N' + QUOTENAME(@ObjectName,'''') 
    ELSE
        SET @sql = @sql + NCHAR(13) + N'  AND ObjectList.name ' + @LikeOperator + N' @ObjectName '
    
IF LEN(@Permission) > 0
    IF @Print = 1
        SET @sql = @sql + NCHAR(13) + N'  AND Permission.permission_name ' + @LikeOperator + N' N' + QUOTENAME(@Permission,'''')
    ELSE
        SET @sql = @sql + NCHAR(13) + N'  AND Permission.permission_name ' + @LikeOperator + N' @Permission'
  
IF LEN(@LoginName) > 0
    BEGIN
        SET @sql = @sql + NCHAR(13) + 
        N'   AND EXISTS (SELECT 1 
                       FROM sys.server_principals SrvPrincipals 
                       WHERE SrvPrincipals.sid = Grantee.sid 
                         AND Grantee.sid NOT IN (0x00, 0x01) 
                         AND Grantee.type NOT IN (''R'') ' + NCHAR(13) 
        IF @Print = 1
            SET @sql = @sql + NCHAR(13) + N'  AND SrvPrincipals.name ' + @LikeOperator + N' N' + QUOTENAME(@LoginName,'''')
        ELSE
            SET @sql = @sql + NCHAR(13) + N'  AND SrvPrincipals.name ' + @LikeOperator + N' @LoginName'
  
        SET @sql = @sql + ')'
    END

IF @IncludeMSShipped = 0
    SET @sql = @sql + NCHAR(13) + N'  AND Grantee.is_fixed_role = 0 ' + NCHAR(13) + 
                '  AND Grantee.name NOT IN (''dbo'',''public'',''INFORMATION_SCHEMA'',''guest'',''sys'') '
  
IF @Print = 1
    BEGIN
        PRINT '-- Database & object Permissions' 
        PRINT CAST(@use AS nvarchar(max))
        PRINT CAST(@ObjectList AS nvarchar(max))
        PRINT CAST(@ObjectList2 AS nvarchar(max))
        PRINT CAST(@sql AS nvarchar(max))
    END
ELSE
BEGIN
    IF object_id('tempdb..##DBPermissions') IS NOT NULL
        DROP TABLE ##DBPermissions

    -- Create temp table to store the data in
    CREATE TABLE ##DBPermissions (
        DBName sysname NULL,
        GranteePrincipalId int NULL,
        GranteeName sysname NULL,
        GrantorName sysname NULL,
        class_desc nvarchar(60) NULL,
        permission_name nvarchar(128) NULL,
        ObjectName sysname NULL,
        SchemaName sysname NULL,
        state_desc nvarchar(60) NULL,
        RevokeScript nvarchar(max) NULL,
        GrantScript nvarchar(max) NULL
        )
    
    -- Add insert statement to @sql
    SET @sql =  @use + @ObjectList + @ObjectList2 +
                N'INSERT INTO ##DBPermissions ' + NCHAR(13) + 
                @sql
    
    IF @DBName = 'All'
        BEGIN
            -- Declare a READ_ONLY cursor to loop through the databases
            DECLARE cur_DBList CURSOR
            READ_ONLY
            FOR SELECT name FROM sys.databases 
            WHERE state IN (0,5)
              AND source_database_id IS NULL
            ORDER BY name
    
            OPEN cur_DBList
    
            FETCH NEXT FROM cur_DBList INTO @AllDBNames
            WHILE (@@fetch_status <> -1)
            BEGIN
                IF (@@fetch_status <> -2)
                BEGIN
                    SET @sql2 = 'USE ' + QUOTENAME(@AllDBNames) + ';' + NCHAR(13) + @sql
                    EXEC sp_executesql @sql2, 
                        N'@Principal sysname, @Role sysname, @Type nvarchar(30), @ObjectName sysname, 
                            @AllDBNames sysname, @Permission sysname, @LoginName sysname', 
                        @Principal, @Role, @Type, @ObjectName, @AllDBNames, @Permission, @LoginName
                    -- PRINT @sql2
                END
                FETCH NEXT FROM cur_DBList INTO @AllDBNames
            END
    
            CLOSE cur_DBList
            DEALLOCATE cur_DBList
        END
    ELSE
        BEGIN
            EXEC sp_executesql @sql, N'@Principal sysname, @Role sysname, @Type nvarchar(30), 
                @ObjectName sysname, @Permission sysname, @LoginName sysname', 
                @Principal, @Role, @Type, @ObjectName, @Permission, @LoginName
        END
END
END

IF @Print <> 1
IF (SERVERPROPERTY('ProductVersion') >= '12' AND @ShowOrphans = 1)
    IF @Output IN ('CreateOnly', 'DropOnly', 'ScriptOnly')
        SELECT DropScript, CreateScript, CreateLogin, AlterUser
        FROM ##DBPrincipals ORDER BY DBName, DBPrincipal
    ELSE
        SELECT DBName, DBPrincipal, SrvPrincipal, type, type_desc, default_schema_name, 
                create_date, modify_date, is_fixed_role, RoleAuthorization, sid, 
                DropScript, CreateScript, CreateLogin, AlterUser
        FROM ##DBPrincipals ORDER BY DBName, DBPrincipal
ELSE
BEGIN
    IF @Output = 'None'
        PRINT ''
    ELSE IF @Output = 'CreateOnly'
    BEGIN
        SELECT CreateScript FROM ##DBPrincipals WHERE CreateScript IS NOT NULL
        UNION ALL
        SELECT AddScript FROM ##DBRoles WHERE AddScript IS NOT NULL
        UNION ALL
        SELECT GrantScript FROM ##DBPermissions WHERE GrantScript IS NOT NULL
    END 
    ELSE IF @Output = 'DropOnly' 
    BEGIN
        SELECT DropScript FROM ##DBPrincipals WHERE DropScript IS NOT NULL
        UNION ALL
        SELECT DropScript FROM ##DBRoles WHERE DropScript IS NOT NULL
        UNION ALL
        SELECT RevokeScript FROM ##DBPermissions WHERE RevokeScript IS NOT NULL
    END
    ELSE IF @Output = 'ScriptOnly' 
    BEGIN
        SELECT DropScript, CreateScript FROM ##DBPrincipals WHERE DropScript IS NOT NULL OR CreateScript IS NOT NULL
        UNION ALL
        SELECT DropScript, AddScript FROM ##DBRoles WHERE DropScript IS NOT NULL OR AddScript IS NOT NULL
        UNION ALL
        SELECT RevokeScript, GrantScript FROM ##DBPermissions WHERE RevokeScript IS NOT NULL OR GrantScript IS NOT NULL
    END
    ELSE IF @Output = 'Report'
    BEGIN
        SELECT DBName, DBPrincipal, SrvPrincipal, type, type_desc,
                STUFF((SELECT N', ' + ##DBRoles.RoleName
                        FROM ##DBRoles
                        WHERE ##DBPrincipals.DBName = ##DBRoles.DBName
                          AND ##DBPrincipals.DBPrincipalId = ##DBRoles.UserPrincipalId
                        ORDER BY ##DBRoles.RoleName
                        FOR XML PATH(''),TYPE).value('.','NVARCHAR(MAX)')
                    , 1, 2, '') AS RoleMembership,
                STUFF((SELECT N', ' + ##DBPermissions.state_desc + N' ' + ##DBPermissions.permission_name + N' on ' + 
                        COALESCE(N'OBJECT:'+##DBPermissions.SchemaName + N'.' + ##DBPermissions.ObjectName, 
                                N'SCHEMA:'+##DBPermissions.SchemaName,
                                N'DATABASE:'+##DBPermissions.DBName)
                        FROM ##DBPermissions
                        WHERE ##DBPrincipals.DBName = ##DBPermissions.DBName
                          AND ##DBPrincipals.DBPrincipalId = ##DBPermissions.GranteePrincipalId
                        ORDER BY ##DBPermissions.state_desc, ISNULL(##DBPermissions.ObjectName, ##DBPermissions.DBName), ##DBPermissions.permission_name
                        FOR XML PATH(''),TYPE).value('.','NVARCHAR(MAX)')
                    , 1, 2, '') AS DirectPermissions
        FROM ##DBPrincipals
        ORDER BY DBName, type, DBPrincipal
    END
    ELSE -- 'Default' or no match
    BEGIN
        SELECT DBName, DBPrincipal, SrvPrincipal, type, type_desc, default_schema_name, 
                create_date, modify_date, is_fixed_role, RoleAuthorization, sid, 
                DropScript, CreateScript
        FROM ##DBPrincipals ORDER BY DBName, DBPrincipal
        IF LEN(@Role) > 0
            SELECT DBName, UserName, RoleName, DropScript, AddScript 
            FROM ##DBRoles ORDER BY DBName, RoleName, UserName
        ELSE
            SELECT DBName, UserName, RoleName, DropScript, AddScript 
            FROM ##DBRoles ORDER BY DBName, UserName, RoleName

        IF LEN(@ObjectName) > 0
            SELECT DBName, GranteeName, GrantorName, class_desc, permission_name, ObjectName, 
                SchemaName, state_desc, RevokeScript, GrantScript 
            FROM ##DBPermissions ORDER BY DBName, SchemaName, ObjectName, GranteeName, permission_name
        ELSE
            SELECT DBName, GranteeName, GrantorName, class_desc, permission_name, ObjectName, 
                SchemaName, state_desc, RevokeScript, GrantScript 
            FROM ##DBPermissions ORDER BY DBName, GranteeName, SchemaName, ObjectName, permission_name
    END

    IF @DropTempTables = 1
    BEGIN
        DROP TABLE ##DBPrincipals
        DROP TABLE ##DBRoles
        DROP TABLE ##DBPermissions
    END
END
GO
