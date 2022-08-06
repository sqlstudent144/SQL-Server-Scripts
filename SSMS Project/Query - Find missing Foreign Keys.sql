-- Don't think this is mine but I can't remember where I got it from.
WITH pkColumns AS 
	(SELECT o.name AS TableName, i.name AS IndexName, c.name AS ColumnName
	FROM sys.indexes i
	JOIN sys.index_columns ic
		ON i.object_id = ic.object_id
		AND i.index_id = ic.index_id
	JOIN sys.columns c
		ON ic.object_id = c.object_id
		AND ic.column_id = c.column_id
	JOIN sys.objects o
		ON i.object_id = o.object_id
	WHERE i.is_primary_key = 1),
	nonpkColumns AS
	(SELECT o.name AS TableName, c.name AS ColumnName
	FROM sys.objects o
	JOIN sys.columns c
		ON o.object_id = c.object_id
	JOIN pkColumns pk
		ON pk.TableName <> o.name
		AND pk.ColumnName = c.name
	),
	fkColumns AS
	(SELECT name AS ForeignKey_Name,
		object_schema_name(referenced_object_id) Parent_Schema_Name,
		object_name(referenced_object_id) Parent_Object_Name,
		object_schema_name(parent_object_id) Child_Schema_Name,
		object_name(parent_object_id) Child_Object_Name,
		is_disabled, is_not_trusted,
		'ALTER TABLE ' + quotename(object_schema_name(parent_object_id)) + '.' +
				   quotename(object_name(parent_object_id)) + ' NOCHECK CONSTRAINT ' + 
				   object_name(object_id) + '; ' AS Disable,
		'ALTER TABLE ' + quotename(object_schema_name(parent_object_id)) + '.' +
				   quotename(object_name(parent_object_id)) + ' WITH CHECK CHECK CONSTRAINT ' + 
				   object_name(object_id) + '; ' AS Enable
	FROM sys.foreign_keys )
SELECT nPK.*, PK.TableName,
	'ALTER TABLE ' + nPK.TableName + ' ADD CONSTRAINT fk_' +nPK.TableName + '_' + nPK.ColumnName + ' FOREIGN KEY (' + nPK.ColumnName+') REFERENCES '+PK.TableName+'('+nPK.ColumnName+')'

FROM nonpkColumns nPK
JOIN pkColumns PK
	ON nPK.ColumnName = PK.ColumnName
WHERE --PK.ColumnName = 'CaseId' AND
	NOT EXISTS (SELECT * FROM fkColumns fkC
				WHERE PK.TableName = fkC.Parent_Object_Name
				  AND nPK.TableName = fkC.Child_Object_Name)
  AND PK.TableName <> 'dtproperties'

