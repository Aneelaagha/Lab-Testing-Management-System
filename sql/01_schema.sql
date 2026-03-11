-- ============================================================
-- Lab Testing Management System - Azure SQL Database Schema
-- ============================================================

-- Engineers / Users
CREATE TABLE Engineers (
    EngineerID      INT IDENTITY(1,1) PRIMARY KEY,
    FullName        NVARCHAR(100)  NOT NULL,
    Email           NVARCHAR(150)  NOT NULL UNIQUE,
    Department      NVARCHAR(100),
    Role            NVARCHAR(50)   DEFAULT 'Engineer',  -- Engineer | LabTech | Manager | Admin
    IsActive        BIT            DEFAULT 1,
    CreatedAt       DATETIME2      DEFAULT GETUTCDATE()
);

-- Product / Sample catalog
CREATE TABLE Products (
    ProductID       INT IDENTITY(1,1) PRIMARY KEY,
    ProductCode     NVARCHAR(50)   NOT NULL UNIQUE,
    ProductName     NVARCHAR(200)  NOT NULL,
    Category        NVARCHAR(100),
    Description     NVARCHAR(500),
    IsActive        BIT            DEFAULT 1,
    CreatedAt       DATETIME2      DEFAULT GETUTCDATE()
);

-- Test types / methods
CREATE TABLE TestTypes (
    TestTypeID      INT IDENTITY(1,1) PRIMARY KEY,
    TestCode        NVARCHAR(50)   NOT NULL UNIQUE,
    TestName        NVARCHAR(200)  NOT NULL,
    Description     NVARCHAR(500),
    EstimatedHours  DECIMAL(5,2),
    Department      NVARCHAR(100),
    IsActive        BIT            DEFAULT 1
);

-- Test Requests (main table)
CREATE TABLE TestRequests (
    RequestID       INT IDENTITY(1,1) PRIMARY KEY,
    RequestNumber   AS ('REQ-' + RIGHT('00000' + CAST(RequestID AS VARCHAR), 5)) PERSISTED,
    ProductID       INT            NOT NULL REFERENCES Products(ProductID),
    RequestedByID   INT            NOT NULL REFERENCES Engineers(EngineerID),
    AssignedToID    INT            REFERENCES Engineers(EngineerID),
    Priority        NVARCHAR(20)   DEFAULT 'Normal',    -- Low | Normal | High | Critical
    Status          NVARCHAR(30)   DEFAULT 'Submitted', -- Submitted | In Review | In Progress | Completed | Cancelled
    SampleQty       INT            DEFAULT 1,
    SampleNotes     NVARCHAR(1000),
    DueDate         DATE,
    SubmittedAt     DATETIME2      DEFAULT GETUTCDATE(),
    UpdatedAt       DATETIME2      DEFAULT GETUTCDATE(),
    CompletedAt     DATETIME2,
    CONSTRAINT CHK_Priority CHECK (Priority IN ('Low','Normal','High','Critical')),
    CONSTRAINT CHK_Status   CHECK (Status   IN ('Submitted','In Review','In Progress','Completed','Cancelled'))
);

-- Line items linking requests to test types
CREATE TABLE RequestTests (
    RequestTestID   INT IDENTITY(1,1) PRIMARY KEY,
    RequestID       INT            NOT NULL REFERENCES TestRequests(RequestID),
    TestTypeID      INT            NOT NULL REFERENCES TestTypes(TestTypeID),
    Status          NVARCHAR(30)   DEFAULT 'Pending',   -- Pending | Running | Pass | Fail | Inconclusive
    ScheduledStart  DATETIME2,
    ActualStart     DATETIME2,
    ActualEnd       DATETIME2,
    Notes           NVARCHAR(1000),
    CONSTRAINT CHK_TestStatus CHECK (Status IN ('Pending','Running','Pass','Fail','Inconclusive'))
);

-- Test Results
CREATE TABLE TestResults (
    ResultID        INT IDENTITY(1,1) PRIMARY KEY,
    RequestTestID   INT            NOT NULL REFERENCES RequestTests(RequestTestID),
    PerformedByID   INT            NOT NULL REFERENCES Engineers(EngineerID),
    MeasuredValue   DECIMAL(18,4),
    Unit            NVARCHAR(50),
    LowerSpec       DECIMAL(18,4),
    UpperSpec       DECIMAL(18,4),
    Outcome         NVARCHAR(20)   NOT NULL,  -- Pass | Fail | Inconclusive
    Notes           NVARCHAR(2000),
    RecordedAt      DATETIME2      DEFAULT GETUTCDATE(),
    CONSTRAINT CHK_Outcome CHECK (Outcome IN ('Pass','Fail','Inconclusive'))
);

-- Attachments (file references stored in SharePoint / Blob)
CREATE TABLE Attachments (
    AttachmentID    INT IDENTITY(1,1) PRIMARY KEY,
    RequestID       INT            NOT NULL REFERENCES TestRequests(RequestID),
    FileName        NVARCHAR(255)  NOT NULL,
    FileURL         NVARCHAR(1000) NOT NULL,
    UploadedByID    INT            REFERENCES Engineers(EngineerID),
    UploadedAt      DATETIME2      DEFAULT GETUTCDATE()
);

-- Audit / Status History
CREATE TABLE StatusHistory (
    HistoryID       INT IDENTITY(1,1) PRIMARY KEY,
    RequestID       INT            NOT NULL REFERENCES TestRequests(RequestID),
    OldStatus       NVARCHAR(30),
    NewStatus       NVARCHAR(30),
    ChangedByID     INT            REFERENCES Engineers(EngineerID),
    ChangeNote      NVARCHAR(500),
    ChangedAt       DATETIME2      DEFAULT GETUTCDATE()
);

-- ============================================================
-- Indexes
-- ============================================================
CREATE INDEX IX_TestRequests_Status     ON TestRequests(Status);
CREATE INDEX IX_TestRequests_Priority   ON TestRequests(Priority);
CREATE INDEX IX_TestRequests_DueDate    ON TestRequests(DueDate);
CREATE INDEX IX_RequestTests_RequestID  ON RequestTests(RequestID);
CREATE INDEX IX_TestResults_RequestTestID ON TestResults(RequestTestID);
