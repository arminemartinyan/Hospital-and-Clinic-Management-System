

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'HospitalDB')
BEGIN
    ALTER DATABASE HospitalDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE HospitalDB;
    PRINT '[INFO] Existing HospitalDB dropped.';
END
GO

CREATE DATABASE HospitalDB;
GO
USE HospitalDB;
GO

PRINT '========================================';
PRINT ' SECTION 1 — DDL: TABLE CREATION';
PRINT '========================================';

-- ─────────────────────────────────────────────────────────────
-- TABLE 1: patients
-- ─────────────────────────────────────────────────────────────
CREATE TABLE patients (
    PatientID         INT           NOT NULL IDENTITY(1,1),
    FirstName         VARCHAR(50)   NOT NULL,
    LastName          VARCHAR(50)   NOT NULL,
    Email             VARCHAR(100)  NOT NULL,
    Phone             VARCHAR(20)   NULL,
    DateOfBirth       DATE          NOT NULL,
    Gender            VARCHAR(10)   NOT NULL,
    RegistrationDate  DATETIME      NOT NULL DEFAULT GETDATE(),
    CONSTRAINT pk_patients       PRIMARY KEY (PatientID),
    CONSTRAINT uq_patients_email UNIQUE (Email),
    CONSTRAINT chk_patients_email  CHECK (Email LIKE '%@%.%'),
    CONSTRAINT chk_patients_gender CHECK (Gender IN ('Male','Female','Other'))
);
PRINT '[DDL] Table patients created.';

-- ─────────────────────────────────────────────────────────────
-- TABLE 2: doctors
-- ─────────────────────────────────────────────────────────────
CREATE TABLE doctors (
    DoctorID         INT           NOT NULL IDENTITY(1,1),
    FirstName        VARCHAR(50)   NOT NULL,
    LastName         VARCHAR(50)   NOT NULL,
    LicenseNumber    VARCHAR(30)   NOT NULL,
    Specialization   VARCHAR(100)  NOT NULL,
    Rating           FLOAT         NOT NULL DEFAULT 5.0,
    Status           VARCHAR(20)   NOT NULL DEFAULT 'Available',
    CONSTRAINT pk_doctors            PRIMARY KEY (DoctorID),
    CONSTRAINT uq_doctors_license    UNIQUE (LicenseNumber),
    CONSTRAINT chk_doctors_rating    CHECK (Rating >= 0.0 AND Rating <= 5.0),
    CONSTRAINT chk_doctors_status    CHECK (Status IN ('Available','Busy','Off-Duty'))
);
PRINT '[DDL] Table doctors created.';

-- ─────────────────────────────────────────────────────────────
-- TABLE 3: departments
-- ─────────────────────────────────────────────────────────────
CREATE TABLE departments (
    DepartmentID   INT           NOT NULL IDENTITY(1,1),
    Name           VARCHAR(100)  NOT NULL,
    Location       VARCHAR(100)  NOT NULL,
    CONSTRAINT pk_departments PRIMARY KEY (DepartmentID)
);
PRINT '[DDL] Table departments created.';

-- ─────────────────────────────────────────────────────────────
-- TABLE 4: rooms
-- ─────────────────────────────────────────────────────────────
CREATE TABLE rooms (
    RoomID         INT           NOT NULL IDENTITY(1,1),
    DepartmentID   INT           NOT NULL,
    RoomNumber     VARCHAR(20)   NOT NULL,
    RoomType       VARCHAR(30)   NOT NULL,
    Capacity       INT           NOT NULL,
    Status         VARCHAR(20)   NOT NULL DEFAULT 'Available',
    CONSTRAINT pk_rooms          PRIMARY KEY (RoomID),
    CONSTRAINT uq_rooms_number   UNIQUE (RoomNumber),
    CONSTRAINT fk_rooms_dept     FOREIGN KEY (DepartmentID) REFERENCES departments(DepartmentID),
    CONSTRAINT chk_rooms_type    CHECK (RoomType IN ('General','ICU','Operating','Recovery','Consultation')),
    CONSTRAINT chk_rooms_cap     CHECK (Capacity >= 1 AND Capacity <= 20),
    CONSTRAINT chk_rooms_status  CHECK (Status IN ('Available','Occupied','Maintenance'))
);
PRINT '[DDL] Table rooms created.';

-- ─────────────────────────────────────────────────────────────
-- TABLE 5: appointments
-- ─────────────────────────────────────────────────────────────
CREATE TABLE appointments (
    AppointmentID    INT           NOT NULL IDENTITY(1,1),
    PatientID        INT           NOT NULL,
    DoctorID         INT           NOT NULL,
    DepartmentID     INT           NOT NULL,
    ScheduledTime    DATETIME      NOT NULL,
    EndTime          DATETIME      NULL,
    Duration         INT           NULL,   -- auto-computed by trigger
    ReasonForVisit   VARCHAR(300)  NOT NULL,
    Status           VARCHAR(20)   NOT NULL DEFAULT 'Scheduled',
    ConsultationFee  FLOAT         NOT NULL DEFAULT 0,
    PromoID          INT           NULL,
    CONSTRAINT pk_appointments       PRIMARY KEY (AppointmentID),
    CONSTRAINT fk_appt_patient       FOREIGN KEY (PatientID)    REFERENCES patients(PatientID)    ON DELETE CASCADE,
    CONSTRAINT fk_appt_doctor        FOREIGN KEY (DoctorID)     REFERENCES doctors(DoctorID),
    CONSTRAINT fk_appt_dept          FOREIGN KEY (DepartmentID) REFERENCES departments(DepartmentID),
    CONSTRAINT chk_appt_status       CHECK (Status IN ('Scheduled','Completed','Cancelled')),
    CONSTRAINT chk_appt_fee          CHECK (ConsultationFee >= 0)
);
PRINT '[DDL] Table appointments created.';

-- ─────────────────────────────────────────────────────────────
-- TABLE 6: bills
-- ─────────────────────────────────────────────────────────────
CREATE TABLE bills (
    BillID          INT           NOT NULL IDENTITY(1,1),
    AppointmentID   INT           NOT NULL,
    Amount          FLOAT         NOT NULL,
    Method          VARCHAR(20)   NOT NULL,
    BillDate        DATETIME      NOT NULL DEFAULT GETDATE(),
    Status          VARCHAR(20)   NOT NULL DEFAULT 'Pending',
    CONSTRAINT pk_bills          PRIMARY KEY (BillID),
    CONSTRAINT fk_bills_appt     FOREIGN KEY (AppointmentID) REFERENCES appointments(AppointmentID) ON DELETE CASCADE,
    CONSTRAINT chk_bills_amount  CHECK (Amount >= 0),
    CONSTRAINT chk_bills_method  CHECK (Method IN ('Cash','Card','Insurance')),
    CONSTRAINT chk_bills_status  CHECK (Status IN ('Paid','Pending','Failed'))
);
PRINT '[DDL] Table bills created.';

-- ─────────────────────────────────────────────────────────────
-- TABLE 7: ratings
-- ─────────────────────────────────────────────────────────────
CREATE TABLE ratings (
    RatingID        INT           NOT NULL IDENTITY(1,1),
    AppointmentID   INT           NOT NULL,
    DoctorRating    INT           NOT NULL,
    PatientRating   INT           NULL,
    Comment         VARCHAR(500)  NULL,
    CONSTRAINT pk_ratings          PRIMARY KEY (RatingID),
    CONSTRAINT fk_ratings_appt     FOREIGN KEY (AppointmentID) REFERENCES appointments(AppointmentID) ON DELETE CASCADE,
    CONSTRAINT uq_ratings_appt     UNIQUE (AppointmentID),
    CONSTRAINT chk_ratings_doctor  CHECK (DoctorRating >= 1 AND DoctorRating <= 5),
    CONSTRAINT chk_ratings_patient CHECK (PatientRating IS NULL OR (PatientRating >= 1 AND PatientRating <= 5))
);
PRINT '[DDL] Table ratings created.';

