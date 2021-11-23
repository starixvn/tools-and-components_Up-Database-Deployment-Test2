/*<info serverAlias="NexOps-Up_DeploymentTest" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[SpmAliasServer_Insert]
	@AliasServerId INT=NULL OUTPUT
	,@Name VARCHAR(50)
	
	,@DbServers VARCHAR(500)=NULL	
	,@DatabaseIds VARCHAR(2000)=NULL
	,@DbServerBackup VARCHAR(5000)=NULL
	
	,@Description NVARCHAR(200)=NULL
	,@IsActive BIT=0
	,@CreatedBy INT=NULL
	
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
AS
/*
Created: 20150318@Josh.Phan
Task: Insert Alias Server.
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
	DECLARE @Data NVARCHAR(MAX)

	IF EXISTS (SELECT 1
		FROM [dbo].[SpmAliasServer] WITH (NOLOCK)
		WHERE [Name] = @Name AND IsDeleted = 0)
	
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

	SET XACT_ABORT ON
	BEGIN TRAN
	BEGIN TRY
		INSERT INTO [dbo].[SpmAliasServer]
			([Name]
			 ,[Description]
			 ,[IsActive]
			 ,[ModifiedBy]
			 ,[ModifiedDate])	
		VALUES (
			@Name
			,@Description
			,@IsActive
			,@CreatedBy
			,GETDATE())		
	
		SELECT @AliasServerId = CAST(SCOPE_IDENTITY() AS INT)
		
		IF ISNULL(@DatabaseIds,'') <> ''
		BEGIN
			INSERT INTO #Database(DatabaseId)
			SELECT DISTINCT val FROM fnc_strSplit (@DatabaseIds, ',')
		END	
			
		IF ISNULL(@DatabaseIds,'') <> ''
		BEGIN
			INSERT INTO [dbo].[SpmAliasServerDatabase]
				([AliasServerId]
				,[DatabaseId])
			SELECT DISTINCT
				@AliasServerId
				,[DatabaseId]
			FROM #Database AS db	
		END
	
		IF ISNULL(@DbServers, '') <> ''	
		BEGIN
			EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@DbServers

			INSERT INTO [dbo].[SpmAliasServerEnvironment] (
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
	
		IF ISNULL(@DbServerBackup, '') <> ''	
		BEGIN
			EXEC sp_xml_preparedocument @DocHandler OUTPUT
				,@DbServerBackup

			INSERT INTO [dbo].[SpmAliasServerDatabaseBackup] (
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
		END

		EXEC @Data = [dbo].[fncGetDataForWriteLog] @ObjectId = @AliasServerId, @ObjectType = 4
		EXEC dbo.SpmLog_Insert @UserId = @CreatedBy, @SpName = 'SpmAliasServer_Insert', @ObjectId = @AliasServerId, @ObjectTypeId = 4, @Data = @Data, @OldData = NULL
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

	DROP TABLE #Database
END

GO


