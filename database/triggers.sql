USE MedicalClinic;
GO

CREATE OR ALTER TRIGGER TR_Appointment_DoctorSchedule 
ON dbo.Appointment 
AFTER INSERT, UPDATE 
AS 
BEGIN 
SET NOCOUNT ON;
    
    IF NOT(UPDATE(Date_Time) OR UPDATE(DoctorID) OR UPDATE(OfficeID) OR UPDATE(AppointStatus)) RETURN;

IF EXISTS(
    SELECT 1
    FROM inserted AS i
    WHERE i.AppointStatus <> 'Cancelled'
        AND NOT EXISTS (
            SELECT 1
            FROM DoctorSchedule as ds
            WHERE ds.DoctorID  = i.DoctorID
            AND ds.OfficeID = i.OfficeID
            AND ds.DayOfWeek = CHOOSE(DATEDIFF(DAY, '19000101', i.Date_Time) % 7 + 1,
                                                'Mon','Tue','Wed','Thu','Fri','Sat','Sun')
        )
)

BEGIN
    ROLLBACK TRANSACTION;
        THROW 50001, 'The Doctor is not scheduled at this office that day', 1;
    END;

    IF EXISTS(
        SELECT 1
        FROM inserted AS i 
        JOIN Office AS o ON o.OfficeID=i.OfficeID
        WHERE i.AppointStatus <> 'Cancelled'
        AND (CAST(i.Date_Time AS TIME) < o.OpeningTime 
        OR CAST(i.Date_Time AS TIME) >= o.ClosingTime)

    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50002, 'The Office is not open at that time', 1;
        END;
    END;
    GO

CREATE OR ALTER TRIGGER TR_PaymentDetail_Overpayment
ON dbo.PaymentDetail
AFTER INSERT, UPDATE
AS BEGIN
SET NOCOUNT ON;

    IF NOT(UPDATE(AmountApplied) OR UPDATE(PaymentID)) RETURN;

IF EXISTS(
    SELECT 1
    FROM Appointment AS a
    JOIN Payment AS p ON p.AppointmentID = a.AppointmentID 
    JOIN PaymentDetail AS pd ON pd.PaymentID = p.PaymentID
    WHERE a.AppointmentID IN(
                            SELECT p2.AppointmentID
                            FROM inserted AS i
                            JOIN Payment AS p2 ON p2.PaymentID = i.PaymentID
                            )
    AND p.PayStatus <> 'Refunded'
    GROUP BY a.AppointmentID, a.TotalCost
    HAVING SUM(pd.AmountApplied) > a.TotalCost
)

BEGIN 
    ROLLBACK TRANSACTION;
    THROW 50008, 'This payment would exceed the total cost of the appointment', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER TR_Payment_Overpayment
ON dbo.Payment
AFTER INSERT, UPDATE
AS BEGIN
SET NOCOUNT ON;
    IF NOT(UPDATE(PayStatus) OR UPDATE(AppointmentID)) RETURN;

IF EXISTS(
    SELECT 1
    FROM inserted AS i
    JOIN Appointment AS a on a.AppointmentID = i.AppointmentID
    WHERE a.AppointStatus = 'Cancelled' AND i.PayStatus <> 'Refunded'

)

BEGIN 
    ROLLBACK TRANSACTION;
    THROW 50007, 'This payment cannot be done since the appointment is cancelled', 1;
    END;
    
    IF EXISTS(
    SELECT 1
    FROM Appointment AS a
    JOIN Payment AS p ON p.AppointmentID = a.AppointmentID 
    JOIN PaymentDetail AS pd ON pd.PaymentID = p.PaymentID
    WHERE a.AppointmentID IN(
                            SELECT i.AppointmentID
                            FROM inserted AS i
                            )
    AND p.PayStatus <> 'Refunded'
    GROUP BY a.AppointmentID, a.TotalCost
    HAVING SUM(pd.AmountApplied) > a.TotalCost
)
BEGIN 
    ROLLBACK TRANSACTION;
    THROW 50008, 'This payment would exceed the total cost of the appointment', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER TR_Appointment_StatusTransition
ON dbo.Appointment
AFTER UPDATE
AS BEGIN
SET NOCOUNT ON;

    IF NOT(UPDATE(AppointStatus)) RETURN;

IF EXISTS(
    SELECT 1
    FROM deleted AS d
    JOIN inserted AS i ON i.AppointmentID = d.AppointmentID
    WHERE d.AppointStatus IN('Cancelled', 'Completed')
    AND i.AppointStatus <> d.AppointStatus
)
BEGIN 
    ROLLBACK TRANSACTION;
    THROW 50005, 'A completed or cancelled appointment cannot change status.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER TR_Referral_IssuedByPrimary
ON dbo.Referral
AFTER INSERT, UPDATE
AS BEGIN
SET NOCOUNT ON;
    IF NOT(UPDATE(PatientID) OR UPDATE(PrimaryID)) RETURN;
IF EXISTS(
    SELECT 1
    FROM inserted AS i
    WHERE NOT EXISTS(
                SELECT 1
                FROM PatientDoctor AS pd
                WHERE pd.PatientID = i.PatientID
                AND pd.DoctorID = i.PrimaryID
                AND pd.RolePlayed = 'Primary'
              )
)
BEGIN 
    ROLLBACK TRANSACTION;
    THROW 50004, 'Only the patient''s primary doctor can issue a referral.', 1;
    END;
END;
GO