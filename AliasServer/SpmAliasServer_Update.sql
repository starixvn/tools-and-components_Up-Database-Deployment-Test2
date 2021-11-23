/*<info serverAlias="NexOps-Up_DeploymentTest" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[SpmAliasServer_Update]
	@AliasServerId INT
	,@Name VARCHAR(50)
	,@DbServers VARCHAR(5000)=NULL	
	,@DatabaseIds VARCHAR(200)=NULL
	,@DbServerBackup VARCHAR(5000)=NULL
	,@Description NVARCHAR(2000)=NULL
	,@IsActive BIT=0
	,@ModifiedBy INT=NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150318@Josh.Phan
Task: Edit Alias Server.
DB: SPM
Original: 

Revisions:  
Param's Explanation:
	@DbServers = <ROOT>
						<DbServer DbServerId="1" EnvironmentId="1"></DbServer>
						<DbServer DbServerId="2" EnvironmentId="2"></DbServer>
					</ROOT>
	@DbServerBackup = <ROOT><DbServerBackup DbServerId="1" EnvironmentId="4" DbServerBackupId="2" DatabaseId="1"></DbServerBackup></ROOT>
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @DocHandler INT
	DECLARE @Data NVARCHAR(MAX), @OldData NVARCHAR(MAX)

	IF @IsActive = 0 AND EXISTS(SELECT 1
	     FROM [dbo].[SpmStoredProcedure] AS st WITH (NOLOCK)
	     WHERE st.AliasServerId = @AliasServerId
	        AND st.[IsDeleted] = 0
			AND st.IsActive = 1)
	BEGIN
	     SELECT @ErrCode = 100
	           ,@ErrMsg = 'You can not deactivate this Alias because it is being used by one or more Stored Procedure.'
	     RETURN
	END

	IF EXISTS(SELECT 1
		FROM [dbo].[SpmAliasServer] WITH (NOLOCK)
		WHERE [AliasServerId] <> @AliasServerId AND [Name] = @Name AND IsDeleted = 0)
	
	BEGIN
		SELECT @ErrCode = 100
			,@ErrMsg = 'Alias Server ''' + @Name + ''' has already existed. Please try again.'
		RETURN
	END

	IF OBJECT_ID('tempdb..#Database') IS NOT NULL
	BEGIN
		DROP TABLE #Database
	END 

	CREATE TABLE #Database (DatabaseId  SMALLINT)
	IF ISNULL(@DatabaseIds,'') <> ''
	BEGIN
		INSERT INTO #Database(DatabaseId)
		SELECT DISTINCT val FROM fnc_strSplit (@DatabaseIds, ',')
	END	
	
	IF OBJECT_ID('tempdb..#DbServer') IS NOT NULL
	BEGIN
		DROP TABLE #DbServer
	END 

	CREATE TABLE #DbServer ([AliasServerId] INT
			,[EnvironmentId] INT
			,[DbServerId] INT)

	IF ISNULL(@DbServers, '') <> ''	
	BEGIN
		EXEC sp_xml_preparedocument @DocHandler OUTPUT
			,@DbServers

		INSERT INTO #DbServer(
			[AliasServerId]
			,[EnvironmentId]
			,[DbServerId])
		SELECT 
			@AliasServerId
			,EnvironmentId
			,DbServerId
		FROM OPENXML(@DocHandler, '/ROOT/DbServer', 1) 
		WITH (EnvironmentId INT
				,DbServerId INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END

	IF (@IsActive = 1 AND (EXISTS (SELECT 1
			 FROM [dbo].[SpmDbServer] AS sv WITH (NOLOCK)
			 INNER JOIN #DbServer AS tmpsv ON sv.DbServerId = tmpsv.DbServerId
			 WHERE sv.IsActive = 0)
		OR EXISTS (SELECT 1 FROM [dbo].[SpmDatabase] AS db WITH (NOLOCK)
			INNER JOIN #Database AS tmpdb ON db.DatabaseId = tmpdb.DatabaseId
			WHERE db.IsActive = 0)))
	BEGIN
	     SELECT @ErrCode = 100
	           ,@ErrMsg = 'You can not activate this Alias because DB Server or Database are been deactivate.'
	     RETURN
	END

	IF OBJECT_ID('tempdb..#DbServerBackup') IS NOT NULL
	BEGIN
		DROP TABLE #DbServerBackup
	END 
	
	CREATE TABLE #DbServerBackup (
		Id INT IDENTITY(1,1)
		,AliasServerId INT
		,DbServerId INT
		,DatabaseId INT
		,EnvironmentId INT
		,DbServerBackupId INT)

	EXEC @OldData = [dbo].[fncGetDataForWriteLog] @ObjectId = @AliasServerId, @ObjectType = 4

	SET XACT_ABORT ON
	BEGIN TRAN
	BEGIN TRY
		UPDATE [dbo].[SpmAliasServer] WITH (ROWLOCK,UPDLOCK)
		SET [Name] = @Name
			,[Description] = @Description
			,[IsActive] = @IsActive
			,[ModifiedBy] = @ModifiedBy
			,[ModifiedDate] = GETDATE()
		WHERE [AliasServerId] = @AliasServerId	

		DELETE FROM [dbo].[SpmAliasServerDatabase] WHERE [AliasServerId] = @AliasServerId 		
	
		INSERT INTO [dbo].[SpmAliasServerDatabase]
			([AliasServerId]
			,[DatabaseId])
		SELECT DISTINCT
			@AliasServerId
			,[DatabaseId]
		FROM #Database AS db		

		IF ISNULL(@DbServers, '') <> ''	
		BEGIN
			DELETE FROM [dbo].[SpmAliasServerEnvironment] WHERE [AliasServerId] = @AliasServerId
			INSERT INTO [dbo].[SpmAliasServerEnvironment] (
				[AliasServerId]
				,[EnvironmentId]
				,[DbServerId])
			SELECT 
				@AliasServerId
				,EnvironmentId
				,DbServerId
			FROM #DbServer
		END
	
		IF ISNULL(@DbServerBackup, '') <> ''	
		BEGIN
			EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@DbServerBackup

			INSERT INTO #DbServerBackup (
				[AliasServerId]
				,[DbServerId]
				,[DatabaseId]
				,[EnvironmentId]
				,[DbServerBackupId])
			SELECT 
				@AliasServerId
				,DbServerId
				,DatabaseId
				,EnvironmentId
				,DbServerBackupId
			FROM OPENXML(@DocHandler, '/ROOT/DbServerBackup', 1) 
			WITH (DbServerId INT
				  ,DatabaseId INT
				  ,EnvironmentId INT
				  ,DbServerBackupId INT) 
			AS Data

			EXEC sp_xml_removedocument @DocHandler
		
			DELETE ali FROM [dbo].[SpmAliasServerDatabaseBackup] AS ali
			WHERE [AliasServerId] = @AliasServerId AND NOT EXISTS (
						SELECT 1
						FROM #DbServerBackup WITH (NOLOCK)
						 WHERE [AliasServerId] = ali.[AliasServerId] AND ali.[DbServerId] = [DbServerId] AND ali.[DatabaseId] = [DatabaseId] 
							AND ali.[EnvironmentId] = [EnvironmentId] AND ali.[DBServerBackupId] = [DbServerBackupId])
						
			INSERT INTO [dbo].[SpmAliasServerDatabaseBackup](
				[AliasServerId]
				,[DbServerId]
				,[DatabaseId]
				,[EnvironmentId]
				,[DbServerBackupId])
			SELECT [AliasServerId]
				,[DbServerId]
				,[DatabaseId]
				,[EnvironmentId]
				,[DbServerBackupId]
			FROM #DbServerBackup AS ba
			WHERE [Id] NOT IN (
					SELECT baTemp.[Id]
					FROM #DbServerBackup AS baTemp
					 INNER JOIN [dbo].[SpmAliasServerDatabaseBackup] AS ali WITH (NOLOCK)
					 ON ali.[AliasServerId] = ba.[AliasServerId] AND ali.[DbServerId] = ba.[DbServerId] AND ali.[DatabaseId] = ba.[DatabaseId] 
							AND ali.[EnvironmentId] = ba.[EnvironmentId] AND ali.[DBServerBackupId] = ba.[DbServerBackupId])						
		END

		EXEC @Data = [dbo].[fncGetDataForWriteLog] @ObjectId = @AliasServerId, @ObjectType = 4
		EXEC dbo.SpmLog_Insert @UserId = @ModifiedBy, @SpName = 'SpmAliasServer_Update', @ObjectId = @AliasServerId, @ObjectTypeId = 4, @Data = @Data, @OldData = @OldData

		COMMIT
	END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
	       ROLLBACK
	       SELECT @ErrCode = 100
		      ,@ErrMsg = 'There is an error when updating Alias Server.'
	   END
    END CATCH

	DROP TABLE #DbServerBackup
	DROP TABLE #Database
END

GO


