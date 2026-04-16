-- =========================================================
-- Synthetic Legacy Hospital Database - V2
-- PostgreSQL
-- Purpose: realistic legacy integration / ETL / cleanup testing
-- All data is fictional
-- =========================================================

DROP TABLE IF EXISTS integration_outbox CASCADE;
DROP TABLE IF EXISTS patient_merge_log CASCADE;
DROP TABLE IF EXISTS document_store CASCADE;
DROP TABLE IF EXISTS billing_line CASCADE;
DROP TABLE IF EXISTS invoice_header CASCADE;
DROP TABLE IF EXISTS medication_order CASCADE;
DROP TABLE IF EXISTS procedure_log CASCADE;
DROP TABLE IF EXISTS diagnosis_log CASCADE;
DROP TABLE IF EXISTS lab_result CASCADE;
DROP TABLE IF EXISTS lab_order CASCADE;
DROP TABLE IF EXISTS admission_record CASCADE;
DROP TABLE IF EXISTS appointment_book CASCADE;
DROP TABLE IF EXISTS visit_record CASCADE;
DROP TABLE IF EXISTS provider_directory CASCADE;
DROP TABLE IF EXISTS department_ref CASCADE;
DROP TABLE IF EXISTS patient_master CASCADE;

-- =========================================================
-- Reference / master tables
-- =========================================================

CREATE TABLE department_ref (
    dept_id              SERIAL PRIMARY KEY,
    dept_code            VARCHAR(12) NOT NULL,
    dept_name            VARCHAR(100) NOT NULL,
    building_name        VARCHAR(60),
    floor_label          VARCHAR(20),
    extension_no         VARCHAR(15),
    active_flag          CHAR(1) DEFAULT 'Y',
    retired_ts           TIMESTAMP
);

CREATE TABLE provider_directory (
    provider_id          SERIAL PRIMARY KEY,
    provider_code        VARCHAR(20) NOT NULL,
    full_name            VARCHAR(120) NOT NULL,
    title_text           VARCHAR(40),
    specialty_text       VARCHAR(80),
    dept_id              INT REFERENCES department_ref(dept_id),
    phone_direct         VARCHAR(30),
    pager_no             VARCHAR(30),
    hire_date            DATE,
    active_flag          CHAR(1) DEFAULT 'Y',
    external_registry_no VARCHAR(30),
    notes_text           TEXT
);

