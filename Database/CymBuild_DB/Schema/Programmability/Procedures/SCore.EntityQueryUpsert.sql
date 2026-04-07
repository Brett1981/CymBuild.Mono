SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[EntityQueryUpsert]
	(	@Name NVARCHAR(250),
		@RowStatus TINYINT,
		@Statement NVARCHAR(max),
		@EntityTypeGuid UNIQUEIDENTIFIER,
		@IsDefaultCreate BIT,
		@IsDefaultRead BIT,
		@IsDefaultUpdate BIT,
		@IsDefaultDelete BIT,
		@IsScalarExecute BIT,
		@IsDefaultValidation BIT,
		@EntityHoBTGuid UNIQUEIDENTIFIER,
		@IsDefaultDataPills BIT,
		@IsMergeDocumentQuery BIT,
		@IsProgressData BIT,
		@SchemaName NVARCHAR(255),
		@ObjectName NVARCHAR(255),
		@IsManualStatement BIT,
		@Guid UNIQUEIDENTIFIER OUT
	)
AS
BEGIN
	SET NOCOUNT ON 

	SET @SchemaName = LTRIM(RTRIM(@SchemaName))
	SET @ObjectName = LTRIM(RTRIM(@ObjectName))

	DECLARE @EntityTypeID INT,
			@EntityHoBTID INT;

	SELECT	@EntityTypeID = ID
	FROM	SCore.EntityTypes
	WHERE	(Guid = @EntityTypeGuid);

	SELECT	@EntityHoBTID = ID
	FROM	SCore.EntityHobts
	WHERE	(Guid = @EntityHoBTGuid);

	DECLARE @IsInsert BIT = 0;
	EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
								@SchemeName = N'SCore',			-- nvarchar(255)
								@ObjectName = N'EntityQueries', -- nvarchar(255)
								@IsInsert = @IsInsert OUTPUT;	-- bit

	DECLARE @Type		   CHAR(2),
			@EntityQueryId INT = -1;

	DECLARE @Parameters TABLE
		(
			Guid UNIQUEIDENTIFIER NOT NULL,
			Name NVARCHAR(255) NULL,
			TypeID INT NULL,
			EntityQueryID INT NULL,
			Is_Output BIT NULL,
			MappedEntityPropertyID INT NULL
		);

	-- Maintain the Query Text and Parameters 
	IF (@IsManualStatement = 0)
	BEGIN
		SELECT	@EntityQueryId = ID
		FROM	SCore.EntityQueries
		WHERE	(Guid = @Guid);

		SELECT	@Type = type
		FROM	sys.objects
		WHERE	(name					 = @ObjectName)
			AND (SCHEMA_NAME (schema_id) = @SchemaName);

		IF (@Type = 'TF')
		BEGIN
			INSERT	@Parameters
				 (Guid, Name, TypeID, EntityQueryID, Is_Output, MappedEntityPropertyID)
			SELECT		NEWID (),
						pp.name,
						datatype.ID		  AS TypeId,
						@EntityQueryId	  AS EntityQueryID,
						pp.is_output,
						mappedproperty.ID AS MappedEntityPropertyID
			FROM		sys.objects		AS o
			JOIN		sys.sql_modules AS m ON (m.object_id = o.object_id)
			JOIN		sys.parameters	AS pp ON (m.object_id = pp.object_id)
			JOIN		sys.types		AS t ON (pp.user_type_id = t.user_type_id)
			OUTER APPLY
						(
							SELECT	edt.ID
							FROM	SCore.EntityDataTypes AS edt
							WHERE	(
										(edt.Name	 = t.name)
									AND (t.name		 <> N'nvarchar')
									)
								 OR
								  (
									  (t.name		 = N'nvarchar')
								  AND (pp.max_length <> -1)
								  AND (edt.Name		 = N'nvarchar')
								  )
								 OR
								  (
									  (t.name		 = N'nvarchar')
								  AND (pp.max_length = -1)
								  AND (edt.Name		 = N'nvarchar(max)')
								  )
								 OR
								  (
									  (edt.Name		 = N'nvarchar')
								  AND (t.name		 = N'sysname')
								  )
								 OR
								  (
									  (edt.Name		 = N'double')
								  AND (t.name		 = N'decimal')
								  )
						)				AS datatype
			OUTER APPLY
						(
							SELECT		TOP (1) ep.ID
							FROM		SCore.EntityProperties AS ep
							JOIN		SCore.EntityHobts	   AS h ON (ep.EntityHoBTID = h.ID)
							WHERE		(ep.RowStatus			 = 1)
									AND (h.EntityTypeID			 = @EntityTypeID)
									AND
									  (
										  (N'@' + ep.Name		 = pp.name)
									   OR
										(
											(pp.name			 <> N'@Guid')
										AND (pp.name LIKE N'%Guid')
										AND (SUBSTRING (   pp.name,
														   0,
														   LEN (pp.name) - 3
													   ) + N'ID' = N'@' + ep.Name
											)
										)
									  )
							ORDER BY	ep.ID
						) AS mappedproperty
			WHERE		(SCHEMA_NAME (o.schema_id) = @SchemaName)
					AND (o.name					   = @ObjectName)
			ORDER BY	pp.parameter_id;
		END
		ELSE IF (@Type = 'P')
		BEGIN
			INSERT	@Parameters
				 (Guid, Name, TypeID, EntityQueryID, Is_Output, MappedEntityPropertyID)
			SELECT	NEWID (),
					pp.name,
					datatype.ID		  AS TypeId,
					@EntityQueryId	  AS EntityQueryID,
					pp.is_output,
					mappedproperty.ID AS MappedEntityPropertyID
			FROM	sys.procedures AS p
			JOIN	sys.parameters AS pp ON (p.object_id = pp.object_id)
			JOIN	sys.types	   AS t ON (pp.user_type_id = t.user_type_id)
			OUTER APPLY
					(
						SELECT	edt.ID
						FROM	SCore.EntityDataTypes AS edt
						WHERE	(
									(edt.Name	 = t.name)
								AND (t.name		 <> N'nvarchar')
								)
							 OR
							  (
								  (t.name		 = N'nvarchar')
							  AND (pp.max_length <> -1)
							  AND (edt.Name		 = N'nvarchar')
							  )
							 OR
							  (
								  (t.name		 = N'nvarchar')
							  AND (pp.max_length = -1)
							  AND (edt.Name		 = N'nvarchar(max)')
							  )
							 OR
							  (
								  (edt.Name		 = N'nvarchar')
							  AND (t.name		 = N'sysname')
							  )
							 OR
							  (
								  (edt.Name		 = N'double')
							  AND (t.name		 = N'decimal')
							  )
					)			   AS datatype
			OUTER APPLY
					(
						SELECT		TOP (1) ep.ID
						FROM		SCore.EntityProperties AS ep
						JOIN		SCore.EntityHobts	   AS h ON (ep.EntityHoBTID = h.ID)
						WHERE		(ep.RowStatus			 = 1)
								AND (h.EntityTypeID			 = @EntityTypeID)
								AND
								  (
									  (N'@' + ep.Name		 = pp.name)
								   OR
									(
										(pp.name			 <> N'@Guid')
									AND (pp.name LIKE N'%Guid')
									AND (SUBSTRING (   pp.name,
													   0,
													   LEN (pp.name) - 3
												   ) + N'ID' = N'@' + ep.Name
										)
									)
								  )
						ORDER BY	ep.ID
					) AS mappedproperty
			WHERE	(SCHEMA_NAME (p.schema_id) = @SchemaName)
				AND (p.name					   = @ObjectName);
		END;

		DECLARE @ParameterList NVARCHAR(MAX);

		IF (@Type = N'TF')
		BEGIN
			SELECT	@ParameterList = STUFF (
										 (
											 SELECT N', ' + p.Name
											 FROM	@Parameters AS p
											 FOR XML PATH ('')
										 ),
										 1,
										 1,
										 ''
										   );

			SET @Statement = N'SELECT * FROM [' + @SchemaName + N'].[' + @ObjectName + N'] (' + @ParameterList
							 + N') root_hobt';
		END;
		ELSE IF (@Type = 'U') OR (@Type = 'V')
		BEGIN 
			SELECT	@ParameterList = STUFF (
										(
											SELECT	N','  + CHAR(10) + CHAR(9) + CASE ep.DropDownListDefinitionID 
																WHEN -1 THEN N'root_hobt.' + ep.Name
																ELSE N'[' + CONVERT(NVARCHAR(MAX), ep.Guid) + '].Guid AS ' + ep.Name
															END
											FROM	SCore.EntityProperties AS ep
											JOIN	SCore.EntityHobts AS eh ON (eh.ID = ep.EntityHoBTID)
											WHERE	(eh.SchemaName = @SchemaName)
												AND	(eh.ObjectName = @ObjectName)
												AND	(ep.RowStatus NOT IN (0, 254))
												AND	(eh.RowStatus NOT IN (0, 254))
											FOR XML PATH ('')
										),
										1,
										1,
										''
										);

			DECLARE	@JoinList NVARCHAR(MAX) = STUFF (
			(
				SELECT N' JOIN ' + eh2.SchemaName + N'.' + eh2.ObjectName + N' AS [' + CONVERT(NVARCHAR(MAX), ep.Guid) + N'] ON ([' + CONVERT(NVARCHAR(MAX), ep.Guid) + N'].ID = root_hobt.' + ep.Name + N') ' + CHAR(10) 
				FROM	SCore.EntityProperties AS ep
				JOIN	SCore.EntityHobts AS eh ON (eh.ID = ep.EntityHoBTID)
				JOIN	SUserInterface.DropDownListDefinitions AS ddld ON (ddld.ID = ep.DropDownListDefinitionID)
				JOIN	SCore.EntityTypes AS et ON (et.ID = ddld.EntityTypeId)
				JOIN	SCore.EntityHobts AS eh2 ON (eh2.EntityTypeID = et.ID)
				WHERE	(eh.SchemaName = @SchemaName)
					AND	(eh.ObjectName = @ObjectName)
					AND	(eh2.IsMainHoBT = 1)
					AND	(ep.DropDownListDefinitionID > 0)
				FOR XML PATH ('')
			),
			1,
			1,
			'');

			SET @Statement = N'SELECT ' + @ParameterList + CHAR(10) + N'FROM ' + @SchemaName + N'.' + @ObjectName + N' AS root_hobt ' + CHAR(10) + ISNULL(@JoinList, N'')
		END
		ELSE IF (@Type = N'P')
		BEGIN
			SELECT	@ParameterList = STUFF (
										 (
											 SELECT N', ' + CHAR(10) + CHAR(9) + p.Name + N' = ' + p.Name
											 FROM	@Parameters AS p
											 FOR XML PATH ('')
										 ),
										 1,
										 1,
										 ''
										   );

			SET @Statement = N'EXEC [' + @SchemaName + N'].[' + @ObjectName + N'] ' + @ParameterList;
		END;
	END;

	-- Insert / Update the main Query Record 
	IF (@IsInsert = 1)
	BEGIN
		SET @RowStatus = 1;

		INSERT	SCore.EntityQueries
			 (Guid,
			  Name,
			  RowStatus,
			  Statement,
			  EntityTypeID,
			  IsDefaultCreate,
			  IsDefaultRead,
			  IsDefaultDelete,
			  IsScalarExecute,
			  IsDefaultUpdate,
			  IsDefaultValidation,
			  EntityHoBTID,
			  IsDefaultDataPills,
			  IsMergeDocumentQuery,
			  IsProgressData,
			  SchemaName,
			  ObjectName,
			  IsManualStatement)
		VALUES
			 (
				 @Guid,
				 @Name,
				 @RowStatus,
				 @Statement,
				 @EntityTypeID,
				 @IsDefaultCreate,
				 @IsDefaultRead,
				 @IsDefaultDelete,
				 @IsScalarExecute,
				 @IsDefaultUpdate,
				 @IsDefaultValidation,
				 @EntityHoBTID,
				 @IsDefaultDataPills,
				 @IsMergeDocumentQuery,
				 @IsProgressData,
				 @SchemaName,
				 @ObjectName,
				 @IsManualStatement
			 );

      SELECT
              @EntityQueryId = SCOPE_IDENTITY();

      if (@IsManualStatement = 0)
      BEGIN 
        UPDATE  @Parameters
        SET     EntityQueryID = @EntityQueryId 
      END
	END;
	ELSE
	BEGIN
		UPDATE	SCore.EntityQueries
		SET		Name = @Name,
				RowStatus = @RowStatus,
				Statement = @Statement,
				EntityTypeID = @EntityTypeID,
				IsDefaultCreate = @IsDefaultCreate,
				IsDefaultRead = @IsDefaultRead,
				IsDefaultUpdate = @IsDefaultUpdate,
				IsDefaultDelete = @IsDefaultDelete,
				IsScalarExecute = @IsScalarExecute,
				IsDefaultValidation = @IsDefaultValidation,
				EntityHoBTID = @EntityHoBTID,
				IsDefaultDataPills = @IsDefaultDataPills,
				IsMergeDocumentQuery = @IsMergeDocumentQuery,
				IsProgressData = @IsProgressData,
				SchemaName = @SchemaName,
				ObjectName = @ObjectName,
				IsManualStatement = @IsManualStatement
		WHERE	(Guid = @Guid);
	END;

	IF (@IsManualStatement = 0)
	BEGIN
		UPDATE	@Parameters
		SET		EntityQueryID = @EntityQueryId;

		-- Create the data object row for the Parameters we're about to insert. 
		INSERT	SCore.DataObjects
			 (Guid, RowStatus, EntityTypeId)
		SELECT	p.Guid,
				1,
				@EntityTypeID
		FROM	@Parameters AS p
		WHERE	(NOT EXISTS
			(
				SELECT	1
				FROM	SCore.DataObjects do
				WHERE	(do.Guid = p.Guid)
			)
				);

		-- Merge the query parameters. 
		MERGE SCore.EntityQueryParameters AS tgt
		USING
			(
				SELECT	*
				FROM	@Parameters
			) AS src
		ON (tgt.EntityQueryID = src.EntityQueryID)
	   AND	(tgt.Name = src.Name)
		WHEN MATCHED THEN UPDATE SET tgt.RowStatus = 1,
									 tgt.EntityDataTypeID = ISNULL (   src.TypeID,
																	   -1
																   ),
									 tgt.MappedEntityPropertyID = ISNULL (	 src.MappedEntityPropertyID,
                                       tgt.MappedEntityPropertyID
																		 ),
									 tgt.IsInput = 1,
									 tgt.IsOutput = src.Is_Output,
									 tgt.IsReturnColumn = 0
		WHEN NOT MATCHED BY TARGET THEN INSERT
											 (
												 RowStatus,
												 Guid,
												 Name,
												 EntityQueryID,
												 EntityDataTypeID,
												 MappedEntityPropertyID,
												 DefaultValue,
												 IsInput,
												 IsOutput,
												 IsReturnColumn
											 )
										VALUES
											 (
												 1,
												 src.Guid,
												 src.Name,
												 src.EntityQueryID,
												 ISNULL (	src.TypeID,
															-1
														),
												 ISNULL (	src.MappedEntityPropertyID,
															-1
														),
												 N'',
												 1,
												 src.Is_Output,
												 0
											 );
	END;

END;
GO