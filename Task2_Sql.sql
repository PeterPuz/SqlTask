CREATE TABLE [Dimension](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](200) NOT NULL,
	[Value] [int] NOT NULL,
	[IsDeleted] [bit] NOT NULL,
    CONSTRAINT [PK_Id_Dimension] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [Unique_Name] UNIQUE NONCLUSTERED ([Name] ASC)
) 
GO

CREATE TABLE [Staging](
	[Name] [nvarchar](200) NOT NULL,
	[Value] [int] NOT NULL
)
GO

--LoadDimension procedure based on MERGE statement
CREATE PROCEDURE dbo.LoadDimension
AS
BEGIN

MERGE dbo.dimension AS TARGET
USING dbo.staging AS SOURCE
ON TARGET.Name = SOURCE.Name
WHEN MATCHED THEN UPDATE SET TARGET.Value = SOURCE.Value
WHEN NOT MATCHED BY SOURCE THEN UPDATE SET TARGET.IsDeleted = 1
WHEN NOT MATCHED BY TARGET THEN INSERT (Name,Value,IsDeleted ) VALUES (SOURCE.Name, SOURCE.Value,0);

END
GO

--LoadDimension procedure based on INSERT,UPDATE 
CREATE PROCEDURE dbo.LoadDimension
AS
BEGIN

IF OBJECT_ID('tempdb..#SortedStaging') IS NOT NULL DROP TABLE #SortedStaging;  
SELECT Name,Value INTO #SortedStaging
FROM dbo.Staging ORDER BY Name

CREATE CLUSTERED INDEX IX_SortedStaging
ON #SortedStaging ([Name])

UPDATE dbo.Dimension
SET IsDeleted = 1
FROM dbo.Dimension as D
LEFT JOIN #SortedStaging as S
ON D.Name = S.Name
WHERE S.Name IS NULL

UPDATE dbo.Dimension
SET Value = S.Value
FROM #SortedStaging S
LEFT JOIN dbo.Dimension D ON S.Name = D.Name 
WHERE D.Id IS NOT NULL

INSERT INTO dbo.Dimension (Name,Value,IsDeleted)
SELECT S.Name, S.Value,0 FROM #SortedStaging S
LEFT JOIN dbo.Dimension D ON S.Name = D.Name 
WHERE D.Id IS NULL

DROP TABLE #SortedStaging
END
GO

--Test procedure
CREATE PROCEDURE TestLoadDimension
AS
BEGIN
EXEC tSQLt.FakeTable 'dbo.Staging', @identity=1
EXEC tSQLt.FakeTable 'dbo.Dimension', @identity=1

CREATE TABLE #ExpectedValues (Name nvarchar(200),Value int, IsDeleted bit)

INSERT INTO dbo.Staging (Name,Value) VALUES('r_shouldBeUpdated',5)
INSERT INTO dbo.Staging (Name,Value) VALUES('r_shouldBeInserted',3)
INSERT INTO dbo.Dimension (Name,Value,IsDeleted) VALUES ('r_shouldBeUpdated',0,0)
INSERT INTO dbo.Dimension (Name,Value,IsDeleted) VALUES ('r_shouldBeDeleted',0,0)
INSERT INTO #ExpectedValues (Name,Value,IsDeleted) VALUES('r_shouldBeUpdated',5,0)
INSERT INTO #ExpectedValues (Name,Value,IsDeleted) VALUES('r_shouldBeInserted',3,0)
INSERT INTO #ExpectedValues (Name,Value,IsDeleted) VALUES('r_shouldBeDeleted',0,1)
EXEC dbo.LoadDimension
SELECT Name,Value,IsDeleted INTO #ActualValues FROM dbo.Dimension
EXEC tSQLt.AssertEqualsTable #ActualValues, #ExpectedValues

END;
GO
