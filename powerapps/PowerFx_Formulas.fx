// ============================================================
// Lab Testing Management System — Power Fx Reference
// ============================================================
// Copy these snippets into the matching control properties
// inside your PowerApps canvas app.
// ============================================================


// ────────────────────────────────────────────────────────────
// APP OnStart — cache lookup tables
// ────────────────────────────────────────────────────────────
Set(gblCurrentUser,
    LookUp(Engineers, Email = User().Email)
);
ClearCollect(colProducts,  Products);
ClearCollect(colTestTypes, TestTypes);
ClearCollect(colEngineers, Filter(Engineers, IsActive = true));

Set(gblPriorityChoices,
    ["Low", "Normal", "High", "Critical"]
);
Set(gblStatusColors, {
    Submitted:    ColorValue("#3B82F6"),
    InReview:     ColorValue("#F59E0B"),
    InProgress:   ColorValue("#8B5CF6"),
    Completed:    ColorValue("#10B981"),
    Cancelled:    ColorValue("#6B7280")
});


// ────────────────────────────────────────────────────────────
// SCREEN: Dashboard
// ────────────────────────────────────────────────────────────

// Label — Total open requests
CountRows(
    Filter(TestRequests,
        Status <> "Completed" && Status <> "Cancelled"
    )
)

// Label — Critical open requests
CountRows(
    Filter(TestRequests,
        Priority = "Critical" &&
        Status <> "Completed" && Status <> "Cancelled"
    )
)

// Label — Overdue count
CountRows(
    Filter(TestRequests,
        DueDate < Today() &&
        Status <> "Completed" && Status <> "Cancelled"
    )
)

// Gallery — Active requests (Items property)
SortByColumns(
    Filter(TestRequests,
        Status <> "Completed" && Status <> "Cancelled",
        // optional engineer filter:
        If(gblCurrentUser.Role = "Engineer",
           RequestedByID = gblCurrentUser.EngineerID,
           true
        )
    ),
    "Priority", Descending,
    "DueDate",  Ascending
)

// Gallery TemplateFill — highlight overdue rows
If(ThisItem.DueDate < Today() &&
   ThisItem.Status <> "Completed",
   ColorValue("#FEF2F2"),   // light red
   White
)

// Badge — status colour helper (used in label Fill)
Switch(ThisItem.Status,
    "Submitted",   gblStatusColors.Submitted,
    "In Review",   gblStatusColors.InReview,
    "In Progress", gblStatusColors.InProgress,
    "Completed",   gblStatusColors.Completed,
    "Cancelled",   gblStatusColors.Cancelled,
    Gray
)


// ────────────────────────────────────────────────────────────
// SCREEN: Submit Request
// ────────────────────────────────────────────────────────────

// Button "Submit" — OnSelect
// Validate
If(IsBlank(ddProduct.Selected) || IsBlank(dpDueDate.SelectedDate),
    Notify("Please fill in all required fields.", NotificationType.Error),

    // Patch main request row
    Set(gblNewRequest,
        Patch(TestRequests, Defaults(TestRequests), {
            ProductID:     ddProduct.Selected.ProductID,
            RequestedByID: gblCurrentUser.EngineerID,
            Priority:      ddPriority.Selected.Value,
            DueDate:       dpDueDate.SelectedDate,
            SampleQty:     Value(txtSampleQty.Text),
            SampleNotes:   txtNotes.Text,
            Status:        "Submitted"
        })
    );

    // Patch selected test type line items
    ForAll(
        Filter(colTestTypeSelection, Selected = true),
        Patch(RequestTests, Defaults(RequestTests), {
            RequestID:  gblNewRequest.RequestID,
            TestTypeID: TestTypeID,
            Status:     "Pending"
        })
    );

    // Log status history
    Patch(StatusHistory, Defaults(StatusHistory), {
        RequestID:   gblNewRequest.RequestID,
        NewStatus:   "Submitted",
        ChangedByID: gblCurrentUser.EngineerID,
        ChangeNote:  "Request submitted via app"
    });

    Notify("Request " & gblNewRequest.RequestNumber & " submitted successfully.", NotificationType.Success);
    Navigate(scrDashboard, ScreenTransition.Fade)
)

// Checkbox gallery (test type selection) — Items property
colTestTypes

// Individual checkbox — Default (keep selection across navigation)
LookUp(colTestTypeSelection, TestTypeID = ThisItem.TestTypeID, Selected)

