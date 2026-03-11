-- ============================================================
-- Lab Testing Management System - Stored Procedures & Views
-- ============================================================

-- ── View: Active requests with enriched info ─────────────────
CREATE OR ALTER VIEW vw_ActiveRequests AS
SELECT
    tr.RequestID,
    tr.RequestNumber,
    p.ProductCode,
    p.ProductName,
    e1.FullName        AS RequestedBy,
    e1.Email           AS RequestedByEmail,
    e2.FullName        AS AssignedTo,
    tr.Priority,
    tr.Status,
    tr.SampleQty,
    tr.DueDate,
    tr.SubmittedAt,
    tr.UpdatedAt,
    DATEDIFF(DAY, tr.SubmittedAt, GETUTCDATE()) AS AgeDays,
    CASE WHEN tr.DueDate < CAST(GETUTCDATE() AS DATE) AND tr.Status NOT IN ('Completed','Cancelled')
         THEN 1 ELSE 0 END AS IsOverdue,
    (SELECT COUNT(*) FROM RequestTests rt WHERE rt.RequestID = tr.RequestID)                         AS TotalTests,
    (SELECT COUNT(*) FROM RequestTests rt WHERE rt.RequestID = tr.RequestID AND rt.Status = 'Pass')  AS PassedTests,
    (SELECT COUNT(*) FROM RequestTests rt WHERE rt.RequestID = tr.RequestID AND rt.Status = 'Fail')  AS FailedTests
FROM TestRequests tr
JOIN Products     p  ON p.ProductID   = tr.ProductID
JOIN Engineers    e1 ON e1.EngineerID = tr.RequestedByID
LEFT JOIN Engineers e2 ON e2.EngineerID = tr.AssignedToID
WHERE tr.Status NOT IN ('Cancelled','Completed');
GO

-- ── View: Dashboard summary by status ────────────────────────
CREATE OR ALTER VIEW vw_DashboardSummary AS
SELECT
    Status,
    Priority,
    COUNT(*)                                       AS RequestCount,
    AVG(DATEDIFF(DAY, SubmittedAt, GETUTCDATE()))  AS AvgAgeDays,
    SUM(CASE WHEN DueDate < CAST(GETUTCDATE() AS DATE) THEN 1 ELSE 0 END) AS OverdueCount
FROM TestRequests
GROUP BY Status, Priority;
GO

-- ── View: Pass/Fail rate per product ─────────────────────────
CREATE OR ALTER VIEW vw_ProductPassRates AS
SELECT
    p.ProductCode,
    p.ProductName,
    COUNT(DISTINCT tr.RequestID)                    AS TotalRequests,
    SUM(CASE WHEN res.Outcome = 'Pass' THEN 1 ELSE 0 END)  AS PassCount,
    SUM(CASE WHEN res.Outcome = 'Fail' THEN 1 ELSE 0 END)  AS FailCount,
    CAST(
        100.0 * SUM(CASE WHEN res.Outcome = 'Pass' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(res.ResultID), 0)
    AS DECIMAL(5,2))                               AS PassRatePct
FROM Products       p
JOIN TestRequests   tr  ON tr.ProductID      = p.ProductID
JOIN RequestTests   rt  ON rt.RequestID      = tr.RequestID
JOIN TestResults    res ON res.RequestTestID = rt.RequestTestID
GROUP BY p.ProductCode, p.ProductName;
GO

