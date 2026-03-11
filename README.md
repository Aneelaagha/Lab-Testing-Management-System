# Lab Testing Management System — Starter Project

A PowerApps + Azure SQL starter for managing product test requests, tracking
status, recording results, and visualising outcomes in Power BI.

---

## Tech Stack
| Layer | Technology |
|---|---|
| Front-end | PowerApps Canvas App + Power Fx |
| Database | Azure SQL Database |
| Automation | Power Automate (4 flows) |
| Analytics | Power BI + DAX |
| API Bridge | Python / Flask (optional) |
| Notifications | Office 365 / Microsoft Teams |

---

## Project Structure

```
lab-testing-system/
├── sql/
│   ├── 01_schema.sql            ← All tables + indexes
│   ├── 02_procedures_views.sql  ← Stored procs, views
│   └── 03_seed_data.sql         ← Sample engineers, products, requests
├── powerapps/
│   └── PowerFx_Formulas.fx      ← All screen formulas, copy-paste ready
├── power_automate/
│   └── flows_definition.json    ← 4 flow blueprints (triggers + steps)
├── power_bi/
│   └── DAX_Measures.dax         ← KPI measures + conditional formatting
├── python/
│   ├── api_bridge.py            ← Flask REST API (optional custom connector)
│   └── requirements.txt
└── docs/
    └── dashboard_preview.html   ← Visual reference for the UI layout
```

---

## Quick Start

### 1 — Azure SQL
1. Create an Azure SQL Database called `LabTestingDB`.
2. Run scripts in order: `01_schema.sql` → `02_procedures_views.sql` → `03_seed_data.sql`.
3. Note your connection string for the next steps.

### 2 — PowerApps
1. Create a new **Canvas App** (tablet layout).
2. Add a **SQL Server** data source pointing to your Azure SQL DB.
3. Add these tables/views as data sources:
   - `TestRequests`, `Engineers`, `Products`, `TestTypes`
   - `RequestTests`, `TestResults`, `StatusHistory`, `Attachments`
   - `vw_ActiveRequests`, `vw_DashboardSummary`, `vw_ProductPassRates`
4. Create screens: **Dashboard, Submit Request, Request Detail, Record Results**.
5. Copy formulas from `powerapps/PowerFx_Formulas.fx` into the matching controls.

### 3 — Power Automate
1. Open **Power Automate** and create 4 new flows using `power_automate/flows_definition.json` as a blueprint.
2. Set up connections: **SQL Server**, **Office 365 Outlook**, **Microsoft Teams**.
3. Replace placeholder values (`<your-server>`, `labmanager@yourorg.com`) with real values.
4. Test each flow with a sample request.

### 4 — Power BI
1. Connect Power BI Desktop to your Azure SQL DB.
2. Import views: `vw_ActiveRequests`, `vw_DashboardSummary`, `vw_ProductPassRates`.
3. Paste the measures from `power_bi/DAX_Measures.dax` into the model.
4. Build visuals: KPI cards, bar chart (status), donut (pass/fail), table (active requests).
5. Publish to Power BI Service and embed the report URL in PowerApps using a Power BI tile.

### 5 — Python API Bridge (optional)
Use if you need a **Custom Connector** in PowerApps or Power Automate.

```bash
cd python
pip install -r requirements.txt
# Set env var:
export SQL_CONNECTION_STRING="Driver=...;Server=...;Database=LabTestingDB;"
python api_bridge.py        # starts on port 5000
```
Deploy to **Azure App Service** or **Azure Container Apps** for production.

---

## Key Screens

| Screen | Purpose |
|---|---|
| Dashboard | KPI cards, active request gallery, overdue alerts |
| Submit Request | Form with product picker, priority, due date, test type checklist |
| Request Detail | Full detail + status update + file attachments |
| Record Results | Enter measurements, auto-calculates Pass/Fail vs spec limits |

---

## Database Tables

| Table | Purpose |
|---|---|
| `Engineers` | Users and roles |
| `Products` | Product/sample catalogue |
| `TestTypes` | Available test methods |
| `TestRequests` | Main request header |
| `RequestTests` | Test line items per request |
| `TestResults` | Measured values and outcome |
| `StatusHistory` | Full audit trail |
| `Attachments` | File reference links |

---

## Power Automate Flows

| Flow | Trigger | Action |
|---|---|---|
| New Request Notification | SQL row created | Email requester + Teams post |
| Status Change Alert | SQL row updated | Email requester with new status |
| Overdue Reminder | Daily 08:00 (weekdays) | Email all requesters with overdue items |
| All Tests Complete | SQL row created (Results) | Auto-close request + notify requester |

---

## Environment Variables

```env
SQL_CONNECTION_STRING=Driver={ODBC Driver 18 for SQL Server};Server=<server>.database.windows.net;Database=LabTestingDB;Authentication=ActiveDirectoryInteractive;Encrypt=yes;
LAB_MANAGER_EMAIL=labmanager@yourorg.com
TEAMS_LAB_CHANNEL_ID=<channel-id>
```
