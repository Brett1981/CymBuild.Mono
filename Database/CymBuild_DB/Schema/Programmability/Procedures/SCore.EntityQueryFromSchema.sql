SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[EntityQueryFromSchema]
	(	@ProcedureSchema NVARCHAR(254),
		@ProcedureName NVARCHAR(254),
		@EntityName NVARCHAR(255)
	)
AS
BEGIN
	DECLARE @EntityQueryID INT,
			@ParameterList NVARCHAR(2000),
			@EntityTypeID  INT,
			@Type		   NVARCHAR(10),
			@Statement	   NVARCHAR(2550);

	SELECT	@EntityTypeID = et.ID
	FROM	SCore.EntityTypes AS et
	WHERE	(et.Name = @EntityName);

	DECLARE @Parameters TABLE
		(
			Name NVARCHAR(255) NULL,
			TypeID INT NULL,
			EntityQueryID INT NULL,
			Is_Output BIT NULL,
			MappedEntityPropertyID INT NULL
		);

	SELECT	@Type = type
	FROM	sys.objects
	WHERE	(name					 = @ProcedureName)
		AND (SCHEMA_NAME (schema_id) = @ProcedureSchema);

	IF (@Type = N'TF')
	BEGIN
		INSERT	@Parameters
			 (Name, TypeID, EntityQueryID, Is_Output, MappedEntityPropertyID)
		SELECT	pp.name,
				datatype.ID		  AS TypeId,
				@EntityQueryID	  AS EntityQueryID,
				pp.is_output,
				mappedproperty.ID AS MappedEntityPropertyID
		FROM	sys.objects		AS o
		JOIN	sys.sql_modules AS m ON (m.object_id = o.object_id)
		JOIN	sys.parameters	AS pp ON (m.object_id = pp.object_id)
		JOIN	sys.types		AS t ON (pp.user_type_id = t.user_type_id)
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
		WHERE	(SCHEMA_NAME (o.schema_id) = @ProcedureSchema)
			AND (o.name					   = @ProcedureName);
	END;
	ELSE
	BEGIN
		INSERT	@Parameters
			 (Name, TypeID, EntityQueryID, Is_Output, MappedEntityPropertyID)
		SELECT	pp.name,
				datatype.ID		  AS TypeId,
				@EntityQueryID	  AS EntityQueryID,
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
		WHERE	(SCHEMA_NAME (p.schema_id) = @ProcedureSchema)
			AND (p.name					   = @ProcedureName);
	END;

	SELECT	@ParameterList = STUFF (
								 (
									 SELECT N', ' + p.Name + N' = ' + p.Name
									 FROM	@Parameters AS p
									 FOR XML PATH ('')
								 ),
								 1,
								 1,
								 ''
								   );



	IF (@Type = N'TF')
	BEGIN
		SET @Statement = N'SELECT * FROM [' + @ProcedureSchema + N'].[' + @ProcedureName + N'] (' + @ParameterList + N') root_hobt';
	END;
	ELSE
	BEGIN
		SET @Statement = N'EXEC [' + @ProcedureSchema + N'].[' + @ProcedureName + N'] ' + @ParameterList;
	END;

	SELECT	@EntityQueryID = eq.ID
	FROM	SCore.EntityQueries AS eq
	WHERE	(eq.Name		 = N'[' + @ProcedureSchema + N'].[' + @ProcedureName + N']')
		AND (eq.EntityTypeID = @EntityTypeID);

	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT	SCore.EntityQueries
			 (RowStatus, Guid, Name, Statement, EntityTypeID, IsDefaultCreate, IsDefaultDelete, IsDefaultRead, IsDefaultUpdate, IsDefaultValidation)
		VALUES
			 (
				 1,
				 NEWID (),
				 N'[' + @ProcedureSchema + N'].[' + @ProcedureName + N']',
				 @Statement,
				 @EntityTypeID,
				 CASE WHEN @ProcedureName LIKE N'%Upsert' THEN 1 ELSE 0 END,
				 0,
				 0,
				 CASE WHEN @ProcedureName LIKE N'%Upsert' THEN 1 ELSE 0 END,
				 CASE WHEN @ProcedureName LIKE N'%Validate' THEN 1 ELSE 0 END
			 );

		SELECT	@EntityQueryID = SCOPE_IDENTITY ();
	END;
	ELSE
	BEGIN
		UPDATE	SCore.EntityQueries
		SET		Statement = @Statement
		WHERE	ID = @EntityQueryID;
	END;

	UPDATE	@Parameters
	SET		EntityQueryID = @EntityQueryID;

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
																		 -1
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
											 NEWID (),
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
GO