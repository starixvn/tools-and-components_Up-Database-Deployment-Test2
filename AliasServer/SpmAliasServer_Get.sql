/*<info serverAlias="NexOps-Up_DeploymentTest" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[SpmAliasServer_Get]
	@DBServerIds VARCHAR(MAX)=NULL,
	@DatabaseIds VARCHAR(MAX)=NULL,
	@IsActive BIT=0 
AS
/*
Created: 20150318@Josh.Phan
Task: Get Alias Server.
DB: SPM
Original: 

Revisions:  
Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON;
	
    IF OBJECT_ID('tempdb..#DBServer') IS NOT NULL
	   BEGIN
		  DROP TABLE #DBServer
	   END 

    CREATE TABLE #DBServer (
	   DBServerId  SMALLINT)

    IF ISNULL(@DBServerIds,'') <> ''
    BEGIN
	   INSERT INTO #DBServer (
		  DBServerId )
	   SELECT DISTINCT val FROM fnc_strSplit (@DBServerIds, ',')
    END	
	
    IF OBJECT_ID('tempdb..#Database') IS NOT NULL 
	   BEGIN
		  DROP TABLE #Database
	   END 

    CREATE TABLE #Database (
	   DatabaseId  SMALLINT)

    IF ISNULL(@DatabaseIds,'') <> ''
    BEGIN
	   INSERT INTO #Database (
		  DatabaseId )
	   SELECT DISTINCT val FROM fnc_strSplit (@DatabaseIds, ',')
    END
    
    IF OBJECT_ID('tempdb..#tblAliasServer') IS NOT NULL 
    BEGIN
	   DROP TABLE #tblAliasServer
    END 

    CREATE TABLE #tblAliasServer (
	   AliasServerId  INT,
	   Name VARCHAR(100),
	   [Description] NVARCHAR(2000),
	   IsActive BIT,
	   ModifiedBy INT,
	   ModifiedDate DATETIME
    )	
    
    INSERT INTO #tblAliasServer
    (
        AliasServerId,
        Name,
        [Description],
        IsActive,
        ModifiedBy,
        ModifiedDate
    )    
    SELECT DISTINCT
	   ali.[AliasServerId]
	   ,ali.[Name]
	   ,ali.[Description]
	   ,ali.[IsActive]
	   ,ali.[ModifiedBy]
	   ,ali.[ModifiedDate]
    FROM [dbo].[SpmAliasServer] AS ali WITH (NOLOCK)
	   LEFT JOIN [dbo].[SpmAliasServerEnvironment] AS aev WITH (NOLOCK) 
		  ON ali.[AliasServerId] = aev.[AliasServerId]
	   LEFT JOIN dbo.SpmDbServer AS ds WITH(NOLOCK)
		  ON ds.DbServerId = aev.DbServerId
			 AND ds.IsDeleted = 0
	   INNER JOIN dbo.SpmAliasServerDatabase AS aliasDb WITH(NOLOCK)
		  ON aliasDb.AliasServerId = ali.AliasServerId
	   INNER JOIN dbo.SpmDatabase AS db WITH(NOLOCK)
		  ON db.DatabaseId = aliasDb.DatabaseId
			 AND db.IsDeleted = 0
    WHERE ali.IsDeleted = 0
	   AND (
		  @IsActive IS NULL 
		  OR ali.[IsActive] = @IsActive
	   )
	   AND (
		  ISNULL(@DBServerIds,'') = '' 
		  OR ds.DbServerId IN (SELECT DBServerId FROM #DBServer)
	   )
	   AND (
		  ISNULL(@DatabaseIds,'') = '' 
		  OR db.DatabaseId IN (SELECT DatabaseId FROM #Database)
	   )	   
    ORDER BY ali.[Name]
    
    SELECT AliasServerId,
        Name,
        [Description],
        IsActive,
        ModifiedBy,
        ModifiedDate
    FROM #tblAliasServer
    	
    SELECT alias.[AliasServerId]
	   ,aev.[EnvironmentId] 
	   ,aev.[DbServerId]	
	   ,dbSer.[Name] AS DbServerName
    FROM #tblAliasServer AS alias
	   INNER JOIN [dbo].[SpmAliasServerEnvironment] AS aev WITH (NOLOCK)
		  ON alias.[AliasServerId] = aev.[AliasServerId]
	   INNER JOIN [dbo].[SpmDbServer] AS dbSer WITH (NOLOCK) 
		  ON aev.[DbServerId] = dbSer.[DbServerId]
			 AND dbSer.IsDeleted = 0   
	
    SELECT aliBack.[AliasServerId]
	   ,aliBack.[DbServerId]
	   ,aliBack.[DatabaseId]
	   ,aliBack.[EnvironmentId]
	   ,aliBack.[DBServerBackupId]
    FROM [dbo].[SpmAliasServerDatabaseBackup] AS aliBack WITH (NOLOCK)	
	   INNER JOIN #tblAliasServer AS alias 
		  ON aliBack.[AliasServerId] = alias.[AliasServerId]   
	
    SELECT 
	   alDb.[AliasServerId]
	   ,alDb.[DatabaseId]
	   ,db.[Name]
    FROM [dbo].[SpmAliasServerDatabase] AS alDb WITH (NOLOCK)
	   INNER JOIN #tblAliasServer AS alias 
		  ON alDb.[AliasServerId] = alias.[AliasServerId]
	   INNER JOIN [dbo].[SpmDatabase] AS db WITH (NOLOCK) 
		  ON alDb.[DatabaseId] = db.[DatabaseId]    
		
    DROP TABLE #DBServer
    DROP TABLE #Database
    DROP TABLE #tblAliasServer
END

GO


