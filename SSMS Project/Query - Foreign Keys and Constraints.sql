SELECT 'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id)) + '.' + QUOTENAME(OBJECT_NAME(parent_object_id)) + 
	' WITH CHECK CHECK CONSTRAINT ' + quotename(name)
FROM sys.foreign_keys
WHERE is_not_trusted = 1


SELECT
'ALTER TABLE ' 
   + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) 
   + ' DROP CONSTRAINT ' + QUOTENAME(fk.name) 
FROM sys.foreign_keys AS fk
INNER JOIN sys.tables AS rt -- referenced table
  ON fk.referenced_object_id = rt.[object_id]
INNER JOIN sys.schemas AS rs 
  ON rt.[schema_id] = rs.[schema_id]
INNER JOIN sys.tables AS ct -- constraint table
  ON fk.parent_object_id = ct.[object_id]
INNER JOIN sys.schemas AS cs 
  ON ct.[schema_id] = cs.[schema_id]
WHERE rt.is_ms_shipped = 0 AND ct.is_ms_shipped = 0;


SELECT
'ALTER TABLE ' 
   + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) 
   + ' ADD CONSTRAINT ' + QUOTENAME(fk.name) 
   + ' FOREIGN KEY (' + STUFF((SELECT ',' + QUOTENAME(c.name)
			   -- get all the columns in the constraint table
				FROM sys.columns AS c 
				INNER JOIN sys.foreign_key_columns AS fkc 
				ON fkc.parent_column_id = c.column_id
				AND fkc.parent_object_id = c.[object_id]
				WHERE fkc.constraint_object_id = fk.[object_id]
				ORDER BY fkc.constraint_column_id 
				FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'')
  + ') REFERENCES ' + QUOTENAME(rs.name) + '.' + QUOTENAME(rt.name)
  + '(' + STUFF((SELECT ',' + QUOTENAME(c.name)
		   -- get all the referenced columns
			FROM sys.columns AS c 
			INNER JOIN sys.foreign_key_columns AS fkc 
			ON fkc.referenced_column_id = c.column_id
			AND fkc.referenced_object_id = c.[object_id]
			WHERE fkc.constraint_object_id = fk.[object_id]
			ORDER BY fkc.constraint_column_id 
			FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') + '); '+char(13)++char(10)+'GO'
FROM sys.foreign_keys AS fk
INNER JOIN sys.tables AS rt -- referenced table
  ON fk.referenced_object_id = rt.[object_id]
INNER JOIN sys.schemas AS rs 
  ON rt.[schema_id] = rs.[schema_id]
INNER JOIN sys.tables AS ct -- constraint table
  ON fk.parent_object_id = ct.[object_id]
INNER JOIN sys.schemas AS cs 
  ON ct.[schema_id] = cs.[schema_id]
WHERE rt.is_ms_shipped = 0 AND ct.is_ms_shipped = 0;




SELECT
	QUOTENAME(cs.name) Schema_Name
	, QUOTENAME(ct.name) Table_Name 
	, QUOTENAME(fk.name) Constraint_Name
   , STUFF((SELECT ',' + QUOTENAME(c.name)
			   -- get all the columns in the constraint table
				FROM sys.columns AS c 
				INNER JOIN sys.foreign_key_columns AS fkc 
				ON fkc.parent_column_id = c.column_id
				AND fkc.parent_object_id = c.[object_id]
				WHERE fkc.constraint_object_id = fk.[object_id]
				ORDER BY fkc.constraint_column_id 
				FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') Column_List
	, QUOTENAME(rs.name) Ref_Schema_Name
	, QUOTENAME(rt.name) Ref_Table_Name
	, STUFF((SELECT ',' + QUOTENAME(c.name)
		   -- get all the referenced columns
			FROM sys.columns AS c 
			INNER JOIN sys.foreign_key_columns AS fkc 
			ON fkc.referenced_column_id = c.column_id
			AND fkc.referenced_object_id = c.[object_id]
			WHERE fkc.constraint_object_id = fk.[object_id]
			ORDER BY fkc.constraint_column_id 
			FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') Ref_Column_list
FROM sys.foreign_keys AS fk
INNER JOIN sys.tables AS rt -- referenced table
  ON fk.referenced_object_id = rt.[object_id]
INNER JOIN sys.schemas AS rs 
  ON rt.[schema_id] = rs.[schema_id]
INNER JOIN sys.tables AS ct -- constraint table
  ON fk.parent_object_id = ct.[object_id]
INNER JOIN sys.schemas AS cs 
  ON ct.[schema_id] = cs.[schema_id]
WHERE rt.is_ms_shipped = 0 AND ct.is_ms_shipped = 0
  AND (ct.name = 'triggers' or rt.name = 'triggers')
