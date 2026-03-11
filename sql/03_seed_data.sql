-- ============================================================
-- Lab Testing Management System - Seed / Sample Data
-- ============================================================

-- Engineers
INSERT INTO Engineers (FullName, Email, Department, Role) VALUES
('Alice Hartman',  'alice.hartman@lab.com',  'Mechanical',  'Engineer'),
('Bob Chen',       'bob.chen@lab.com',        'Electronics', 'Engineer'),
('Carol Smith',    'carol.smith@lab.com',     'Lab',         'LabTech'),
('David Kumar',    'david.kumar@lab.com',     'Lab',         'LabTech'),
('Eva Müller',     'eva.muller@lab.com',      'Management',  'Manager'),
('Frank Torres',   'frank.torres@lab.com',    'IT',          'Admin');

-- Products
INSERT INTO Products (ProductCode, ProductName, Category) VALUES
('PROD-001', 'Industrial Sensor Module v2',  'Sensors'),
('PROD-002', 'High-Torque Servo Assembly',   'Actuators'),
('PROD-003', 'Battery Management PCB',       'Electronics'),
('PROD-004', 'Structural Frame Bracket',     'Mechanical'),
('PROD-005', 'Wireless Comm. Module',        'Electronics');

-- Test Types
INSERT INTO TestTypes (TestCode, TestName, Description, EstimatedHours, Department) VALUES
('ENV-001', 'Thermal Cycling',         'Repeated hot/cold temperature cycles',   8.0,  'Lab'),
('ENV-002', 'Vibration Test',          'Sinusoidal and random vibration profile', 4.0,  'Lab'),
('ENV-003', 'Ingress Protection (IP)', 'Dust and water ingress per IEC 60529',   6.0,  'Lab'),
('ELEC-001','Electrical Continuity',   'Full continuity and insulation check',    2.0,  'Lab'),
('ELEC-002','EMC / Emissions',         'Radiated and conducted emissions scan',   12.0, 'Lab'),
('MECH-001','Tensile Strength',        'Material pull-to-failure test',           3.0,  'Lab'),
('MECH-002','Hardness (Rockwell)',     'Surface hardness measurement',            1.0,  'Lab'),
('FUNC-001','Functional Verification', 'End-to-end functional smoke test',        2.0,  'Lab');

-- Sample Test Requests
EXEC usp_SubmitTestRequest
    @ProductID=1, @RequestedByID=1, @Priority='High',
    @DueDate='2026-03-20', @SampleQty=3,
    @SampleNotes='Prototype batch – priority sign-off needed',
    @TestTypeIDs='1,2,4', @NewRequestID=NULL;

EXEC usp_SubmitTestRequest
    @ProductID=3, @RequestedByID=2, @Priority='Critical',
    @DueDate='2026-03-15', @SampleQty=1,
    @SampleNotes='Pre-production board, DVT milestone',
    @TestTypeIDs='4,5,8', @NewRequestID=NULL;

EXEC usp_SubmitTestRequest
    @ProductID=2, @RequestedByID=1, @Priority='Normal',
    @DueDate='2026-04-01', @SampleQty=2,
    @SampleNotes=NULL,
    @TestTypeIDs='2,6,7', @NewRequestID=NULL;

-- Advance request 2 to In Progress
EXEC usp_UpdateRequestStatus @RequestID=2, @NewStatus='In Progress', @ChangedByID=3,
     @ChangeNote='Picked up by lab tech Carol';