// Checkbox — OnCheck
Patch(colTestTypeSelection,
    LookUp(colTestTypeSelection, TestTypeID = ThisItem.TestTypeID),
    {TestTypeID: ThisItem.TestTypeID, Selected: true}
);

// Checkbox — OnUncheck
Patch(colTestTypeSelection,
    LookUp(colTestTypeSelection, TestTypeID = ThisItem.TestTypeID),
    {TestTypeID: ThisItem.TestTypeID, Selected: false}
);


// ────────────────────────────────────────────────────────────
// SCREEN: Request Detail
// ────────────────────────────────────────────────────────────

// Gallery — test line items for selected request
Filter(RequestTests, RequestID = gblSelectedRequest.RequestID)

// Dropdown — reassign engineer (Items)
colEngineers

// Button "Update Status" — OnSelect
Patch(TestRequests,
    LookUp(TestRequests, RequestID = gblSelectedRequest.RequestID),
    {
        Status:       ddNewStatus.Selected.Value,
        AssignedToID: ddAssignTo.Selected.EngineerID,
        UpdatedAt:    Now()
    }
);
Patch(StatusHistory, Defaults(StatusHistory), {
    RequestID:   gblSelectedRequest.RequestID,
    OldStatus:   gblSelectedRequest.Status,
    NewStatus:   ddNewStatus.Selected.Value,
    ChangedByID: gblCurrentUser.EngineerID,
    ChangeNote:  txtStatusNote.Text
});
Notify("Status updated.", NotificationType.Success);
Navigate(scrDashboard, ScreenTransition.Fade)


// ────────────────────────────────────────────────────────────
// SCREEN: Record Results
// ────────────────────────────────────────────────────────────

// Button "Save Result" — OnSelect
If(IsBlank(txtMeasuredValue.Text),
    Notify("Enter a measured value.", NotificationType.Warning),

    Patch(TestResults, Defaults(TestResults), {
        RequestTestID:  gblSelectedRequestTest.RequestTestID,
        PerformedByID:  gblCurrentUser.EngineerID,
        MeasuredValue:  Value(txtMeasuredValue.Text),
        Unit:           txtUnit.Text,
        LowerSpec:      Value(txtLowerSpec.Text),
        UpperSpec:      Value(txtUpperSpec.Text),
        Outcome:        If(
                            Value(txtMeasuredValue.Text) >= Value(txtLowerSpec.Text) &&
                            Value(txtMeasuredValue.Text) <= Value(txtUpperSpec.Text),
                            "Pass", "Fail"
                        ),
        Notes:          txtResultNotes.Text,
        RecordedAt:     Now()
    });

    // Update test line item status
    Patch(RequestTests,
        LookUp(RequestTests, RequestTestID = gblSelectedRequestTest.RequestTestID),
        {
            Status:    If(
                          Value(txtMeasuredValue.Text) >= Value(txtLowerSpec.Text) &&
                          Value(txtMeasuredValue.Text) <= Value(txtUpperSpec.Text),
                          "Pass", "Fail"
                       ),
            ActualEnd: Now()
        }
    );

    Notify("Result recorded.", NotificationType.Success);
    Back()
)

// Dynamic outcome indicator label text
If(
    IsBlank(txtMeasuredValue.Text) || IsBlank(txtLowerSpec.Text) || IsBlank(txtUpperSpec.Text),
    "—",
    If(
        Value(txtMeasuredValue.Text) >= Value(txtLowerSpec.Text) &&
        Value(txtMeasuredValue.Text) <= Value(txtUpperSpec.Text),
        "✔ PASS", "✘ FAIL"
    )
)

// Outcome label color
If(
    txtOutcomePreview.Text = "✔ PASS", ColorValue("#10B981"),
    txtOutcomePreview.Text = "✘ FAIL", ColorValue("#EF4444"),
    Gray
)


// ────────────────────────────────────────────────────────────
// GLOBAL SEARCH (header bar)
// ────────────────────────────────────────────────────────────

// Gallery Items on any list screen — add search filter
Filter(TestRequests,
    (IsBlank(txtSearch.Text) ||
     gblSelectedProduct.ProductName in ProductName ||
     txtSearch.Text in RequestNumber
    ) &&
    (ddFilterStatus.Selected.Value = "All" ||
     Status = ddFilterStatus.Selected.Value
    )
)
