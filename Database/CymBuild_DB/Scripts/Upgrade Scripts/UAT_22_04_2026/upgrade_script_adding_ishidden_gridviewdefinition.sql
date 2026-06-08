BEGIN TRANSACTION;

ALTER TABLE SUserInterface.GridViewDefinitions
ADD IsHidden BIT NOT NULL
    CONSTRAINT DF_GridViewDefinitions_IsHidden DEFAULT (0);


COMMIT;