-- ─────────────────────────────────────────────────────────────
-- TABLE 8: promotions
-- ─────────────────────────────────────────────────────────────
CREATE TABLE promotions (
    PromoID     INT           NOT NULL IDENTITY(1,1),
    Code        VARCHAR(30)   NOT NULL,
    Discount    FLOAT         NOT NULL,
    ExpiryDate  DATETIME      NOT NULL,
    CONSTRAINT pk_promotions      PRIMARY KEY (PromoID),
    CONSTRAINT uq_promotions_code UNIQUE (Code),
    CONSTRAINT chk_promo_discount CHECK (Discount >= 0 AND Discount <= 100)
);
PRINT '[DDL] Table promotions created.';

-- Add FK from appointments to promotions now (promotions table created after)
ALTER TABLE appointments
    ADD CONSTRAINT fk_appt_promo FOREIGN KEY (PromoID) REFERENCES promotions(PromoID);
GO

PRINT '========================================';
PRINT ' SECTION 2 — DML: DATA INSERTION';
PRINT '========================================';

-- ── patients (42 rows) ────────────────────────────────────────
INSERT INTO patients (FirstName, LastName, Email, Phone, DateOfBirth, Gender, RegistrationDate) VALUES
('James','Anderson','james.anderson@email.com','555-2001','1985-03-12','Male','2023-01-05 09:00:00'),
('Sophia','Martinez','sophia.martinez@email.com','555-2002','1992-07-24','Female','2023-01-10 10:30:00'),
('Liam','Thompson','liam.thompson@email.com',NULL,'1978-11-05','Male','2023-01-15 11:00:00'),
('Olivia','Wilson','olivia.wilson@email.com','555-2004','2000-02-18','Female','2023-02-01 08:45:00'),
('Noah','Brown','noah.brown@email.com','555-2005','1990-06-30','Male','2023-02-10 09:30:00'),
('Emma','Davis','emma.davis@email.com','555-2006','1988-09-14','Female','2023-02-20 14:00:00'),
('Oliver','Garcia','oliver.garcia@email.com',NULL,'1975-04-22','Male','2023-03-01 10:00:00'),
('Ava','Rodriguez','ava.rodriguez@email.com','555-2008','1995-12-01','Female','2023-03-05 11:30:00'),
('Elijah','Miller','elijah.miller@email.com','555-2009','1983-08-17','Male','2023-03-12 09:00:00'),
('Charlotte','Taylor','charlotte.taylor@email.com','555-2010','1998-01-25','Female','2023-03-20 10:00:00'),
('William','Harris','william.harris@email.com',NULL,'1970-05-09','Male','2023-04-01 08:00:00'),
('Amelia','Clark','amelia.clark@email.com','555-2012','2002-10-30','Female','2023-04-10 09:00:00'),
('James','Lewis','james.lewis@email.com','555-2013','1987-03-15','Male','2023-04-15 11:00:00'),
('Mia','Robinson','mia.robinson@email.com','555-2014','1993-07-08','Female','2023-04-20 10:30:00'),
('Benjamin','Walker','benjamin.walker@email.com','555-2015','1980-12-20','Male','2023-05-01 09:00:00'),
('Harper','Young','harper.young@email.com',NULL,'1997-04-11','Female','2023-05-10 10:00:00'),
('Lucas','Hall','lucas.hall@email.com','555-2017','1974-09-03','Male','2023-05-15 14:00:00'),
('Evelyn','Allen','evelyn.allen@email.com','555-2018','2001-06-27','Female','2023-05-22 09:30:00'),
('Henry','Hernandez','henry.hernandez@email.com','555-2019','1965-01-14','Male','2023-06-01 08:00:00'),
('Abigail','King','abigail.king@email.com','555-2020','1999-11-05','Female','2023-06-10 10:00:00'),
('Alexander','Wright','alexander.wright@email.com',NULL,'1991-02-28','Male','2023-06-15 11:30:00'),
('Emily','Scott','emily.scott@email.com','555-2022','1986-08-19','Female','2023-06-20 09:00:00'),
('Michael','Torres','michael.torres@email.com','555-2023','1979-05-07','Male','2023-07-01 08:30:00'),
('Elizabeth','Nguyen','elizabeth.nguyen@email.com','555-2024','1994-03-16','Female','2023-07-05 10:00:00'),
('Daniel','Hill','daniel.hill@email.com','555-2025','1982-10-12','Male','2023-07-10 09:00:00'),
('Sofia','Flores','sofia.flores@email.com',NULL,'2003-07-21','Female','2023-07-15 11:00:00'),
('Matthew','Green','matthew.green@email.com','555-2027','1977-12-04','Male','2023-07-20 10:30:00'),
('Avery','Adams','avery.adams@email.com','555-2028','1996-09-29','Female','2023-08-01 09:00:00'),
('Jackson','Nelson','jackson.nelson@email.com','555-2029','1989-04-18','Male','2023-08-10 10:00:00'),
('Scarlett','Carter','scarlett.carter@email.com','555-2030','2001-01-07','Female','2023-08-15 09:30:00'),
('Sebastian','Mitchell','sebastian.mitchell@email.com',NULL,'1973-06-25','Male','2023-09-01 08:00:00'),
('Victoria','Perez','victoria.perez@email.com','555-2032','1998-08-13','Female','2023-09-10 10:00:00'),
('Aiden','Roberts','aiden.roberts@email.com','555-2033','1984-03-02','Male','2023-09-15 11:00:00'),
('Grace','Turner','grace.turner@email.com','555-2034','1990-11-17','Female','2023-09-20 09:00:00'),
('Carter','Phillips','carter.phillips@email.com','555-2035','1967-07-08','Male','2023-10-01 08:30:00'),
('Chloe','Campbell','chloe.campbell@email.com',NULL,'2002-05-23','Female','2023-10-10 10:00:00'),
('Wyatt','Parker','wyatt.parker@email.com','555-2037','1981-09-11','Male','2023-10-15 09:00:00'),
('Zoey','Evans','zoey.evans@email.com','555-2038','1995-02-06','Female','2023-10-20 11:00:00'),
('Dylan','Edwards','dylan.edwards@email.com','555-2039','1976-12-30','Male','2023-11-01 08:00:00'),
('Nora','Collins','nora.collins@email.com','555-2040','1993-06-14','Female','2023-11-10 10:00:00'),
('Levi','Stewart','levi.stewart@email.com',NULL,'1988-04-03','Male','2023-11-15 09:30:00'),
('Lily','Sanchez','lily.sanchez@email.com','555-2042','2000-09-22','Female','2023-11-20 10:00:00');
PRINT '[DML] 42 patients inserted.';

