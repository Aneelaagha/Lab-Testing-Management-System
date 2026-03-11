"""
Lab Testing Management System
Python Utilities: Azure SQL connector, REST API bridge, report generator
"""

import os
import json
import logging
from datetime import datetime, date
from typing import Any

import pyodbc
import pandas as pd
from flask import Flask, request, jsonify

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Database connection
# ---------------------------------------------------------------------------
CONNECTION_STRING = os.getenv(
    "SQL_CONNECTION_STRING",
    "Driver={ODBC Driver 18 for SQL Server};"
    "Server=<your-server>.database.windows.net;"
    "Database=LabTestingDB;"
    "Authentication=ActiveDirectoryInteractive;"
    "Encrypt=yes;"
)


def get_connection() -> pyodbc.Connection:
    return pyodbc.connect(CONNECTION_STRING)


def _serialize(obj: Any) -> Any:
    """JSON-serialise dates and decimals."""
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serialisable")


# ---------------------------------------------------------------------------
# Flask REST API  (called by PowerApps custom connector or Power Automate)
# ---------------------------------------------------------------------------
app = Flask(__name__)


@app.route("/api/requests", methods=["GET"])
def get_requests():
    """Return active requests with optional filters."""
    status   = request.args.get("status")
    priority = request.args.get("priority")
    engineer = request.args.get("engineerId")

    sql = "SELECT * FROM vw_ActiveRequests WHERE 1=1"
    params: list = []

    if status:
        sql += " AND Status = ?"
        params.append(status)
    if priority:
        sql += " AND Priority = ?"
        params.append(priority)
    if engineer:
        sql += " AND RequestedByID = ?"
        params.append(int(engineer))

    with get_connection() as conn:
        df = pd.read_sql(sql, conn, params=params)

    return jsonify(json.loads(df.to_json(orient="records", default_handler=str)))


@app.route("/api/requests/<int:request_id>", methods=["GET"])
def get_request_detail(request_id: int):
    """Full detail for one request including test line items."""
    with get_connection() as conn:
        req_df  = pd.read_sql(
            "SELECT * FROM vw_ActiveRequests WHERE RequestID = ?",
            conn, params=[request_id]
        )
        tests_df = pd.read_sql(
            """
            SELECT rt.*, tt.TestName, tt.TestCode
            FROM RequestTests rt
            JOIN TestTypes tt ON tt.TestTypeID = rt.TestTypeID
            WHERE rt.RequestID = ?
            """,
            conn, params=[request_id]
        )
        history_df = pd.read_sql(
            """
            SELECT sh.*, e.FullName AS ChangedBy
            FROM StatusHistory sh
            LEFT JOIN Engineers e ON e.EngineerID = sh.ChangedByID
            WHERE sh.RequestID = ?
            ORDER BY sh.ChangedAt DESC
            """,
            conn, params=[request_id]
        )

    if req_df.empty:
        return jsonify({"error": "Request not found"}), 404

    result = json.loads(req_df.iloc[0].to_json(default_handler=str))
    result["tests"]   = json.loads(tests_df.to_json(orient="records",   default_handler=str))
    result["history"] = json.loads(history_df.to_json(orient="records", default_handler=str))
    return jsonify(result)


@app.route("/api/requests", methods=["POST"])
def submit_request():
    """Submit a new test request (called from PowerApps custom connector)."""
    body = request.get_json()
    required = ["productId", "requestedById", "priority", "dueDate", "testTypeIds"]
    missing = [f for f in required if f not in body]
    if missing:
        return jsonify({"error": f"Missing fields: {missing}"}), 400

    test_ids_csv = ",".join(str(i) for i in body["testTypeIds"])

    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            DECLARE @NewID INT;
            EXEC usp_SubmitTestRequest
                @ProductID    = ?,
                @RequestedByID= ?,
                @Priority     = ?,
                @DueDate      = ?,
                @SampleQty    = ?,
                @SampleNotes  = ?,
                @TestTypeIDs  = ?,
                @NewRequestID = @NewID OUTPUT;
            SELECT @NewID;
            """,
            body["productId"],
            body["requestedById"],
            body["priority"],
            body["dueDate"],
            body.get("sampleQty", 1),
            body.get("sampleNotes"),
            test_ids_csv,
        )
        new_id = cursor.fetchval()
        conn.commit()

    logger.info("New request created: ID=%s", new_id)
    return jsonify({"requestId": new_id}), 201


@app.route("/api/requests/<int:request_id>/status", methods=["PATCH"])
def update_status(request_id: int):
    body = request.get_json()
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC usp_UpdateRequestStatus @RequestID=?, @NewStatus=?, @ChangedByID=?, @ChangeNote=?",
            request_id,
            body["newStatus"],
            body["changedById"],
            body.get("changeNote"),
        )
        conn.commit()
    return jsonify({"ok": True})


@app.route("/api/results", methods=["POST"])
def record_result():
    body = request.get_json()
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(
            "EXEC usp_RecordTestResult @RequestTestID=?, @PerformedByID=?, "
            "@MeasuredValue=?, @Unit=?, @LowerSpec=?, @UpperSpec=?, @Notes=?",
            body["requestTestId"],
            body["performedById"],
            body.get("measuredValue"),
            body.get("unit"),
            body.get("lowerSpec"),
            body.get("upperSpec"),
            body.get("notes"),
        )
        conn.commit()
    return jsonify({"ok": True}), 201


# ---------------------------------------------------------------------------
# Reporting helpers  (called by Power BI dataflow or scheduled tasks)
# ---------------------------------------------------------------------------

def export_dashboard_summary(output_path: str = "dashboard_summary.csv") -> pd.DataFrame:
    """Export the dashboard summary view to CSV for Power BI or ad-hoc use."""
    with get_connection() as conn:
        df = pd.read_sql("SELECT * FROM vw_DashboardSummary", conn)
    df.to_csv(output_path, index=False)
    logger.info("Dashboard summary exported to %s", output_path)
    return df


def export_product_pass_rates(output_path: str = "product_pass_rates.csv") -> pd.DataFrame:
    with get_connection() as conn:
        df = pd.read_sql("SELECT * FROM vw_ProductPassRates", conn)
    df.to_csv(output_path, index=False)
    logger.info("Product pass rates exported to %s", output_path)
    return df


def generate_weekly_report() -> dict:
    """
    Aggregate stats for the past 7 days.
    Returns a dict suitable for serialising to JSON or sending via email.
    """
    sql = """
        SELECT
            COUNT(*)                                           AS TotalSubmitted,
            SUM(CASE WHEN Status = 'Completed' THEN 1 END)    AS TotalCompleted,
            SUM(CASE WHEN Status = 'Cancelled' THEN 1 END)    AS TotalCancelled,
            SUM(CASE WHEN DueDate < CAST(GETUTCDATE() AS DATE)
                      AND Status NOT IN ('Completed','Cancelled') THEN 1 END) AS Overdue,
            AVG(DATEDIFF(HOUR, SubmittedAt, CompletedAt))      AS AvgTurnaroundHours
        FROM TestRequests
        WHERE SubmittedAt >= DATEADD(DAY, -7, GETUTCDATE())
    """
    with get_connection() as conn:
        row = pd.read_sql(sql, conn).iloc[0].to_dict()

    row["ReportDate"] = datetime.utcnow().isoformat()
    logger.info("Weekly report generated: %s", row)
    return row


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    # Start REST API bridge on port 5000
    app.run(host="0.0.0.0", port=5000, debug=False)