CREATE TABLE patient_master (
    patient_id           SERIAL PRIMARY KEY,
    chart_no             VARCHAR(20) NOT NULL,
    legacy_person_no     VARCHAR(20),
    national_id_text     VARCHAR(30),
    local_id_text        VARCHAR(30),
    mpi_hint             VARCHAR(40),       -- crude legacy matching key
    last_name            VARCHAR(80) NOT NULL,
    first_name           VARCHAR(80) NOT NULL,
    middle_name          VARCHAR(80),
    preferred_name       VARCHAR(80),
    suffix_text          VARCHAR(20),
    sex_code             VARCHAR(10),
    birth_date           DATE,
    age_text             VARCHAR(20),       -- sometimes manually entered
    deceased_flag        CHAR(1) DEFAULT 'N',
    blood_type_text      VARCHAR(10),
    marital_text         VARCHAR(20),
    language_text        VARCHAR(40),
    religion_text        VARCHAR(40),
    occupation_text      VARCHAR(80),
    employer_name        VARCHAR(120),
    phone_home           VARCHAR(30),
    phone_mobile         VARCHAR(30),
    phone_work           VARCHAR(30),
    email_addr           VARCHAR(120),
    addr_line1           VARCHAR(120),
    addr_line2           VARCHAR(120),
    town_name            VARCHAR(80),
    district_name        VARCHAR(80),
    postal_text          VARCHAR(20),
    country_text         VARCHAR(40),
    emergency_name       VARCHAR(120),
    emergency_relation   VARCHAR(40),
    emergency_phone      VARCHAR(30),
    gp_name_text         VARCHAR(120),
    allergy_text         TEXT,
    chronic_flag_text    VARCHAR(20),
    smoking_text         VARCHAR(30),
    alcohol_text         VARCHAR(30),
    vip_flag             CHAR(1) DEFAULT 'N',
    merge_target_chart   VARCHAR(20),       -- legacy manual hint only
    active_flag          CHAR(1) DEFAULT 'Y',
    reg_date             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_update_ts       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_patient_chart_no ON patient_master(chart_no);
CREATE INDEX ix_patient_name_dob ON patient_master(last_name, first_name, birth_date);

CREATE TABLE visit_record (
    visit_id             SERIAL PRIMARY KEY,
    visit_no             VARCHAR(20) NOT NULL,
    patient_id           INT NOT NULL REFERENCES patient_master(patient_id),
    visit_type           VARCHAR(20),
    dept_id              INT REFERENCES department_ref(dept_id),
    attending_provider   INT REFERENCES provider_directory(provider_id),
    referred_by_text     VARCHAR(120),
    visit_start_ts       TIMESTAMP NOT NULL,
    visit_end_ts         TIMESTAMP,
    arrival_mode         VARCHAR(30),
    reason_text          VARCHAR(255),
    chief_complaint      VARCHAR(255),
    triage_note          TEXT,
    status_text          VARCHAR(20),
    source_system        VARCHAR(30),
    external_visit_ref   VARCHAR(30),
    created_ts           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_update_ts       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_visit_no ON visit_record(visit_no);
CREATE INDEX ix_visit_patient ON visit_record(patient_id);

CREATE TABLE appointment_book (
    appt_id              SERIAL PRIMARY KEY,
    appt_no              VARCHAR(20) NOT NULL,
    patient_id           INT REFERENCES patient_master(patient_id),
    provider_id          INT REFERENCES provider_directory(provider_id),
    dept_id              INT REFERENCES department_ref(dept_id),
    appt_ts              TIMESTAMP NOT NULL,
    duration_mins        INT,
    appt_status          VARCHAR(20),
    reason_text          VARCHAR(255),
    booking_channel      VARCHAR(30),
    slot_label           VARCHAR(20),
    reminder_flag        CHAR(1) DEFAULT 'N',
    note_text            TEXT,
    created_by_user      VARCHAR(40),
    last_update_ts       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_appt_no ON appointment_book(appt_no);

CREATE TABLE admission_record (
    admission_id         SERIAL PRIMARY KEY,
    admit_no             VARCHAR(20) NOT NULL,
    visit_id             INT REFERENCES visit_record(visit_id),
    patient_id           INT NOT NULL REFERENCES patient_master(patient_id),
    admit_ts             TIMESTAMP NOT NULL,
    discharge_ts         TIMESTAMP,
    ward_name            VARCHAR(60),
    room_no              VARCHAR(20),
    bed_no               VARCHAR(20),
    attending_team_text  VARCHAR(80),
    admit_source         VARCHAR(40),
    discharge_disp       VARCHAR(40),
    isolation_flag       CHAR(1) DEFAULT 'N',
    diet_text            VARCHAR(80),
    nursing_comment      TEXT
);

CREATE INDEX ix_admit_no ON admission_record(admit_no);

CREATE TABLE diagnosis_log (
    dx_id                SERIAL PRIMARY KEY,
    visit_id             INT REFERENCES visit_record(visit_id),
    admission_id         INT REFERENCES admission_record(admission_id),
    patient_id           INT NOT NULL REFERENCES patient_master(patient_id),
    dx_seq               INT,
    dx_code_local        VARCHAR(20),
    dx_code_old          VARCHAR(20),
    dx_desc              VARCHAR(255) NOT NULL,
    dx_type              VARCHAR(20),
    onset_text           VARCHAR(40),
    chronicity_text      VARCHAR(20),
    resolution_text      VARCHAR(40),
    provider_id          INT REFERENCES provider_directory(provider_id),
    entered_by           VARCHAR(40),
    entered_ts           TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE procedure_log (
    proc_id              SERIAL PRIMARY KEY,
    visit_id             INT REFERENCES visit_record(visit_id),
    admission_id         INT REFERENCES admission_record(admission_id),
    patient_id           INT NOT NULL REFERENCES patient_master(patient_id),
    proc_code_local      VARCHAR(20),
    proc_desc            VARCHAR(255) NOT NULL,
    proc_site_text       VARCHAR(40),
    proc_ts              TIMESTAMP,
    surgeon_provider_id  INT REFERENCES provider_directory(provider_id),
    anaesthesia_text     VARCHAR(60),
    theatre_text         VARCHAR(40),
    implant_text         VARCHAR(100),
    outcome_text         VARCHAR(100),
    note_text            TEXT
);

CREATE TABLE medication_order (
    med_order_id         SERIAL PRIMARY KEY,
    visit_id             INT REFERENCES visit_record(visit_id),
    admission_id         INT REFERENCES admission_record(admission_id),
    patient_id           INT NOT NULL REFERENCES patient_master(patient_id),
    med_name_text        VARCHAR(120) NOT NULL,
    local_drug_code      VARCHAR(20),
    dose_text            VARCHAR(60),
    route_text           VARCHAR(30),
    freq_text            VARCHAR(40),
    prn_flag             CHAR(1) DEFAULT 'N',
    indication_text      VARCHAR(255),
    start_ts             TIMESTAMP,
    stop_ts              TIMESTAMP,
    prescribing_provider INT REFERENCES provider_directory(provider_id),
    pharmacy_status      VARCHAR(20),
    dispense_qty_text    VARCHAR(40),
    admin_instruction    TEXT,
    caution_text         TEXT
);

CREATE TABLE lab_order (
    lab_order_id         SERIAL PRIMARY KEY,
    order_no             VARCHAR(20) NOT NULL,
    visit_id             INT REFERENCES visit_record(visit_id),
    admission_id         INT REFERENCES admission_record(admission_id),
    patient_id           INT NOT NULL REFERENCES patient_master(patient_id),
    ordering_provider    INT REFERENCES provider_directory(provider_id),
    order_ts             TIMESTAMP NOT NULL,
    specimen_type        VARCHAR(40),
    test_panel_name      VARCHAR(120),
    priority_text        VARCHAR(20),
    order_status         VARCHAR(20),
    external_order_ref   VARCHAR(30),
    clinical_note        TEXT
);

CREATE INDEX ix_lab_order_no ON lab_order(order_no);

CREATE TABLE lab_result (
    lab_result_id        SERIAL PRIMARY KEY,
    lab_order_id         INT NOT NULL REFERENCES lab_order(lab_order_id),
    component_name       VARCHAR(120) NOT NULL,
    component_code_local VARCHAR(20),
    result_value_text    VARCHAR(60) NOT NULL,
    unit_text            VARCHAR(20),
    ref_range_text       VARCHAR(40),
    abnormal_flag        VARCHAR(10),
    result_status        VARCHAR(20),
    verified_by_text     VARCHAR(120),
    result_ts            TIMESTAMP,
    comment_text         TEXT
);

CREATE TABLE invoice_header (
    invoice_id           SERIAL PRIMARY KEY,
    invoice_no           VARCHAR(20) NOT NULL,
    patient_id           INT NOT NULL REFERENCES patient_master(patient_id),
    visit_id             INT REFERENCES visit_record(visit_id),
    admission_id         INT REFERENCES admission_record(admission_id),
    invoice_date         DATE NOT NULL,
    payer_name           VARCHAR(120),
    payer_plan_text      VARCHAR(120),
    billing_status       VARCHAR(20),
    total_amount         NUMERIC(12,2) DEFAULT 0,
    discount_amount      NUMERIC(12,2) DEFAULT 0,
    amount_paid          NUMERIC(12,2) DEFAULT 0,
    note_text            TEXT
);

CREATE INDEX ix_invoice_no ON invoice_header(invoice_no);

CREATE TABLE billing_line (
    billing_line_id      SERIAL PRIMARY KEY,
    invoice_id           INT NOT NULL REFERENCES invoice_header(invoice_id),
    charge_code          VARCHAR(20),
    charge_desc          VARCHAR(255),
    service_date         DATE,
    qty                  NUMERIC(10,2) DEFAULT 1,
    unit_price           NUMERIC(12,2) DEFAULT 0,
    line_amount          NUMERIC(12,2) DEFAULT 0,
    revenue_bucket       VARCHAR(40),
    line_status          VARCHAR(20),
    ordering_dept_text   VARCHAR(60)
);

CREATE TABLE document_store (
    doc_id               SERIAL PRIMARY KEY,
    patient_id           INT NOT NULL REFERENCES patient_master(patient_id),
    visit_id             INT REFERENCES visit_record(visit_id),
    admission_id         INT REFERENCES admission_record(admission_id),
    doc_type             VARCHAR(40),
    doc_title            VARCHAR(150),
    author_name          VARCHAR(120),
    author_provider_id   INT REFERENCES provider_directory(provider_id),
    created_ts           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    content_text         TEXT,
    signed_flag          CHAR(1) DEFAULT 'N',
    scan_ref_text        VARCHAR(80)
);

CREATE TABLE patient_merge_log (
    merge_id             SERIAL PRIMARY KEY,
    source_chart_no      VARCHAR(20) NOT NULL,
    target_chart_no      VARCHAR(20) NOT NULL,
    merge_ts             TIMESTAMP NOT NULL,
    merge_reason         VARCHAR(255),
    performed_by         VARCHAR(40),
    review_flag          CHAR(1) DEFAULT 'N'
);

CREATE TABLE integration_outbox (
    outbox_id            SERIAL PRIMARY KEY,
    entity_name          VARCHAR(40) NOT NULL,
    entity_pk            VARCHAR(40) NOT NULL,
    action_type          VARCHAR(20) NOT NULL,
    payload_json         TEXT NOT NULL,
    source_system        VARCHAR(30),
    enqueue_ts           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_flag       CHAR(1) DEFAULT 'N',
    processed_ts         TIMESTAMP,
    retry_count          INT DEFAULT 0,
    last_attempt_ts      TIMESTAMP,
    dedupe_key           VARCHAR(80),
    error_text           TEXT
);

-- =========================================================
-- Seed reference data
-- =========================================================

INSERT INTO department_ref (dept_code, dept_name, building_name, floor_label, extension_no, active_flag, retired_ts) VALUES
('GEN-OPD', 'General Clinic', 'Main Block', '1', '1101', 'Y', NULL),
('EMR', 'Emergency Room', 'Main Block', 'G', '1199', 'Y', NULL),
('LAB', 'Laboratory', 'Service Wing', '1', '1302', 'Y', NULL),
('WARD-A', 'Medical Ward A', 'North Wing', '2', '2201', 'Y', NULL),
('SURG-M', 'Minor Theatre', 'Service Wing', 'G', '1405', 'Y', NULL),
('BILL', 'Billing Office', 'Admin Block', 'G', '1004', 'Y', NULL),
('OBS', 'Observation Bay', 'Main Block', 'G', '1184', 'N', '2025-11-01 00:00');

INSERT INTO provider_directory (
    provider_code, full_name, title_text, specialty_text, dept_id, phone_direct, pager_no,
    hire_date, active_flag, external_registry_no, notes_text
) VALUES
('DR100', 'Mina Sorrel', 'Dr.', 'Family Medicine', 1, '555-1108', 'P-44', '2018-06-04', 'Y', 'REG-8821', 'Usually morning clinic'),
('DR101', 'Harun Vale', 'Dr.', 'Emergency Care', 2, '555-1192', 'P-18', '2020-01-15', 'Y', 'REG-8822', 'Night duty rotation'),
('DR102', 'Elio Bram', 'Dr.', 'Internal Medicine', 4, '555-2204', NULL, '2016-09-01', 'Y', 'REG-8823', 'Rounds before 8am'),
('DR103', 'Rhea Mardin', 'Dr.', 'Minor Surgery', 5, '555-1408', 'P-31', '2019-03-10', 'Y', 'REG-8824', NULL),
('NP201', 'Talia Fen', 'Nurse Practitioner', 'Primary Care', 1, '555-1114', NULL, '2021-11-02', 'Y', 'NP-1002', NULL),
('LAB01', 'Jon Ivers', 'Mr.', 'Lab Supervisor', 3, '555-1305', NULL, '2017-04-21', 'Y', NULL, 'Handles send-out tests'),
('DR077', 'Edda Voss', 'Dr.', 'Observation Medicine', 7, '555-1184', 'P-08', '2012-02-01', 'N', 'REG-8080', 'Retired service, provider left'),
('TEMP1', 'ONCALL LOCUM', 'Dr.', 'General Cover', 1, NULL, NULL, '2026-01-05', 'Y', NULL, 'Shared login/provider shell');

-- =========================================================
-- Seed patient data
-- Includes realistic quality issues
-- =========================================================

INSERT INTO patient_master (
    chart_no, legacy_person_no, national_id_text, local_id_text, mpi_hint,
    last_name, first_name, middle_name, preferred_name, suffix_text,
    sex_code, birth_date, age_text, deceased_flag, blood_type_text,
    marital_text, language_text, religion_text, occupation_text, employer_name,
    phone_home, phone_mobile, phone_work, email_addr,
    addr_line1, addr_line2, town_name, district_name, postal_text, country_text,
    emergency_name, emergency_relation, emergency_phone, gp_name_text,
    allergy_text, chronic_flag_text, smoking_text, alcohol_text,
    vip_flag, merge_target_chart, active_flag, reg_date, last_update_ts
) VALUES
('CH-000145', 'P8821', 'ID-77-2901', 'LOC-145', 'DAMAR|LENA|1987-04-11',
 'Damar', 'Lena', 'Iris', 'Len', NULL,
 'F', '1987-04-11', NULL, 'N', 'A+',
 'Married', 'English', 'None', 'School Admin', 'Oakbend Primary',
 '555 9001', '(555) 772-190', NULL, 'lena.d@example.test',
 '14 River Lane', NULL, 'Oakbend', 'West', '44102', 'Local',
 'Tomas Damar', 'Spouse', '555-772-191', 'Dr H. Keel',
 'Penicillin (rash); shellfish?', 'Y', 'Never', 'Social',
 'N', NULL, 'Y', '2024-08-11 09:20', '2026-03-10 11:05'),

('CH-000146', 'P8822X', NULL, 'LOC-146', 'CORIN|MATEO|1972-09-27',
 'Corin', 'Mateo', NULL, NULL, NULL,
 'M', '1972-09-27', '53', 'N', 'O-',
 'Single', 'English', 'None', 'Machine Operator', 'Oakbend Metal Works',
 NULL, '555-222-7101', '555-900-8821', NULL,
 '8 Hill Cart Rd', 'Near Old Mill', 'Oakbend', 'North', '44109', 'Local',
 'Liza Corin', 'Sister', '555.222.7109', NULL,
 'NKDA', 'Y', 'Current some days', 'Weekend',
 'N', NULL, 'Y', '2023-01-05 10:15', '2026-03-06 01:25'),

('CH-000147', 'OLD-771', 'LOC-88211', 'LOC-147', 'SEN|PRIYA|1995-01-08',
 'Sen', 'Priya', 'D', 'Priya', NULL,
 'F', '1995-01-08', NULL, 'N', '',
 'Single', 'Hindi', 'Hindu', 'Cashier', NULL,
 '555-3330', '555-333-8820', NULL, 'priya.sen@example.test',
 '22 Market Street', 'Unit 4B', 'Lakeview', 'Central', '55011', 'Local',
 'Asha Sen', 'Mother', '555-330-0041', 'Dr P. Nash',
 'Peanut, latex', 'N', 'Never', 'No',
 'N', NULL, 'Y', '2025-02-12 14:10', '2026-03-03 15:00'),

('CH-000148', 'P-00991', 'ID-44-9988', 'LOC-148', 'QUILL|JONAH|1961-12-19',
 'Quill', 'Jonah', NULL, 'Joe', NULL,
 'M', '1961-12-19', '64y', 'N', 'B+',
 'Widowed', 'English', 'Christian', 'Retired', NULL,
 '555-4100', NULL, NULL, NULL,
 '77 Cedar Reach', NULL, 'Oakbend', 'East', '44121', 'Local',
 'Marin Quill', 'Daughter', '555-4102', 'Dr Mina Sorrel',
 'Sulfa?', 'Y', 'Former', 'No',
 'Y', NULL, 'Y', '2021-11-18 08:00', '2026-03-06 09:42'),

('CH-000149', 'TEMP-14', NULL, 'TEMP-14', 'VALEZ|NORA|2012-07-03',
 'Valez', 'Nora', NULL, NULL, NULL,
 'U', '2012-07-03', '13', 'N', 'AB+',
 'Minor', 'Spanish', 'None', 'Student', NULL,
 NULL, '555-881-2211', NULL, NULL,
 '5 Garden Path', NULL, 'Brookhollow', 'South', '46002', 'Local',
 'Inez Valez', 'Mother', '555-881-2212', NULL,
 'No known drug allergy', 'N', 'Never', 'No',
 'N', NULL, 'Y', '2026-03-07 09:50', '2026-03-07 10:18'),

-- Duplicate-ish patient: same person as CH-000145 but old temp chart not fully merged
('TMP-7781', 'TMP7781', NULL, NULL, 'DAMAR|LENA|1987-04-11',
 'Damar', 'Lena', NULL, NULL, NULL,
 'Female', '1987-04-11', '38', 'N', NULL,
 NULL, 'Eng', NULL, NULL, NULL,
 NULL, '555772190', NULL, NULL,
 '14 River Ln', NULL, 'Oakbend', NULL, NULL, NULL,
 'Tom Damar', 'husband', '555772191', NULL,
 'penicillin', 'Y', NULL, NULL,
 'N', 'CH-000145', 'N', '2024-08-11 08:55', '2025-12-01 11:02'),

-- Slightly duplicate-ish child registration with different spelling
('CH-000150', 'P0150', NULL, 'LOC-150', 'VALEZ|NORAH|2012-07-03',
 'Vales', 'Norah', NULL, NULL, NULL,
 'F', '2012-07-03', NULL, 'N', NULL,
 'Minor', 'Spanish', NULL, 'Student', NULL,
 NULL, '5558812211', NULL, NULL,
 '5 Garden Path', NULL, 'Brookhollow', 'South', '46002', 'Local',
 'Inez Valez', 'Mother', '5558812212', NULL,
 'NKDA', 'N', NULL, NULL,
 'N', 'CH-000149', 'N', '2026-03-07 09:40', '2026-03-07 09:41'),

-- Older inactive chart left behind after probable merge
('CH-000099', 'LEG-099', 'ID-44-9988', NULL, 'QUILL|JONAH|1961-12-19',
 'Quill', 'Jon', NULL, NULL, NULL,
 'M', '1961-12-19', NULL, 'N', NULL,
 'Widower', 'English', NULL, NULL, NULL,
 '5554100', NULL, NULL, NULL,
 '77 Cedar Rch', NULL, 'Oakbend', 'E', '44121', NULL,
 'Marin Quill', 'Dtr', '5554102', NULL,
 'sulfa', 'Y', NULL, NULL,
 'N', 'CH-000148', 'N', '2018-07-03 13:10', '2024-04-02 09:00');

-- =========================================================
-- Appointments
-- Includes no-shows, cancelled, odd statuses, unmatched flow
-- =========================================================

INSERT INTO appointment_book (
    appt_no, patient_id, provider_id, dept_id, appt_ts, duration_mins, appt_status,
    reason_text, booking_channel, slot_label, reminder_flag, note_text, created_by_user, last_update_ts
) VALUES
('APT-1001', 1, 1, 1, '2026-03-01 09:00', 20, 'ARRIVED', 'Follow-up for blood pressure', 'phone', 'MORN-1', 'Y', 'Requested early slot', 'desk01', '2026-02-28 16:20'),
('APT-1002', 2, 1, 1, '2026-03-02 10:20', 20, 'DNKA', 'General review', 'desk', 'MID-2', 'N', NULL, 'desk02', '2026-03-02 11:00'),
('APT-1003', 3, 5, 1, '2026-03-03 14:00', 30, 'ARRIVED', 'Skin rash and cough', 'walkin', 'PM-3', 'N', 'Paper slip attached', 'front01', '2026-03-03 14:01'),
('APT-1004', 4, 1, 1, '2026-03-04 11:00', 20, 'BOOKED', 'Medication refill', 'phone', 'MID-3', 'Y', NULL, 'desk01', '2026-03-03 17:10'),
('APT-1005', 1, 8, 1, '2026-03-11 16:30', 15, 'SEEN', 'Quick form review', 'desk', 'PM-5', 'N', 'Locum cover', 'desk01', '2026-03-11 16:50'),
('APT-1006', 5, 1, 1, '2026-03-07 10:00', 20, 'CHKD-IN', 'School physical form', 'phone', 'MORN-3', 'N', NULL, 'desk02', '2026-03-07 09:58'),
('APT-1007', 6, 1, 1, '2025-11-14 09:40', 20, 'CXL', 'Temp reg duplicate check', 'phone', 'MORN-2', 'N', 'Chart issue', 'desk01', '2025-11-13 15:00');

-- =========================================================
-- Visits
-- Statuses intentionally inconsistent
-- =========================================================

INSERT INTO visit_record (
    visit_no, patient_id, visit_type, dept_id, attending_provider, referred_by_text,
    visit_start_ts, visit_end_ts, arrival_mode, reason_text, chief_complaint,
    triage_note, status_text, source_system, external_visit_ref, created_ts, last_update_ts
) VALUES
('V-260301-01', 1, 'OPD', 1, 1, NULL,
 '2026-03-01 09:08', '2026-03-01 09:31', 'walkin', 'Follow-up for blood pressure', 'BP follow-up',
 'BP elevated at intake; no distress', 'CLOSED', 'frontdesk', 'FD-77881', '2026-03-01 09:08', '2026-03-01 09:31'),

('V-260303-01', 3, 'OPD', 1, 5, NULL,
 '2026-03-03 14:10', '2026-03-03 14:42', 'walkin', 'Rash, cough, itchy eyes', 'rash and cough',
 'Afebrile, mild wheeze', 'done', 'manual', NULL, '2026-03-03 14:10', '2026-03-03 14:46'),

('V-260305-ER1', 2, 'ER', 2, 2, 'self',
 '2026-03-05 22:14', '2026-03-06 01:05', 'private car', 'Chest tightness', 'chest tightness after work',
 'Arrived anxious, pain score 6/10', 'CLOSED', 'erdesk', 'ER-100044', '2026-03-05 22:14', '2026-03-06 01:06'),

('V-260306-IP1', 4, 'INPAT', 4, 3, 'clinic',
 '2026-03-06 08:20', NULL, 'wheelchair', 'Dizziness, weakness, poor intake', 'weakness',
 'Admit from clinic', 'OPEN', 'frontdesk', 'IP-44001', '2026-03-06 08:20', '2026-03-10 08:20'),

('V-260307-01', 5, 'OPD', 1, 1, NULL,
 '2026-03-07 10:00', '2026-03-07 10:20', 'walkin', 'School physical form', 'school form',
 'Well appearing', 'closed', 'frontdesk', NULL, '2026-03-07 10:00', '2026-03-07 10:25'),

-- Visit created against duplicate temp chart
('V-251114-09', 6, 'OPD', 1, 1, NULL,
 '2025-11-14 09:44', '2025-11-14 09:59', 'walkin', 'Fever and sore throat', 'fever',
 'Quick registration; ID not confirmed', 'COMPLETE', 'frontdesk', NULL, '2025-11-14 09:44', '2025-11-14 10:10'),

-- Visit on inactive chart
('V-240401-02', 8, 'OPD', 1, 1, NULL,
 '2024-04-01 11:05', '2024-04-01 11:18', 'walkin', 'Medication refill', 'refill',
 NULL, 'CLOSED', 'legacy_import', 'LEG-APR-22', '2024-04-02 08:00', '2024-04-02 08:10'),

-- Uses inactive/retired department/provider
('V-250930-OBS1', 2, 'OBS', 7, 7, NULL,
 '2025-09-30 18:20', '2025-09-30 23:30', 'ambulance', 'Observation for dizziness', 'dizziness',
 'Placed in observation bay', 'closed', 'old_obs_app', 'OBS-9981', '2025-09-30 18:20', '2025-10-01 06:00');

-- =========================================================
-- Admissions
-- Includes open stay and delayed discharge documentation
-- =========================================================

INSERT INTO admission_record (
    admit_no, visit_id, patient_id, admit_ts, discharge_ts, ward_name, room_no, bed_no,
    attending_team_text, admit_source, discharge_disp, isolation_flag, diet_text, nursing_comment
) VALUES
('ADM-260306-01', 4, 4, '2026-03-06 09:10', NULL, 'Medical Ward A', '203', 'B',
 'Med Team Blue', 'Clinic', NULL, 'N', 'Soft diet', 'Needs fall precautions'),

-- Old completed admission with sparse data
('ADM-250930-01', 8, 2, '2025-09-30 18:40', '2025-10-01 08:20', 'Observation Bay', 'OBS-2', '2',
 'Obs Team', 'ER', 'Home', 'N', NULL, 'Stayed overnight');

-- =========================================================
-- Diagnoses
-- Includes mixed coding habits and duplicates
-- =========================================================

INSERT INTO diagnosis_log (
    visit_id, admission_id, patient_id, dx_seq, dx_code_local, dx_code_old, dx_desc,
    dx_type, onset_text, chronicity_text, resolution_text, provider_id, entered_by, entered_ts
) VALUES
(1, NULL, 1, 1, 'HTN-01', '401A', 'High blood pressure, poorly controlled',
 'final', 'years', 'chronic', NULL, 1, 'msorrel', '2026-03-01 09:28'),
(1, NULL, 1, 2, 'WT-OBS', NULL, 'Weight gain',
 'working', '3 months', 'subacute', NULL, 1, 'msorrel', '2026-03-01 09:29'),
(2, NULL, 3, 1, 'ALRG-7', NULL, 'Allergic rash',
 'final', '2 days', 'acute', NULL, 5, 'tfen', '2026-03-03 14:35'),
(2, NULL, 3, 2, 'RESP-2', 'URI-1', 'Upper airway irritation with mild wheeze',
 'working', '1 week', 'acute', NULL, 5, 'tfen', '2026-03-03 14:36'),
(3, NULL, 2, 1, 'CP-UNK', NULL, 'Chest pain, cause not clear',
 'working', 'same day', 'acute', NULL, 2, 'hvale', '2026-03-05 22:30'),
(3, NULL, 2, 2, 'ANX-1', NULL, 'Anxiety possible contributor',
 'working', 'same day', 'acute', NULL, 2, 'hvale', '2026-03-05 22:45'),
(4, 1, 4, 1, 'DEHY-3', 'D-33', 'Dehydration',
 'final', '4 days', 'acute', NULL, 3, 'ebram', '2026-03-06 09:40'),
(4, 1, 4, 2, 'WEAK-2', NULL, 'General weakness',
 'working', '1 week', 'subacute', NULL, 3, 'ebram', '2026-03-06 09:41'),
(6, NULL, 6, 1, NULL, NULL, 'Viral throat illness',
 'final', '2 days', 'acute', 'resolved', 1, 'desk01', '2025-11-14 10:00'),
(8, 2, 2, 1, 'DIZ-1', NULL, 'Dizziness',
 'final', '1 day', 'acute', 'resolved', 7, 'oldobs', '2025-09-30 20:00');

-- =========================================================
-- Procedures
-- =========================================================

INSERT INTO procedure_log (
    visit_id, admission_id, patient_id, proc_code_local, proc_desc, proc_site_text,
    proc_ts, surgeon_provider_id, anaesthesia_text, theatre_text, implant_text, outcome_text, note_text
) VALUES
(3, NULL, 2, 'ER-EKG', 'Electrocardiogram', NULL,
 '2026-03-05 22:40', 2, NULL, NULL, NULL, 'Completed', 'Tracing filed in paper chart'),
(4, 1, 4, 'MIN-ULS', 'Bedside ultrasound review', 'abdomen',
 '2026-03-06 10:15', 3, 'none', 'Ward', NULL, 'Limited study', 'Machine image not linked'),
(8, 2, 2, 'OBS-IV', 'IV cannula insertion', 'left arm',
 '2025-09-30 19:00', 7, NULL, NULL, NULL, 'Completed', NULL);

-- =========================================================
-- Medications
-- Includes local codes, inconsistent routes/frequencies
-- =========================================================

INSERT INTO medication_order (
    visit_id, admission_id, patient_id, med_name_text, local_drug_code, dose_text, route_text,
    freq_text, prn_flag, indication_text, start_ts, stop_ts, prescribing_provider,
    pharmacy_status, dispense_qty_text, admin_instruction, caution_text
) VALUES
(1, NULL, 1, 'Amlodipine', 'DRG-1001', '5 mg', 'PO',
 'daily', 'N', 'blood pressure', '2026-03-01 09:30', NULL, 1,
 'filled', '30 tabs', 'Take in morning', 'Monitor ankle swelling'),

(2, NULL, 3, 'Cetirizine', 'DRG-4410', '10 mg', 'PO',
 'nightly', 'N', 'allergy symptoms', '2026-03-03 14:38', '2026-03-10 00:00', 5,
 'sent', '7 tabs', 'Avoid if too drowsy for school', NULL),

(2, NULL, 3, 'Salbutamol inhaler', NULL, '2 puffs', 'INH',
 'q6h prn', 'Y', 'wheeze', '2026-03-03 14:39', NULL, 5,
 'sent', '1 inhaler', 'Use spacer if available', 'Review technique'),

(4, 1, 4, 'IV Fluids NS', 'IV-001', '1 L', 'IV',
 'once', 'N', 'dehydration', '2026-03-06 09:20', '2026-03-06 12:20', 3,
 'new', NULL, 'Run over 3 hours', 'Watch intake/output'),

(8, 2, 2, 'Meclizine', NULL, '25mg', 'oral',
 't.i.d prn', 'Y', 'dizziness', '2025-09-30 20:10', '2025-10-01 08:00', 7,
 'filled', '6', 'Take if dizzy', NULL);

-- =========================================================
-- Lab orders
-- Includes incomplete orders and stale statuses
-- =========================================================

INSERT INTO lab_order (
    order_no, visit_id, admission_id, patient_id, ordering_provider, order_ts,
    specimen_type, test_panel_name, priority_text, order_status, external_order_ref, clinical_note
) VALUES
('LAB-260301-01', 1, NULL, 1, 1, '2026-03-01 09:18',
 'Blood', 'Basic chem + sugar', 'routine', 'done', 'LIS-90001', 'HTN review'),

('LAB-260305-ER1', 3, NULL, 2, 2, '2026-03-05 22:32',
 'Blood', 'Chest pain set', 'stat', 'done', 'LIS-90002', 'Rule out serious cause'),

('LAB-260306-IP1', 4, 1, 4, 3, '2026-03-06 09:25',
 'Blood', 'CMP/CBC', 'urgent', 'done', 'LIS-90003', 'Weakness poor intake'),

-- Ordered but never properly resulted
('LAB-260307-02', 5, NULL, 5, 1, '2026-03-07 10:05',
 'Urine', 'School screening dip', 'routine', 'drawn', NULL, 'School form'),

-- Legacy order with odd status value
('LAB-250930-OBS1', 8, 2, 2, 7, '2025-09-30 19:10',
 'Blood', 'Obs electrolytes', 'urgent', 'complete', 'OLDLIS-1188', 'dizziness workup');

-- =========================================================
-- Lab results
-- Includes numeric and text results, missing units, incomplete panels
-- =========================================================

INSERT INTO lab_result (
    lab_order_id, component_name, component_code_local, result_value_text, unit_text,
    ref_range_text, abnormal_flag, result_status, verified_by_text, result_ts, comment_text
) VALUES
(1, 'Glucose', 'GLU', '108', 'mg/dL', '70-110', 'N', 'final', 'Jon Ivers', '2026-03-01 11:05', NULL),
(1, 'Creatinine', 'CRE', '1.1', 'mg/dL', '0.6-1.3', 'N', 'final', 'Jon Ivers', '2026-03-01 11:05', NULL),
(1, 'Potassium', 'K', '3.4', 'mmol/L', '3.5-5.1', 'L', 'final', 'Jon Ivers', '2026-03-01 11:05', 'Slightly low'),

(2, 'Troponin', 'TROP', 'neg', NULL, 'neg', 'N', 'prelim', 'Night tech', '2026-03-05 23:10', 'Single test only'),
(2, 'WBC', 'WBC', '9.8', 'K/uL', '4.0-11.0', 'N', 'final', 'Jon Ivers', '2026-03-05 23:25', NULL),

(3, 'Sodium', 'NA', '132', 'mmol/L', '135-145', 'L', 'final', 'Jon Ivers', '2026-03-06 11:15', 'Likely low intake'),
(3, 'BUN', 'BUN', '27', 'mg/dL', '7-20', 'H', 'final', 'Jon Ivers', '2026-03-06 11:15', NULL),
(3, 'Hemoglobin', 'HGB', '13.2', 'g/dL', '12-16', 'N', 'final', 'Jon Ivers', '2026-03-06 11:15', NULL),

-- Partial old result set
(5, 'Sodium', 'NA', '136', NULL, NULL, 'N', 'Final', 'Old LIS', '2025-09-30 20:10', NULL);

-- =========================================================
-- Billing
-- Includes amounts that do not perfectly align
-- =========================================================

INSERT INTO invoice_header (
    invoice_no, patient_id, visit_id, admission_id, invoice_date, payer_name, payer_plan_text,
    billing_status, total_amount, discount_amount, amount_paid, note_text
) VALUES
('INV-260301-01', 1, 1, NULL, '2026-03-01', 'Self Pay', NULL,
 'closed', 145.00, 0.00, 145.00, 'Paid at cashier'),

('INV-260303-01', 3, 2, NULL, '2026-03-03', 'Self Pay', NULL,
 'open', 98.00, 5.00, 0.00, 'Family asked for itemized copy'),

('INV-260305-01', 2, 3, NULL, '2026-03-05', 'Oakbend Metal Works', 'Shop Floor Coverage',
 'sent', 410.00, 0.00, 0.00, 'Employer coverage on file'),

('INV-260306-01', 4, 4, 1, '2026-03-06', 'Local Senior Coop', 'Senior Assist Plan',
 'part-paid', 920.00, 45.00, 400.00, 'Pending room charge update'),

-- Legacy duplicate invoice-ish artifact
('INV-OLD-998', 8, 7, NULL, '2024-04-01', 'Self Pay', NULL,
 'closed', 40.00, 0.00, 40.00, 'Imported from legacy cashier');

INSERT INTO billing_line (
    invoice_id, charge_code, charge_desc, service_date, qty, unit_price, line_amount,
    revenue_bucket, line_status, ordering_dept_text
) VALUES
(1, 'CONSULT', 'Clinic consultation', '2026-03-01', 1, 80.00, 80.00, 'consult', 'posted', 'General Clinic'),
(1, 'LABBASIC', 'Basic chemistry tests', '2026-03-01', 1, 50.00, 50.00, 'lab', 'posted', 'Laboratory'),
(1, 'ADM-FEE', 'Admin and chart fee', '2026-03-01', 1, 15.00, 15.00, 'admin', 'posted', 'General Clinic'),

(2, 'CONSULT', 'Clinic consultation', '2026-03-03', 1, 75.00, 75.00, 'consult', 'posted', 'General Clinic'),
(2, 'MED-OUT', 'Outpatient medication', '2026-03-03', 1, 23.00, 23.00, 'med', 'posted', 'Pharmacy'),

(3, 'ERCONS', 'ER physician review', '2026-03-05', 1, 180.00, 180.00, 'consult', 'posted', 'Emergency Room'),
(3, 'EKG', 'ECG tracing', '2026-03-05', 1, 95.00, 95.00, 'procedure', 'posted', 'Emergency Room'),
(3, 'LABSTAT', 'Stat lab work', '2026-03-05', 1, 135.00, 135.00, 'lab', 'posted', 'Laboratory'),

(4, 'ROOM', 'Ward bed charge', '2026-03-06', 1, 250.00, 250.00, 'room', 'posted', 'Medical Ward A'),
(4, 'CONSULT-IP', 'Inpatient review', '2026-03-06', 1, 120.00, 120.00, 'consult', 'posted', 'Medical Ward A'),
(4, 'IVSUP', 'IV supplies', '2026-03-06', 1, 65.00, 65.00, 'supply', 'posted', 'Medical Ward A'),
(4, 'LABCMP', 'CMP/CBC', '2026-03-06', 1, 140.00, 140.00, 'lab', 'posted', 'Laboratory'),

(5, 'CONSULT', 'Clinic consultation', '2024-04-01', 1, 40.00, 40.00, 'consult', 'posted', 'General Clinic');

-- =========================================================
-- Documents
-- Includes unsigned note, scan ref, sparse content
-- =========================================================

INSERT INTO document_store (
    patient_id, visit_id, admission_id, doc_type, doc_title, author_name,
    author_provider_id, created_ts, content_text, signed_flag, scan_ref_text
) VALUES
(1, 1, NULL, 'clinic_note', 'Blood Pressure Follow-up', 'Dr. Mina Sorrel', 1, '2026-03-01 09:35',
 'Patient reports missed doses last month. No chest pain. Advised diet review, repeat in 4 weeks.', 'Y', NULL),

(2, 3, NULL, 'er_note', 'ER Quick Note', 'Dr. Harun Vale', 2, '2026-03-05 23:00',
 'Middle-aged male with chest tightness after work shift. ECG done. Initial troponin negative. Symptoms eased with rest.', 'N', NULL),

(4, 4, 1, 'admit_note', 'Admission Summary', 'Dr. Elio Bram', 3, '2026-03-06 10:05',
 'Admitted for weakness and dehydration. Start IV fluid, monitor electrolytes, encourage oral intake.', 'Y', 'SCAN-203-778'),

(3, 2, NULL, 'clinic_note', 'Rash Visit', 'Talia Fen', 5, '2026-03-03 14:45',
 'Likely allergic process. Trial antihistamine. Return if breathing worse or rash spreads.', 'Y', NULL),

(6, 6, NULL, 'paper_scan', 'Walk-in sheet', 'front desk', NULL, '2025-11-14 10:02',
 'Name likely Lena Damar. Temp chart created due to no ID card at desk.', 'N', 'IMG-114-7781');

-- =========================================================
-- Merge log
-- =========================================================

INSERT INTO patient_merge_log (
    source_chart_no, target_chart_no, merge_ts, merge_reason, performed_by, review_flag
) VALUES
('TMP-7781', 'CH-000145', '2025-12-01 11:05', 'Likely duplicate from temp registration', 'regsup1', 'Y'),
('CH-000150', 'CH-000149', '2026-03-07 11:30', 'Child registered twice with spelling variation', 'desklead', 'N'),
('CH-000099', 'CH-000148', '2024-04-02 09:10', 'Old chart version merged to active chart', 'legacyconv', 'Y');

-- =========================================================
-- Integration outbox
-- Includes retries, dupes, stale failures
-- =========================================================

INSERT INTO integration_outbox (
    entity_name, entity_pk, action_type, payload_json, source_system,
    enqueue_ts, processed_flag, processed_ts, retry_count, last_attempt_ts, dedupe_key, error_text
) VALUES
('patient_master', '1', 'update',
 '{"chart_no":"CH-000145","changed_fields":["phone_mobile","last_update_ts"]}',
 'frontdesk',
 '2026-03-10 11:06', 'N', NULL, 0, NULL, 'patient-1-20260310-1106', NULL),

('visit_record', '3', 'insert',
 '{"visit_no":"V-260305-ER1","visit_type":"ER","status_text":"CLOSED"}',
 'erdesk',
 '2026-03-06 01:06', 'N', NULL, 2, '2026-03-06 01:20', 'visit-3-insert', 'Timeout to downstream endpoint'),

('lab_result', '6', 'insert',
 '{"order_no":"LAB-260306-IP1","component_name":"Sodium","result_value_text":"132"}',
 'lis',
 '2026-03-06 11:16', 'Y', '2026-03-06 11:17', 0, '2026-03-06 11:17', 'labres-6-insert', NULL),

-- duplicate-ish message for same event
('lab_result', '6', 'insert',
 '{"order_no":"LAB-260306-IP1","component_name":"Sodium","result_value_text":"132"}',
 'lis',
 '2026-03-06 11:16', 'N', NULL, 1, '2026-03-06 11:19', 'labres-6-insert', 'Duplicate message detected'),

-- stale failed merge notification
('patient_merge_log', '2', 'insert',
 '{"source_chart_no":"CH-000150","target_chart_no":"CH-000149"}',
 'regdesk',
 '2026-03-07 11:31', 'N', NULL, 4, '2026-03-08 09:00', 'merge-2', 'Remote API 500'),

-- outdated inactive patient event
('patient_master', '8', 'update',
 '{"chart_no":"CH-000099","active_flag":"N","merge_target_chart":"CH-000148"}',
 'legacy_import',
 '2024-04-02 09:11', 'N', NULL, 7, '2024-04-10 08:00', 'patient-8-merge', 'Deprecated endpoint');

-- =========================================================
-- Helpful views for realistic integration exercises
-- =========================================================

CREATE OR REPLACE VIEW vw_patient_possible_duplicates AS
SELECT
    p1.patient_id AS patient_id_1,
    p1.chart_no   AS chart_no_1,
    p2.patient_id AS patient_id_2,
    p2.chart_no   AS chart_no_2,
    p1.last_name,
    p1.first_name,
    p1.birth_date,
    p1.phone_mobile AS phone_1,
    p2.phone_mobile AS phone_2,
    p1.mpi_hint
FROM patient_master p1
JOIN patient_master p2
  ON p1.patient_id < p2.patient_id
 AND (
      (p1.mpi_hint IS NOT NULL AND p1.mpi_hint = p2.mpi_hint)
      OR (
          p1.last_name = p2.last_name
          AND p1.first_name = p2.first_name
          AND p1.birth_date = p2.birth_date
      )
 )
WHERE COALESCE(p1.active_flag, 'Y') <> 'N'
   OR COALESCE(p2.active_flag, 'Y') <> 'N';

CREATE OR REPLACE VIEW vw_open_or_inconsistent_visits AS
SELECT
    v.visit_id,
    v.visit_no,
    p.chart_no,
    p.last_name,
    p.first_name,
    v.visit_type,
    v.visit_start_ts,
    v.visit_end_ts,
    v.status_text,
    d.dept_name,
    pr.full_name AS provider_name
FROM visit_record v
JOIN patient_master p ON p.patient_id = v.patient_id
LEFT JOIN department_ref d ON d.dept_id = v.dept_id
LEFT JOIN provider_directory pr ON pr.provider_id = v.attending_provider
WHERE
    v.visit_end_ts IS NULL
    OR LOWER(COALESCE(v.status_text, '')) NOT IN ('closed', 'done', 'open', 'complete')
    OR (v.visit_end_ts IS NOT NULL AND LOWER(COALESCE(v.status_text, '')) = 'open');

CREATE OR REPLACE VIEW vw_invoice_recalc_check AS
SELECT
    ih.invoice_id,
    ih.invoice_no,
    ih.total_amount,
    ih.discount_amount,
    COALESCE(SUM(bl.line_amount), 0) AS summed_lines,
    (COALESCE(SUM(bl.line_amount), 0) - COALESCE(ih.discount_amount, 0)) AS expected_total,
    (ih.total_amount - (COALESCE(SUM(bl.line_amount), 0) - COALESCE(ih.discount_amount, 0))) AS variance
FROM invoice_header ih
LEFT JOIN billing_line bl ON bl.invoice_id = ih.invoice_id
GROUP BY ih.invoice_id, ih.invoice_no, ih.total_amount, ih.discount_amount;

CREATE OR REPLACE VIEW vw_open_integration_events AS
SELECT *
FROM integration_outbox
WHERE processed_flag = 'N'
ORDER BY enqueue_ts ASC;