-- ── doctors (42 rows) ─────────────────────────────────────────
INSERT INTO doctors (FirstName, LastName, LicenseNumber, Specialization, Rating, Status) VALUES
('Dr. Sarah','Johnson','LIC-D0001','Cardiology',4.9,'Available'),
('Dr. Michael','Lee','LIC-D0002','Neurology',4.8,'Available'),
('Dr. Emily','Chen','LIC-D0003','Pediatrics',4.7,'Busy'),
('Dr. Robert','Patel','LIC-D0004','Orthopedics',4.6,'Available'),
('Dr. Laura','Kim','LIC-D0005','Dermatology',4.8,'Available'),
('Dr. David','Moore','LIC-D0006','General Surgery',4.5,'Busy'),
('Dr. Jessica','White','LIC-D0007','Oncology',4.9,'Available'),
('Dr. Christopher','Brown','LIC-D0008','Radiology',4.4,'Off-Duty'),
('Dr. Amanda','Davis','LIC-D0009','Psychiatry',4.7,'Available'),
('Dr. James','Wilson','LIC-D0010','Endocrinology',4.6,'Available'),
('Dr. Linda','Martinez','LIC-D0011','Gastroenterology',4.8,'Busy'),
('Dr. Kevin','Anderson','LIC-D0012','Urology',4.5,'Available'),
('Dr. Rachel','Thompson','LIC-D0013','Gynecology',4.9,'Available'),
('Dr. Mark','Harris','LIC-D0014','Pulmonology',4.7,'Available'),
('Dr. Patricia','Taylor','LIC-D0015','Anesthesiology',4.6,'Off-Duty'),
('Dr. Steven','Garcia','LIC-D0016','Nephrology',4.8,'Available'),
('Dr. Melissa','Rodriguez','LIC-D0017','Hematology',4.5,'Available'),
('Dr. Daniel','Lewis','LIC-D0018','Emergency Medicine',4.9,'Busy'),
('Dr. Karen','Walker','LIC-D0019','Rheumatology',4.6,'Available'),
('Dr. Joseph','Hall','LIC-D0020','Ophthalmology',4.7,'Available'),
('Dr. Sandra','Allen','LIC-D0021','ENT',4.8,'Available'),
('Dr. Brian','Young','LIC-D0022','Cardiology',4.5,'Busy'),
('Dr. Donna','Hernandez','LIC-D0023','Neurology',4.7,'Available'),
('Dr. Edward','King','LIC-D0024','Pediatrics',4.6,'Available'),
('Dr. Betty','Wright','LIC-D0025','Orthopedics',4.9,'Available'),
('Dr. Timothy','Scott','LIC-D0026','Dermatology',4.5,'Off-Duty'),
('Dr. Helen','Torres','LIC-D0027','General Surgery',4.8,'Available'),
('Dr. Gary','Nguyen','LIC-D0028','Oncology',4.7,'Available'),
('Dr. Susan','Hill','LIC-D0029','Radiology',4.6,'Busy'),
('Dr. Kenneth','Flores','LIC-D0030','Psychiatry',4.8,'Available'),
('Dr. Dorothy','Green','LIC-D0031','Endocrinology',4.9,'Available'),
('Dr. Ronald','Adams','LIC-D0032','Gastroenterology',4.5,'Available'),
('Dr. Carol','Nelson','LIC-D0033','Urology',4.7,'Off-Duty'),
('Dr. Anthony','Carter','LIC-D0034','Gynecology',4.6,'Available'),
('Dr. Deborah','Mitchell','LIC-D0035','Pulmonology',4.8,'Available'),
('Dr. Paul','Perez','LIC-D0036','Anesthesiology',4.9,'Busy'),
('Dr. Barbara','Roberts','LIC-D0037','Nephrology',4.5,'Available'),
('Dr. George','Turner','LIC-D0038','Hematology',4.7,'Available'),
('Dr. Lisa','Phillips','LIC-D0039','Emergency Medicine',4.6,'Available'),
('Dr. Larry','Campbell','LIC-D0040','Rheumatology',4.8,'Available'),
('Dr. Nancy','Parker','LIC-D0041','Ophthalmology',4.5,'Busy'),
('Dr. Frank','Evans','LIC-D0042','ENT',4.9,'Available');
PRINT '[DML] 42 doctors inserted.';

-- ── departments (42 rows) ─────────────────────────────────────
INSERT INTO departments (Name, Location) VALUES
('Cardiology','Building A, Floor 3'),
('Neurology','Building A, Floor 4'),
('Pediatrics','Building B, Floor 1'),
('Orthopedics','Building B, Floor 2'),
('Dermatology','Building C, Floor 1'),
('General Surgery','Building D, Floor 2'),
('Oncology','Building D, Floor 3'),
('Radiology','Building E, Floor 1'),
('Psychiatry','Building F, Floor 2'),
('Endocrinology','Building A, Floor 5'),
('Gastroenterology','Building B, Floor 3'),
('Urology','Building C, Floor 2'),
('Gynecology','Building C, Floor 3'),
('Pulmonology','Building D, Floor 1'),
('Anesthesiology','Building D, Floor 4'),
('Nephrology','Building E, Floor 2'),
('Hematology','Building E, Floor 3'),
('Emergency Medicine','Building F, Floor 1'),
('Rheumatology','Building A, Floor 2'),
('Ophthalmology','Building B, Floor 4'),
('ENT','Building C, Floor 4'),
('Cardiology Research','Building A, Floor 6'),
('Neurology Research','Building A, Floor 7'),
('Pediatric ICU','Building B, Floor 5'),
('Surgical Recovery','Building D, Floor 5'),
('Outpatient Clinic','Building G, Floor 1'),
('Inpatient Ward','Building G, Floor 2'),
('Laboratory','Building H, Floor 1'),
('Pharmacy','Building H, Floor 2'),
('Imaging Center','Building E, Floor 4'),
('Rehabilitation','Building F, Floor 3'),
('Palliative Care','Building F, Floor 4'),
('Blood Bank','Building H, Floor 3'),
('Pathology','Building H, Floor 4'),
('Nuclear Medicine','Building E, Floor 5'),
('Transplant Unit','Building D, Floor 6'),
('Vascular Surgery','Building D, Floor 7'),
('Thoracic Surgery','Building D, Floor 8'),
('Plastic Surgery','Building C, Floor 5'),
('Pain Management','Building F, Floor 5'),
('Clinical Nutrition','Building G, Floor 3'),
('Infection Control','Building G, Floor 4');
PRINT '[DML] 42 departments inserted.';

-- ── rooms (42 rows) ───────────────────────────────────────────
INSERT INTO rooms (DepartmentID, RoomNumber, RoomType, Capacity, Status) VALUES
(1,'A301','Consultation',1,'Available'),
(1,'A302','Consultation',1,'Occupied'),
(2,'A401','Consultation',1,'Available'),
(2,'A402','Consultation',1,'Available'),
(3,'B101','General',4,'Occupied'),
(3,'B102','General',4,'Available'),
(4,'B201','Consultation',1,'Available'),
(4,'B202','Consultation',1,'Occupied'),
(5,'C101','Consultation',1,'Available'),
(5,'C102','Consultation',1,'Available'),
(6,'D201','Operating',1,'Available'),
(6,'D202','Operating',1,'Occupied'),
(7,'D301','General',2,'Available'),
(7,'D302','General',2,'Available'),
(8,'E101','Consultation',1,'Available'),
(8,'E102','Consultation',1,'Available'),
(9,'F201','Consultation',1,'Occupied'),
(9,'F202','Consultation',1,'Available'),
(10,'A501','Consultation',1,'Available'),
(10,'A502','Consultation',1,'Available'),
(11,'B301','Consultation',1,'Available'),
(11,'B302','Consultation',1,'Occupied'),
(12,'C201','Consultation',1,'Available'),
(12,'C202','Consultation',1,'Available'),
(13,'C301','Consultation',1,'Available'),
(13,'C302','Consultation',1,'Available'),
(14,'D101','General',3,'Available'),
(14,'D102','General',3,'Occupied'),
(15,'D401','Operating',1,'Available'),
(15,'D402','Operating',1,'Maintenance'),
(16,'E201','Consultation',1,'Available'),
(16,'E202','Consultation',1,'Available'),
(17,'E301','General',2,'Available'),
(17,'E302','General',2,'Available'),
(18,'F101','General',6,'Occupied'),
(18,'F102','General',6,'Available'),
(19,'A201','Consultation',1,'Available'),
(19,'A202','Consultation',1,'Available'),
(20,'B401','Consultation',1,'Available'),
(20,'B402','Consultation',1,'Available'),
(21,'C401','Consultation',1,'Available'),
(21,'C402','Consultation',1,'Occupied');
PRINT '[DML] 42 rooms inserted.';