-- ── Stored Procedure: Submit a new test request ───────────────
CREATE OR ALTER PROCEDURE usp_SubmitTestRequest
    @ProductID    INT,
    @RequestedByID INT,
    @Priority     NVARCHAR(20) = 'Normal',
    @DueDate      DATE         = NULL,
    @SampleQty    INT          = 1,
    @SampleNotes  NVARCHAR(1000) = NULL,
    @TestTypeIDs  NVARCHAR(MAX) = NULL,   -- comma-separated list
    @NewRequestID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO TestRequests (ProductID, RequestedByID, Priority, DueDate, SampleQty, SampleNotes)
        VALUES (@ProductID, @RequestedByID, @Priority, @DueDate, @SampleQty, @SampleNotes);

        SET @NewRequestID = SCOPE_IDENTITY();

        -- Insert individual test line items
        IF @TestTypeIDs IS NOT NULL
        BEGIN
            INSERT INTO RequestTests (RequestID, TestTypeID)
            SELECT @NewRequestID, CAST(value AS INT)
            FROM STRING_SPLIT(@TestTypeIDs, ',')
            WHERE LTRIM(RTRIM(value)) <> '';
        END

        -- Seed status history
        INSERT INTO StatusHistory (RequestID, OldStatus, NewStatus, ChangedByID, ChangeNote)
        VALUES (@NewRequestID, NULL, 'Submitted', @RequestedByID, 'Request submitted');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ── Stored Procedure: Update request status ───────────────────
CREATE OR ALTER PROCEDURE usp_UpdateRequestStatus
    @RequestID   INT,
    @NewStatus   NVARCHAR(30),
    @ChangedByID INT,
    @ChangeNote  NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @OldStatus NVARCHAR(30);
    SELECT @OldStatus = Status FROM TestRequests WHERE RequestID = @RequestID;

    UPDATE TestRequests
    SET Status    = @NewStatus,
        UpdatedAt = GETUTCDATE(),
        CompletedAt = CASE WHEN @NewStatus = 'Completed' THEN GETUTCDATE() ELSE CompletedAt END
    WHERE RequestID = @RequestID;

    INSERT INTO StatusHistory (RequestID, OldStatus, NewStatus, ChangedByID, ChangeNote)
    VALUES (@RequestID, @OldStatus, @NewStatus, @ChangedByID, @ChangeNote);
END;
GO

-- ── Stored Procedure: Record test result ─────────────────────
CREATE OR ALTER PROCEDURE usp_RecordTestResult
    @RequestTestID  INT,
    @PerformedByID  INT,
    @MeasuredValue  DECIMAL(18,4) = NULL,
    @Unit           NVARCHAR(50)  = NULL,
    @LowerSpec      DECIMAL(18,4) = NULL,
    @UpperSpec      DECIMAL(18,4) = NULL,
    @Notes          NVARCHAR(2000)= NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Outcome NVARCHAR(20) = 'Inconclusive';

    IF @MeasuredValue IS NOT NULL AND @LowerSpec IS NOT NULL AND @UpperSpec IS NOT NULL
        SET @Outcome = CASE
            WHEN @MeasuredValue BETWEEN @LowerSpec AND @UpperSpec THEN 'Pass'
            ELSE 'Fail'
        END;

    INSERT INTO TestResults (RequestTestID, PerformedByID, MeasuredValue, Unit, LowerSpec, UpperSpec, Outcome, Notes)
    VALUES (@RequestTestID, @PerformedByID, @MeasuredValue, @Unit, @LowerSpec, @UpperSpec, @Outcome, @Notes);

    UPDATE RequestTests
    SET Status    = @Outcome,
        ActualEnd = GETUTCDATE()
    WHERE RequestTestID = @RequestTestID;
END;
GO

-- ── Stored Procedure: Power Automate notification feed ────────
CREATE OR ALTER PROCEDURE usp_GetPendingNotifications
AS
BEGIN
    SET NOCOUNT ON;
    -- Returns overdue requests needing alerts
    SELECT
        tr.RequestID,
        tr.RequestNumber,
        p.ProductName,
        e.Email         AS RequestedByEmail,
        e.FullName      AS RequestedBy,
        tr.DueDate,
        tr.Priority,
        tr.Status
    FROM TestRequests tr
    JOIN Products   p ON p.ProductID   = tr.ProductID
    JOIN Engineers  e ON e.EngineerID  = tr.RequestedByID
    WHERE tr.Status NOT IN ('Completed','Cancelled')
      AND tr.DueDate < CAST(GETUTCDATE() AS DATE);
END;
GO
