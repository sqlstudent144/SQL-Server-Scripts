SET NOEXEC ON
-- SET NOEXEC OFF
select @@version

instancedefaultpath, iscatalogupdateallowed, masterfile
errorlogfilename, instancedefaultdatapath, instancedefaultlogpath
SELECT SERVERPROPERTY('iscatalogupdateallowed' ) AS iscatalogupdateallowed 
	  ,SERVERPROPERTY('masterfile'             ) AS masterfile			  
	  ,SERVERPROPERTY('errorlogfilename'       ) AS errorlogfilename		  
	  ,SERVERPROPERTY('instancedefaultpath'    ) AS instancedefaultpath	  
	  ,SERVERPROPERTY('instancedefaultdatapath') AS instancedefaultdatapath
	  ,SERVERPROPERTY('instancedefaultlogpath' ) AS instancedefaultlogpath 