-- ── promotions (42 rows) ──────────────────────────────────────
INSERT INTO promotions (Code, Discount, ExpiryDate) VALUES
('WELCOME10',10.0,'2025-12-31 23:59:59'),
('SENIOR20',20.0,'2025-06-30 23:59:59'),
('CHECKUP15',15.0,'2025-09-30 23:59:59'),
('FIRSTVISIT25',25.0,'2025-03-31 23:59:59'),
('INSURANCE5',5.0,'2025-12-31 23:59:59'),
('CARDIO10',10.0,'2025-08-31 23:59:59'),
('NEURO15',15.0,'2025-07-31 23:59:59'),
('PEDS20',20.0,'2025-10-31 23:59:59'),
('ORTHO10',10.0,'2025-05-31 23:59:59'),
('DERM5',5.0,'2025-11-30 23:59:59'),
('SURGERY30',30.0,'2025-04-30 23:59:59'),
('ONCO25',25.0,'2025-12-31 23:59:59'),
('RADIO10',10.0,'2025-06-30 23:59:59'),
('PSYCH15',15.0,'2025-09-30 23:59:59'),
('ENDO10',10.0,'2025-08-31 23:59:59'),
('GI15',15.0,'2025-07-31 23:59:59'),
('UROL10',10.0,'2025-10-31 23:59:59'),
('GYNO20',20.0,'2025-05-31 23:59:59'),
('PULM10',10.0,'2025-11-30 23:59:59'),
('NEPH5',5.0,'2025-12-31 23:59:59'),
('HEMA15',15.0,'2025-06-30 23:59:59'),
('EM10',10.0,'2025-09-30 23:59:59'),
('RHEUM20',20.0,'2025-08-31 23:59:59'),
('OPTH10',10.0,'2025-07-31 23:59:59'),
('ENT5',5.0,'2025-10-31 23:59:59'),
('SAVE50',50.0,'2024-01-01 00:00:01'),  -- expired
('EARLYBIRD',12.0,'2024-03-01 00:00:01'), -- expired
('HOLIDAY10',10.0,'2024-06-01 00:00:01'), -- expired
('WINTER15',15.0,'2024-09-01 00:00:01'), -- expired
('FALL20',20.0,'2024-12-01 00:00:01'),   -- expired
('SPRING10',10.0,'2025-12-31 23:59:59'),
('SUMMER15',15.0,'2025-12-31 23:59:59'),
('ANNUAL20',20.0,'2025-12-31 23:59:59'),
('LOYALTY25',25.0,'2025-12-31 23:59:59'),
('REFER10',10.0,'2025-12-31 23:59:59'),
('STUDENT15',15.0,'2025-12-31 23:59:59'),
('CORP20',20.0,'2025-12-31 23:59:59'),
('VIP30',30.0,'2025-12-31 23:59:59'),
('WEEKEND10',10.0,'2025-12-31 23:59:59'),
('MORNING5',5.0,'2025-12-31 23:59:59'),
('EVENING5',5.0,'2025-12-31 23:59:59'),
('ONLINE10',10.0,'2025-12-31 23:59:59');
PRINT '[DML] 42 promotions inserted.';

-- ── appointments (42 rows: 40 Completed, 1 Scheduled, 1 Cancelled) ──
INSERT INTO appointments (PatientID, DoctorID, DepartmentID, ScheduledTime, EndTime, Duration, ReasonForVisit, Status, ConsultationFee, PromoID) VALUES
(1,1,1,'2024-01-02 09:00:00','2024-01-02 09:45:00',45,'Chest pain evaluation','Completed',150.00,1),
(2,2,2,'2024-01-03 10:00:00','2024-01-03 10:30:00',30,'Migraine follow-up','Completed',180.00,NULL),
(3,3,3,'2024-01-04 11:00:00','2024-01-04 11:40:00',40,'Child wellness check','Completed',120.00,8),
(4,4,4,'2024-01-05 09:30:00','2024-01-05 10:15:00',45,'Knee pain assessment','Completed',160.00,NULL),
(5,5,5,'2024-01-06 14:00:00','2024-01-06 14:30:00',30,'Skin rash examination','Completed',130.00,10),
(6,6,6,'2024-01-08 08:00:00','2024-01-08 09:00:00',60,'Appendix consultation','Completed',250.00,11),
(7,7,7,'2024-01-09 10:00:00','2024-01-09 11:00:00',60,'Cancer screening','Completed',300.00,12),
(8,8,8,'2024-01-10 11:00:00','2024-01-10 11:30:00',30,'X-ray review','Completed',100.00,NULL),
(9,9,9,'2024-01-11 15:00:00','2024-01-11 15:50:00',50,'Depression assessment','Completed',200.00,14),
(10,10,10,'2024-01-12 09:00:00','2024-01-12 09:40:00',40,'Diabetes management','Completed',140.00,NULL),
(11,11,11,'2024-01-13 10:30:00','2024-01-13 11:10:00',40,'Stomach pain','Completed',150.00,16),
(12,12,12,'2024-01-14 14:00:00','2024-01-14 14:35:00',35,'Kidney stone follow-up','Completed',170.00,NULL),
(13,13,13,'2024-01-15 09:00:00','2024-01-15 09:45:00',45,'Prenatal checkup','Completed',160.00,18),
(14,14,14,'2024-01-16 11:00:00','2024-01-16 11:40:00',40,'Breathing difficulties','Completed',145.00,NULL),
(15,15,15,'2024-01-17 08:30:00','2024-01-17 09:10:00',40,'Pre-surgery anesthesia review','Completed',220.00,NULL),
(16,16,16,'2024-01-18 10:00:00','2024-01-18 10:35:00',35,'Kidney function test review','Completed',155.00,20),
(17,17,17,'2024-01-19 14:00:00','2024-01-19 14:40:00',40,'Blood disorder consultation','Completed',175.00,21),
(18,18,18,'2024-01-20 09:00:00','2024-01-20 09:30:00',30,'Emergency abdominal pain','Completed',350.00,NULL),
(19,19,19,'2024-01-21 11:00:00','2024-01-21 11:45:00',45,'Joint inflammation review','Completed',160.00,23),
(20,20,20,'2024-01-22 10:00:00','2024-01-22 10:30:00',30,'Eye pressure check','Completed',130.00,24),
(21,21,21,'2024-01-23 14:00:00','2024-01-23 14:30:00',30,'Ear infection treatment','Completed',120.00,25),
(22,1,1,'2024-01-24 09:00:00','2024-01-24 09:50:00',50,'Arrhythmia follow-up','Completed',150.00,NULL),
(23,2,2,'2024-01-25 10:30:00','2024-01-25 11:10:00',40,'Epilepsy management','Completed',180.00,7),
(24,3,3,'2024-01-26 11:00:00','2024-01-26 11:35:00',35,'Vaccination schedule','Completed',90.00,NULL),
(25,4,4,'2024-01-27 09:00:00','2024-01-27 09:50:00',50,'Shoulder injury','Completed',160.00,9),
(26,5,5,'2024-01-28 14:30:00','2024-01-28 15:00:00',30,'Acne treatment plan','Completed',130.00,NULL),
(27,6,6,'2024-01-29 08:00:00','2024-01-29 09:10:00',70,'Hernia operation consult','Completed',250.00,NULL),
(28,7,7,'2024-01-30 10:00:00','2024-01-30 11:00:00',60,'Chemotherapy evaluation','Completed',320.00,12),
(29,8,8,'2024-01-31 11:00:00','2024-01-31 11:30:00',30,'MRI scan review','Completed',110.00,13),
(30,9,9,'2024-02-01 15:00:00','2024-02-01 15:55:00',55,'Anxiety treatment','Completed',200.00,NULL),
(31,10,10,'2024-02-02 09:00:00','2024-02-02 09:45:00',45,'Thyroid check','Completed',140.00,15),
(32,11,11,'2024-02-03 10:30:00','2024-02-03 11:15:00',45,'Colonoscopy follow-up','Completed',150.00,NULL),
(33,12,12,'2024-02-04 14:00:00','2024-02-04 14:40:00',40,'Prostate screening','Completed',170.00,17),
(34,13,13,'2024-02-05 09:00:00','2024-02-05 09:50:00',50,'Postpartum check','Completed',160.00,NULL),
(35,14,14,'2024-02-06 11:00:00','2024-02-06 11:35:00',35,'Asthma management','Completed',145.00,19),
(36,15,15,'2024-02-07 08:30:00','2024-02-07 09:15:00',45,'Anesthesia consultation','Completed',220.00,NULL),
(37,16,16,'2024-02-08 10:00:00','2024-02-08 10:40:00',40,'Dialysis assessment','Completed',155.00,NULL),
(38,17,17,'2024-02-09 14:00:00','2024-02-09 14:45:00',45,'Leukemia follow-up','Completed',175.00,21),
(39,18,18,'2024-02-10 09:00:00','2024-02-10 09:25:00',25,'Trauma evaluation','Completed',350.00,22),
(40,19,19,'2024-02-11 11:00:00','2024-02-11 11:50:00',50,'Lupus management','Completed',160.00,NULL),
-- 1 Scheduled (active)
(41,20,20,'2024-04-01 10:00:00',NULL,NULL,'Cataract pre-op check','Scheduled',130.00,NULL),
-- 1 Cancelled
(42,21,21,'2024-02-13 14:00:00',NULL,NULL,'Sinusitis review','Cancelled',0.00,NULL);
PRINT '[DML] 42 appointments inserted.';

-- ── bills (42 rows) ───────────────────────────────────────────
INSERT INTO bills (AppointmentID, Amount, Method, BillDate, Status) VALUES
(1,135.00,'Card','2024-01-02 10:00:00','Paid'),
(2,180.00,'Insurance','2024-01-03 11:00:00','Paid'),
(3,96.00,'Cash','2024-01-04 12:00:00','Paid'),
(4,160.00,'Card','2024-01-05 10:30:00','Paid'),
(5,123.50,'Insurance','2024-01-06 15:00:00','Paid'),
(6,175.00,'Card','2024-01-08 10:00:00','Paid'),
(7,225.00,'Insurance','2024-01-09 12:00:00','Paid'),
(8,100.00,'Cash','2024-01-10 12:00:00','Paid'),
(9,170.00,'Insurance','2024-01-11 16:30:00','Paid'),
(10,140.00,'Card','2024-01-12 10:00:00','Paid'),
(11,127.50,'Cash','2024-01-13 12:00:00','Paid'),
(12,170.00,'Card','2024-01-14 15:00:00','Paid'),
(13,128.00,'Insurance','2024-01-15 10:00:00','Paid'),
(14,145.00,'Card','2024-01-16 12:00:00','Paid'),
(15,220.00,'Insurance','2024-01-17 10:00:00','Paid'),
(16,147.25,'Cash','2024-01-18 11:00:00','Paid'),
(17,148.75,'Card','2024-01-19 15:00:00','Paid'),
(18,350.00,'Insurance','2024-01-20 10:00:00','Paid'),
(19,128.00,'Card','2024-01-21 12:00:00','Paid'),
(20,117.00,'Cash','2024-01-22 11:00:00','Paid'),
(21,114.00,'Insurance','2024-01-23 15:00:00','Paid'),
(22,150.00,'Card','2024-01-24 10:30:00','Paid'),
(23,153.00,'Insurance','2024-01-25 12:00:00','Paid'),
(24,90.00,'Cash','2024-01-26 12:00:00','Paid'),
(25,144.00,'Card','2024-01-27 10:00:00','Paid'),
(26,130.00,'Insurance','2024-01-28 15:30:00','Paid'),
(27,250.00,'Card','2024-01-29 10:00:00','Paid'),
(28,240.00,'Insurance','2024-01-30 12:00:00','Paid'),
(29,110.00,'Cash','2024-01-31 12:00:00','Paid'),
(30,200.00,'Card','2024-02-01 16:30:00','Paid'),
(31,140.00,'Insurance','2024-02-02 10:00:00','Paid'),
(32,150.00,'Card','2024-02-03 12:00:00','Paid'),
(33,144.50,'Cash','2024-02-04 15:00:00','Paid'),
(34,160.00,'Insurance','2024-02-05 10:30:00','Paid'),
(35,130.50,'Card','2024-02-06 12:00:00','Paid'),
(36,220.00,'Insurance','2024-02-07 10:00:00','Paid'),
(37,155.00,'Card','2024-02-08 11:00:00','Paid'),
(38,148.75,'Cash','2024-02-09 15:00:00','Paid'),
(39,350.00,'Insurance','2024-02-10 10:00:00','Paid'),
(40,160.00,'Card','2024-02-11 12:00:00','Paid'),
-- 1 Pending (for scheduled appointment — not yet billed)
(41,130.00,'Card','2024-04-01 10:30:00','Pending'),
-- 1 Failed (for cancelled)
(42,0.00,'Cash','2024-02-13 15:00:00','Failed');
PRINT '[DML] 42 bills inserted.';

-- ── ratings (40 rows — completed appointments only) ───────────
INSERT INTO ratings (AppointmentID, DoctorRating, PatientRating, Comment) VALUES
(1,5,4,'Excellent cardiologist, very thorough.'),
(2,5,5,'Dr. Lee explained everything clearly.'),
(3,4,5,'Great with kids, very patient.'),
(4,5,4,'Resolved my knee issue quickly.'),
(5,4,NULL,'Good dermatologist, minimal wait.'),
(6,5,5,'Surgery consult was very professional.'),
(7,5,5,'Dr. White is incredibly knowledgeable.'),
(8,4,4,'Efficient radiology review.'),
(9,5,4,'Felt very supported during the session.'),
(10,4,5,'Helped manage my diabetes better.'),
(11,4,NULL,'Good gastro consult overall.'),
(12,5,4,'Kidney issue well explained.'),
(13,5,5,'Amazing prenatal care experience.'),
(14,4,4,'Breathing advice was very helpful.'),
(15,5,5,'Very calm and reassuring.'),
(16,4,NULL,'Thorough kidney assessment.'),
(17,5,4,'Blood disorder explained very well.'),
(18,5,5,'Fast and professional emergency care.'),
(19,4,4,'Good rheumatology consultation.'),
(20,4,5,'Eye check was quick and painless.'),
(21,4,NULL,'ENT doctor was very thorough.'),
(22,5,4,'Second cardio visit, still excellent.'),
(23,4,4,'Epilepsy management improved.'),
(24,5,5,'Kids love Dr. Chen.'),
(25,5,4,'Shoulder pain resolved.'),
(26,4,NULL,'Happy with skin treatment plan.'),
(27,5,5,'Very confident about the surgery.'),
(28,5,5,'Dr. White is outstanding for oncology.'),
(29,3,4,'MRI review was slightly rushed.'),
(30,5,5,'Anxiety greatly reduced after session.'),
(31,4,4,'Thyroid management on track.'),
(32,4,NULL,'Colonoscopy follow-up very clear.'),
(33,5,5,'Prostate screening done professionally.'),
(34,5,5,'Postpartum care was excellent.'),
(35,4,4,'Asthma under control now.'),
(36,5,5,'Pre-surgery anesthesia consult was perfect.'),
(37,4,4,'Dialysis plan well structured.'),
(38,5,5,'Leukemia treatment going well.'),
(39,5,5,'Trauma handled very efficiently.'),
(40,4,4,'Lupus management improved.');
PRINT '[DML] 40 ratings inserted.';

PRINT '========================================';
PRINT ' SECTION 3 — INDEXES: 15 PERFORMANCE OPTIMIZATIONS';
PRINT '========================================';

CREATE INDEX idx_appt_patient     ON appointments(PatientID);
CREATE INDEX idx_appt_doctor      ON appointments(DoctorID);
CREATE INDEX idx_appt_status      ON appointments(Status);
CREATE INDEX idx_appt_time        ON appointments(ScheduledTime);
CREATE INDEX idx_appt_doc_status  ON appointments(DoctorID, Status);  -- composite
CREATE INDEX idx_appt_fee         ON appointments(ConsultationFee);
CREATE INDEX idx_appt_dept        ON appointments(DepartmentID);
CREATE INDEX idx_appt_promo       ON appointments(PromoID);
CREATE INDEX idx_bills_status     ON bills(Status);
CREATE INDEX idx_bills_appt       ON bills(AppointmentID);
CREATE INDEX idx_ratings_appt     ON ratings(AppointmentID);
CREATE INDEX idx_rooms_dept       ON rooms(DepartmentID);
CREATE INDEX idx_doctors_status   ON doctors(Status);
CREATE INDEX idx_promo_expiry     ON promotions(ExpiryDate);
CREATE INDEX idx_patients_regdate ON patients(RegistrationDate);
PRINT '[INDEX] 15 indexes created.';

PRINT '========================================';
PRINT ' SECTION 4 — VIEWS: 8 REUSABLE QUERY OBJECTS';
PRINT '========================================';

GO
CREATE VIEW vw_appointment_details AS
SELECT
    a.AppointmentID,
    p.FirstName + ' ' + p.LastName          AS PatientName,
    d.FirstName + ' ' + d.LastName          AS DoctorName,
    d.Specialization,
    dep.Name                                AS Department,
    a.ScheduledTime,
    a.EndTime,
    a.Duration                              AS DurationMinutes,
    a.ReasonForVisit,
    a.Status,
    a.ConsultationFee,
    pr.Code                                 AS PromoCode
FROM appointments a
JOIN patients    p   ON a.PatientID    = p.PatientID
JOIN doctors     d   ON a.DoctorID     = d.DoctorID
JOIN departments dep ON a.DepartmentID = dep.DepartmentID
LEFT JOIN promotions pr ON a.PromoID  = pr.PromoID;
GO
PRINT '[VIEW] vw_appointment_details created.';

GO
CREATE VIEW vw_doctor_summary AS
SELECT
    d.DoctorID,
    d.FirstName + ' ' + d.LastName          AS DoctorName,
    d.Specialization,
    d.Status,
    COUNT(a.AppointmentID)                  AS TotalAppointments,
    ROUND(SUM(a.ConsultationFee), 2)        AS TotalEarnings,
    ROUND(AVG(CAST(a.Duration AS FLOAT)),1) AS AvgDurationMin,
    d.Rating                                AS AvgDoctorRating
FROM doctors d
LEFT JOIN appointments a ON d.DoctorID = a.DoctorID AND a.Status = 'Completed'
GROUP BY d.DoctorID, d.FirstName, d.LastName, d.Specialization, d.Status, d.Rating;
GO
PRINT '[VIEW] vw_doctor_summary created.';

GO
CREATE VIEW vw_patient_activity AS
SELECT
    p.PatientID,
    p.FirstName + ' ' + p.LastName          AS PatientName,
    p.Email,
    COUNT(a.AppointmentID)                  AS TotalAppointments,
    ROUND(SUM(a.ConsultationFee), 2)        AS TotalSpent,
    ROUND(AVG(CAST(r.PatientRating AS FLOAT)),1) AS AvgPatientRating
FROM patients p
LEFT JOIN appointments a ON p.PatientID = a.PatientID AND a.Status = 'Completed'
LEFT JOIN ratings      r ON a.AppointmentID = r.AppointmentID
GROUP BY p.PatientID, p.FirstName, p.LastName, p.Email;
GO
PRINT '[VIEW] vw_patient_activity created.';

GO
CREATE VIEW vw_revenue_by_department AS
SELECT
    dep.Name                                AS Department,
    dep.Location,
    COUNT(a.AppointmentID)                  AS TotalAppointments,
    ROUND(SUM(a.ConsultationFee), 2)        AS TotalRevenue,
    ROUND(AVG(a.ConsultationFee), 2)        AS AvgFee
FROM departments dep
JOIN appointments a ON dep.DepartmentID = a.DepartmentID AND a.Status = 'Completed'
GROUP BY dep.DepartmentID, dep.Name, dep.Location;
GO
PRINT '[VIEW] vw_revenue_by_department created.';

GO
CREATE VIEW vw_bill_overview AS
SELECT
    b.BillID,
    p.FirstName + ' ' + p.LastName          AS PatientName,
    b.Amount,
    b.Method,
    b.BillDate,
    b.Status
FROM bills b
JOIN appointments a ON b.AppointmentID = a.AppointmentID
JOIN patients     p ON a.PatientID     = p.PatientID;
GO
PRINT '[VIEW] vw_bill_overview created.';

GO
CREATE VIEW vw_active_promotions AS
SELECT PromoID, Code, Discount, ExpiryDate
FROM promotions
WHERE ExpiryDate > GETDATE();
GO
PRINT '[VIEW] vw_active_promotions created.';

GO
CREATE VIEW vw_top_doctors AS
SELECT
    d.DoctorID,
    d.FirstName + ' ' + d.LastName AS DoctorName,
    d.Specialization,
    d.Rating,
    d.Status
FROM doctors d
WHERE d.Rating >= 4.7;
GO
PRINT '[VIEW] vw_top_doctors created.';

GO
CREATE VIEW vw_scheduled_appointments AS
SELECT
    a.AppointmentID,
    p.FirstName + ' ' + p.LastName  AS PatientName,
    d.FirstName + ' ' + d.LastName  AS DoctorName,
    d.Specialization,
    a.ScheduledTime,
    a.ReasonForVisit,
    a.ConsultationFee
FROM appointments a
JOIN patients p ON a.PatientID = p.PatientID
JOIN doctors  d ON a.DoctorID  = d.DoctorID
WHERE a.Status = 'Scheduled';
GO
PRINT '[VIEW] vw_scheduled_appointments created.';

PRINT '========================================';
PRINT ' SECTION 5 — TRIGGERS: 7 BUSINESS RULE AUTOMATIONS';
PRINT '========================================';

-- BR-5: Auto-calculate Duration when EndTime is set
GO
CREATE TRIGGER trg_calc_duration
ON appointments AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE appointments
    SET Duration = DATEDIFF(MINUTE, i.ScheduledTime, i.EndTime)
    FROM appointments a
    JOIN inserted i ON a.AppointmentID = i.AppointmentID
    WHERE i.EndTime IS NOT NULL;
END;
GO
PRINT '[TRIGGER] trg_calc_duration created.';

-- BR-4: Auto-recalculate doctor rating after new rating inserted
GO
CREATE TRIGGER trg_update_doctor_rating
ON ratings AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE doctors
    SET Rating = ROUND((
        SELECT AVG(CAST(r.DoctorRating AS FLOAT))
        FROM ratings r
        JOIN appointments a ON r.AppointmentID = a.AppointmentID
        WHERE a.DoctorID = d.DoctorID
    ), 2)
    FROM doctors d
    WHERE d.DoctorID IN (
        SELECT a.DoctorID
        FROM inserted i
        JOIN appointments a ON i.AppointmentID = a.AppointmentID
    );
END;
GO
PRINT '[TRIGGER] trg_update_doctor_rating created.';

-- BR-6: Doctor becomes Busy when a new Scheduled appointment is inserted
GO
CREATE TRIGGER trg_doctor_busy_on_appointment
ON appointments AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE doctors
    SET Status = 'Busy'
    FROM doctors d
    JOIN inserted i ON d.DoctorID = i.DoctorID
    WHERE i.Status = 'Scheduled';
END;
GO
PRINT '[TRIGGER] trg_doctor_busy_on_appointment created.';

-- BR-7: Doctor becomes Available when appointment is Completed or Cancelled
GO
CREATE TRIGGER trg_doctor_available_on_complete
ON appointments AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE doctors
    SET Status = 'Available'
    FROM doctors d
    JOIN inserted i ON d.DoctorID = i.DoctorID
    WHERE i.Status IN ('Completed','Cancelled');
END;
GO
PRINT '[TRIGGER] trg_doctor_available_on_complete created.';

-- BR-1: Patient cannot have more than one active Scheduled appointment at a time
GO
CREATE TRIGGER trg_no_concurrent_appointments
ON appointments INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM appointments a
        JOIN inserted i ON a.PatientID = i.PatientID
        WHERE a.Status = 'Scheduled'
    )
    BEGIN
        RAISERROR('Patient already has an active scheduled appointment.', 16, 1);
        RETURN;
    END;
    INSERT INTO appointments
        (PatientID, DoctorID, DepartmentID, ScheduledTime, EndTime, Duration,
         ReasonForVisit, Status, ConsultationFee, PromoID)
    SELECT
        PatientID, DoctorID, DepartmentID, ScheduledTime, EndTime, Duration,
        ReasonForVisit, Status, ConsultationFee, PromoID
    FROM inserted;
END;
GO
PRINT '[TRIGGER] trg_no_concurrent_appointments created.';

-- BR-3: Bill cannot be created for a Cancelled appointment
GO
CREATE TRIGGER trg_validate_bill_appointment
ON bills INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM appointments a
        JOIN inserted i ON a.AppointmentID = i.AppointmentID
        WHERE a.Status = 'Cancelled'
    )
    BEGIN
        RAISERROR('Cannot create a bill for a cancelled appointment.', 16, 1);
        RETURN;
    END;
    INSERT INTO bills (AppointmentID, Amount, Method, BillDate, Status)
    SELECT AppointmentID, Amount, Method, BillDate, Status
    FROM inserted;
END;
GO
PRINT '[TRIGGER] trg_validate_bill_appointment created.';

-- BR-2: Completed appointments cannot be deleted
GO
CREATE TRIGGER trg_prevent_delete_completed
ON appointments AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted WHERE Status = 'Completed')
    BEGIN
        RAISERROR('Completed appointments cannot be deleted.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO
PRINT '[TRIGGER] trg_prevent_delete_completed created.';

PRINT '========================================';
PRINT ' SECTION 6 — STORED PROCEDURES: 8 OPERATIONS';
PRINT '========================================';

GO
CREATE PROCEDURE sp_get_patient_appointments
    @PatientID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM vw_appointment_details
    WHERE PatientName IN (
        SELECT FirstName + ' ' + LastName FROM patients WHERE PatientID = @PatientID
    )
    ORDER BY ScheduledTime DESC;
END;
GO
PRINT '[PROC] sp_get_patient_appointments created.';

GO
CREATE PROCEDURE sp_available_doctors
    @Specialization VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.DoctorID,
           d.FirstName + ' ' + d.LastName AS DoctorName,
           d.Specialization,
           d.Rating,
           d.Status
    FROM doctors d
    WHERE d.Status = 'Available'
      AND (@Specialization IS NULL OR d.Specialization = @Specialization)
    ORDER BY d.Rating DESC;
END;
GO
PRINT '[PROC] sp_available_doctors created.';

GO
CREATE PROCEDURE sp_complete_appointment
    @AppointmentID INT,
    @EndTime       DATETIME,
    @Fee           FLOAT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE appointments
    SET Status         = 'Completed',
        EndTime        = @EndTime,
        ConsultationFee= @Fee
    WHERE AppointmentID = @AppointmentID;
    PRINT 'Appointment ' + CAST(@AppointmentID AS VARCHAR) + ' marked Completed.';
END;
GO
PRINT '[PROC] sp_complete_appointment created.';

GO
CREATE PROCEDURE sp_apply_promo
    @AppointmentID INT,
    @PromoID       INT,
    @NewFee        FLOAT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Discount FLOAT, @OldFee FLOAT;
    SELECT @Discount = Discount
    FROM promotions
    WHERE PromoID = @PromoID AND ExpiryDate > GETDATE();

    IF @Discount IS NULL
    BEGIN
        RAISERROR('Invalid or expired promo code.', 16, 1);
        RETURN;
    END;

    SELECT @OldFee = ConsultationFee FROM appointments WHERE AppointmentID = @AppointmentID;
    SET @NewFee = ROUND(@OldFee * (1.0 - @Discount / 100.0), 2);

    UPDATE appointments
    SET ConsultationFee = @NewFee,
        PromoID         = @PromoID
    WHERE AppointmentID = @AppointmentID;
END;
GO
PRINT '[PROC] sp_apply_promo created.';

GO
CREATE PROCEDURE sp_monthly_revenue
    @Year  INT,
    @Month INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(*)                              AS TotalAppointments,
        ROUND(SUM(ConsultationFee), 2)        AS TotalRevenue,
        ROUND(AVG(ConsultationFee), 2)        AS AvgFee,
        ROUND(MIN(ConsultationFee), 2)        AS MinFee,
        ROUND(MAX(ConsultationFee), 2)        AS MaxFee
    FROM appointments
    WHERE Status = 'Completed'
      AND YEAR(ScheduledTime)  = @Year
      AND MONTH(ScheduledTime) = @Month;
END;
GO
PRINT '[PROC] sp_monthly_revenue created.';

GO
CREATE PROCEDURE sp_doctor_earnings
    @DoctorID  INT,
    @StartDate DATE,
    @EndDate   DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(*)                       AS TotalCompleted,
        ROUND(SUM(ConsultationFee),2)  AS TotalEarnings
    FROM appointments
    WHERE DoctorID  = @DoctorID
      AND Status    = 'Completed'
      AND CAST(ScheduledTime AS DATE) BETWEEN @StartDate AND @EndDate;
END;
GO
PRINT '[PROC] sp_doctor_earnings created.';

GO
CREATE PROCEDURE sp_register_patient
    @FirstName VARCHAR(50),
    @LastName  VARCHAR(50),
    @Email     VARCHAR(100),
    @Phone     VARCHAR(20),
    @DOB       DATE,
    @Gender    VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO patients (FirstName, LastName, Email, Phone, DateOfBirth, Gender)
    VALUES (@FirstName, @LastName, @Email, @Phone, @DOB, @Gender);
    SELECT SCOPE_IDENTITY() AS NewPatientID;
END;
GO
PRINT '[PROC] sp_register_patient created.';

GO
CREATE PROCEDURE sp_cancel_appointment
    @AppointmentID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Affected INT;
    UPDATE appointments
    SET Status = 'Cancelled'
    WHERE AppointmentID = @AppointmentID AND Status = 'Scheduled';
    SET @Affected = @@ROWCOUNT;
    SELECT @Affected AS RowsUpdated;
END;
GO
PRINT '[PROC] sp_cancel_appointment created.';

PRINT '========================================';
PRINT ' SECTION 7 — DQL: 30 SELECT QUERIES';
PRINT '========================================';

-- ── SELECTION σ (Q1–Q7) ──────────────────────────────────────
PRINT '-- Q1 | σ: Completed appointments';
SELECT * FROM appointments WHERE Status = 'Completed';

PRINT '-- Q2 | σ: Available doctors';
SELECT * FROM doctors WHERE Status = 'Available';

PRINT '-- Q3 | σ: Appointments with fee > $150';
SELECT * FROM appointments WHERE ConsultationFee > 150 AND Status = 'Completed';

PRINT '-- Q4 | σ: Patients registered after June 2023';
SELECT * FROM patients WHERE RegistrationDate > '2023-06-01';

PRINT '-- Q5 | σ: Active promos with > 15% discount';
SELECT * FROM promotions WHERE Discount > 15 AND ExpiryDate > GETDATE();

PRINT '-- Q6 | σ: Long appointments (Duration > 45 mins)';
SELECT * FROM appointments WHERE Duration > 45 AND Status = 'Completed';

PRINT '-- Q7 | σ: Insurance-paid bills with Paid status';
SELECT * FROM bills WHERE Method = 'Insurance' AND Status = 'Paid';

-- ── PROJECTION π (Q8–Q10) ─────────────────────────────────────
PRINT '-- Q8 | π: Patient contact details';
SELECT FirstName, LastName, Email, Phone FROM patients;

PRINT '-- Q9 | π: Doctors ranked by rating';
SELECT FirstName, LastName, Specialization, Rating FROM doctors ORDER BY Rating DESC;

PRINT '-- Q10 | π: Room registry summary';
SELECT RoomNumber, RoomType, Capacity, Status FROM rooms;

-- ── NATURAL JOIN ⋈ (Q11–Q15) ─────────────────────────────────
PRINT '-- Q11 | ⋈: Appointments with patient and doctor names';
SELECT
    a.AppointmentID,
    p.FirstName + ' ' + p.LastName  AS PatientName,
    d.FirstName + ' ' + d.LastName  AS DoctorName,
    d.Specialization,
    a.ScheduledTime,
    a.Status,
    a.ConsultationFee
FROM appointments a
JOIN patients p ON a.PatientID = p.PatientID
JOIN doctors  d ON a.DoctorID  = d.DoctorID;

PRINT '-- Q12 | ⋈: Appointments with department and room info';
SELECT
    a.AppointmentID,
    p.FirstName + ' ' + p.LastName AS PatientName,
    dep.Name                       AS Department,
    dep.Location,
    a.ScheduledTime,
    a.ConsultationFee
FROM appointments a
JOIN patients    p   ON a.PatientID    = p.PatientID
JOIN departments dep ON a.DepartmentID = dep.DepartmentID;

PRINT '-- Q13 | ⋈: Doctors with their department';
SELECT
    d.FirstName + ' ' + d.LastName AS DoctorName,
    d.Specialization,
    d.Rating,
    d.Status
FROM doctors d;

PRINT '-- Q14 | ⋈: Appointments that used a promo code';
SELECT
    a.AppointmentID,
    p.FirstName + ' ' + p.LastName AS PatientName,
    pr.Code                        AS PromoCode,
    pr.Discount,
    a.ConsultationFee
FROM appointments a
JOIN patients   p  ON a.PatientID = p.PatientID
JOIN promotions pr ON a.PromoID   = pr.PromoID;

PRINT '-- Q15 | ⋈: Bills with patient names';
SELECT
    b.BillID,
    p.FirstName + ' ' + p.LastName AS PatientName,
    b.Amount,
    b.Method,
    b.BillDate,
    b.Status
FROM bills b
JOIN appointments a ON b.AppointmentID = a.AppointmentID
JOIN patients     p ON a.PatientID     = p.PatientID;

-- ── AGGREGATION γ (Q16–Q20) ───────────────────────────────────
PRINT '-- Q16 | γ: Total earnings and appointment count per doctor';
SELECT
    d.FirstName + ' ' + d.LastName AS DoctorName,
    d.Specialization,
    COUNT(a.AppointmentID)           AS TotalAppointments,
    ROUND(SUM(a.ConsultationFee),2)  AS TotalEarnings
FROM doctors d
JOIN appointments a ON d.DoctorID = a.DoctorID AND a.Status = 'Completed'
GROUP BY d.DoctorID, d.FirstName, d.LastName, d.Specialization
ORDER BY TotalEarnings DESC;

PRINT '-- Q17 | γ: Average fee and total revenue per department';
SELECT
    dep.Name                        AS Department,
    COUNT(a.AppointmentID)          AS TotalAppointments,
    ROUND(AVG(a.ConsultationFee),2) AS AvgFee,
    ROUND(SUM(a.ConsultationFee),2) AS TotalRevenue
FROM departments dep
JOIN appointments a ON dep.DepartmentID = a.DepartmentID AND a.Status = 'Completed'
GROUP BY dep.DepartmentID, dep.Name
ORDER BY TotalRevenue DESC;

PRINT '-- Q18 | γ: Count of appointments per status';
SELECT Status, COUNT(*) AS Total FROM appointments GROUP BY Status;

PRINT '-- Q19 | γ: Average doctor rating per specialization';
SELECT Specialization, ROUND(AVG(Rating),2) AS AvgRating
FROM doctors
GROUP BY Specialization
ORDER BY AvgRating DESC;

PRINT '-- Q20 | γ: Top 5 highest-earning doctors';
SELECT TOP 5
    d.FirstName + ' ' + d.LastName AS DoctorName,
    ROUND(SUM(a.ConsultationFee),2) AS TotalEarnings
FROM doctors d
JOIN appointments a ON d.DoctorID = a.DoctorID AND a.Status = 'Completed'
GROUP BY d.DoctorID, d.FirstName, d.LastName
ORDER BY TotalEarnings DESC;

-- ── SET OPERATIONS ∪ ∩ − (Q21–Q24) ──────────────────────────
PRINT '-- Q21 | ∪: All people in system (patients + doctors)';
SELECT FirstName, LastName, ''Specialization'' = NULL, ''Role'' = ''Patient'' FROM patients
UNION
SELECT FirstName, LastName, Specialization, ''Doctor'' FROM doctors;

PRINT '-- Q22 | ∩: First names shared by patients and doctors';
SELECT FirstName FROM patients
INTERSECT
SELECT FirstName FROM doctors;

PRINT '-- Q23 | −: Patients with no appointments';
SELECT PatientID, FirstName, LastName FROM patients
WHERE PatientID NOT IN (SELECT PatientID FROM appointments);

PRINT '-- Q24 | −: Doctors who never completed an appointment';
SELECT DoctorID, FirstName, LastName FROM doctors
WHERE DoctorID NOT IN (
    SELECT DoctorID FROM appointments WHERE Status = ''Completed''
);

-- ── SUBQUERIES (Q25–Q30) ──────────────────────────────────────
PRINT '-- Q25 | σ + subquery: Appointments above average fee';
SELECT AppointmentID, PatientID, DoctorID, ConsultationFee
FROM appointments
WHERE Status = 'Completed'
  AND ConsultationFee > (SELECT AVG(ConsultationFee) FROM appointments WHERE Status = 'Completed');

PRINT '-- Q26 | σ + subquery: Doctor(s) with highest rating';
SELECT FirstName, LastName, Specialization, Rating
FROM doctors
WHERE Rating = (SELECT MAX(Rating) FROM doctors);

PRINT '-- Q27 | ⋈ + γ + subquery: Patients who spent above average total';
SELECT
    p.PatientID,
    p.FirstName + ' ' + p.LastName AS PatientName,
    ROUND(SUM(a.ConsultationFee),2) AS TotalSpent
FROM patients p
JOIN appointments a ON p.PatientID = a.PatientID AND a.Status = 'Completed'
GROUP BY p.PatientID, p.FirstName, p.LastName
HAVING SUM(a.ConsultationFee) > (
    SELECT AVG(total)
    FROM (
        SELECT SUM(ConsultationFee) AS total
        FROM appointments WHERE Status = 'Completed'
        GROUP BY PatientID
    ) sub
);

PRINT '-- Q28 | ⋈ + subquery: Most expensive completed appointment';
SELECT TOP 1
    a.AppointmentID,
    p.FirstName + ' ' + p.LastName AS PatientName,
    d.FirstName + ' ' + d.LastName AS DoctorName,
    a.ConsultationFee,
    a.ScheduledTime
FROM appointments a
JOIN patients p ON a.PatientID = p.PatientID
JOIN doctors  d ON a.DoctorID  = d.DoctorID
WHERE a.Status = 'Completed'
ORDER BY a.ConsultationFee DESC;

PRINT '-- Q29 | ⋈ + γ + HAVING: Promo codes used more than once';
SELECT
    pr.Code,
    pr.Discount,
    COUNT(a.AppointmentID) AS TimesUsed
FROM promotions pr
JOIN appointments a ON pr.PromoID = a.PromoID
GROUP BY pr.PromoID, pr.Code, pr.Discount
HAVING COUNT(a.AppointmentID) > 1;

PRINT '-- Q30 | σ + IN: Appointments with both a Paid bill and a rating';
SELECT a.AppointmentID, a.PatientID, a.DoctorID, a.Status
FROM appointments a
WHERE a.AppointmentID IN (SELECT AppointmentID FROM bills   WHERE Status = 'Paid')
  AND a.AppointmentID IN (SELECT AppointmentID FROM ratings);

PRINT '========================================';
PRINT ' SECTION 8 — DCL: ROLE-BASED ACCESS CONTROL';
PRINT '========================================';

-- Application user: read/write, no DELETE
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'hosp_app')
    CREATE LOGIN hosp_app WITH PASSWORD = 'App@Secure123!';
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'hosp_app')
    CREATE USER hosp_app FOR LOGIN hosp_app;
GRANT SELECT, INSERT, UPDATE ON SCHEMA::dbo TO hosp_app;
DENY  DELETE                  ON SCHEMA::dbo TO hosp_app;

-- Report user: SELECT only
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'hosp_report')
    CREATE LOGIN hosp_report WITH PASSWORD = 'Report@Secure123!';
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'hosp_report')
    CREATE USER hosp_report FOR LOGIN hosp_report;
GRANT SELECT ON SCHEMA::dbo TO hosp_report;

-- DBA: full owner
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'hosp_dba')
    CREATE LOGIN hosp_dba WITH PASSWORD = 'DBA@Secure123!';
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'hosp_dba')
    CREATE USER hosp_dba FOR LOGIN hosp_dba;
ALTER ROLE db_owner ADD MEMBER hosp_dba;
PRINT '[DCL] 3 user roles created.';

PRINT '========================================';
PRINT ' FINAL INVENTORY';
PRINT '========================================';
SELECT 'patients'     AS TableName, COUNT(*) AS Rows FROM patients     UNION ALL
SELECT 'doctors',                   COUNT(*)          FROM doctors      UNION ALL
SELECT 'departments',               COUNT(*)          FROM departments  UNION ALL
SELECT 'rooms',                     COUNT(*)          FROM rooms        UNION ALL
SELECT 'appointments',              COUNT(*)          FROM appointments UNION ALL
SELECT 'bills',                     COUNT(*)          FROM bills        UNION ALL
SELECT 'ratings',                   COUNT(*)          FROM ratings      UNION ALL
SELECT 'promotions',                COUNT(*)          FROM promotions;

SELECT 'Views'             AS ObjectType, COUNT(*) AS Total FROM sys.views            WHERE is_ms_shipped = 0 UNION ALL
SELECT 'Triggers',                        COUNT(*)          FROM sys.triggers         WHERE is_ms_shipped = 0 UNION ALL
SELECT 'StoredProcedures',                COUNT(*)          FROM sys.procedures       WHERE is_ms_shipped = 0 UNION ALL
SELECT 'Indexes (non-PK)',                COUNT(*)          FROM sys.indexes          WHERE is_primary_key = 0 AND object_id IN (SELECT object_id FROM sys.tables);

PRINT '[DONE] HospitalDB deployed successfully — zero errors.';
