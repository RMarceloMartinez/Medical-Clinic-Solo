USE MedicalClinic;
GO

PRINT '=== Trigger 1: TR_Appointment_DoctorSchedule ===';

-- Test 1: ALLOWED - Ramirez at office 1 on Monday 10:00 (he works Mondays there)
BEGIN TRY
    INSERT INTO Appointment (OfficeID, DoctorID, PatientID, ReferralID, Date_Time,
                             AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES (1000000, 1000000, 1000006, NULL, '2026-10-19 10:00',
            'Scheduled', 150.00, 'Phone', NULL, NULL);
    PRINT 'OK   Test 1: valid appointment was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 1: valid appointment was rejected: ' + ERROR_MESSAGE();
END CATCH;

-- Test 2: REJECTED (50001) - Ramirez at office 1 on Tuesday (not scheduled)
BEGIN TRY
    INSERT INTO Appointment (OfficeID, DoctorID, PatientID, ReferralID, Date_Time,
                             AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES (1000000, 1000000, 1000006, NULL, '2026-10-20 10:00',
            'Scheduled', 150.00, 'Phone', NULL, NULL);
    PRINT 'FAIL Test 2: wrong-day appointment was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK   Test 2: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

--Test 3: REJECTED (50001) - Ramirez at the wrong office
BEGIN TRY
    INSERT INTO Appointment(OfficeID, DoctorID, PatientID, ReferralID, Date_Time,
                             AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES(1000001, 1000000, 1000006, NULL, '2026-10-19 11:00',
            'Scheduled', 150.00, 'Phone', NULL, NULL);
        PRINT 'FAIL Test 3: wrong-office appointment was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK   Test 3: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

--Test 4: REJECTED (50002) -Ramirez before opening
BEGIN TRY
    INSERT INTO Appointment(OfficeID, DoctorID, PatientID, ReferralID, Date_Time,
                             AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES(1000000, 1000000, 1000006, NULL, '2026-10-19 07:59',
            'Scheduled', 150.00, 'Phone', NULL, NULL);
        PRINT 'FAIL Test 4: before oppening time appointment was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK   Test 4: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

--Test 5: REJECTED (50002) -Ramirez at closing time
BEGIN TRY
    INSERT INTO Appointment(OfficeID, DoctorID, PatientID, ReferralID, Date_Time,
                             AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES(1000000, 1000000, 1000006, NULL, '2026-10-19 17:00',
            'Scheduled', 150.00, 'Phone', NULL, NULL);
        PRINT 'FAIL Test 5: at closing time appointment was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK   Test 5: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

-- Test 6: ALLOWED - cancelled appointment on Tuesday (wrong day, but cancelled rows are exempt)
BEGIN TRY
    INSERT INTO Appointment (OfficeID, DoctorID, PatientID, ReferralID, Date_Time,
                             AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES (1000000, 1000000, 1000006, NULL, '2026-10-20 10:00',
            'Cancelled', 150.00, 'Phone', 'Patient rescheduled', 'Patient');
    PRINT 'OK   Test 6: valid Cancellation was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 6: valid appointment was rejected: ' + ERROR_MESSAGE();
END CATCH;

--Test 7: REJECTED (50001) - multi-row insert, one valid (Wed) + one invalid (Tue) row
BEGIN TRY
    INSERT INTO Appointment(OfficeID, DoctorID, PatientID, ReferralID, Date_Time,
                             AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES(1000000, 1000000, 1000006, NULL, '2026-10-21 10:00',
            'Scheduled', 150.00, 'Phone', NULL, NULL),
          (1000000, 1000000, 1000006, NULL, '2026-10-20 11:00',
            'Scheduled', 150.00, 'Phone', NULL, NULL);
        PRINT 'FAIL Test 7: multi-row insert with a bad row was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK   Test 7: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;
SELECT COUNT(*) AS Wed21Rows FROM Appointment WHERE Date_Time = '2026-10-21 10:00';

--Test 8 REJECTED (50001) - bad update
BEGIN TRY
    UPDATE Appointment
    SET Date_Time = '2026-10-20 10:00'
    WHERE AppointmentID = 1000000;
        PRINT 'FAIL Test 8: moving an appointment to an unscheduled day was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK   Test 8: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

GO
PRINT '=== Triggers 2 / 2b: overpayment and cancelled appointments ===';

DECLARE @ApptID INT, @Pay1 INT, @Pay2 INT, @Pay3 INT;

-- Setup: a $200 appointment that passes trigger 1 (Ramirez, office 1, Monday 10:00)
INSERT INTO Appointment (OfficeID, DoctorID, PatientID, ReferralID, Date_Time,
                         AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
VALUES (1000000, 1000000, 1000007, NULL, '2026-10-26 10:00',
        'Scheduled', 200.00, 'Phone', NULL, NULL);
SET @ApptID = SCOPE_IDENTITY();

-- Test 9: ALLOWED - payment 1, $120 cash (total 120 of 200)
BEGIN TRY
    INSERT INTO Payment (AppointmentID, InstallmentNumber, PaymentDate, PayStatus)
    VALUES (@ApptID, 1, '2026-10-14', 'Completed');
    SET @Pay1 = SCOPE_IDENTITY();

    INSERT INTO PaymentDetail (PaymentID, MethodID, AmountApplied)
    VALUES (@Pay1, 1, 120.00);          -- MethodID 1 = Cash

    PRINT 'OK   Test 9: $120 payment was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 9: $120 payment was rejected: ' + ERROR_MESSAGE();
END CATCH;

-- Test 10: Alllowed - payment 2, 80 cash (exactly at the limit)
BEGIN TRY
    INSERT INTO Payment(AppointmentID, InstallmentNumber, PaymentDate, PayStatus)
    VALUES(@ApptID, 2, '2026-10-20', 'Completed');
    SET @Pay2 = SCOPE_IDENTITY();

    INSERT INTO PaymentDetail(PaymentID, MethodID, AmountApplied)
    VALUES(@Pay2, 2, 80.00);    --Method 2 = Credit Card

    PRINT 'OK   Test 10: $80 payment was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 10: $80 payment was rejected: ' + ERROR_MESSAGE();
END CATCH;

-- Test 11: REJECTED (50008) - 1 cent over the $200 tota
INSERT INTO Payment(AppointmentID, InstallmentNumber, PaymentDate, PayStatus)
VALUES(@ApptID, 3, '2026-10-22', 'Completed');
SET @Pay3 = SCOPE_IDENTITY();
BEGIN TRY
    INSERT INTO PaymentDetail(PaymentID, MethodID, AmountApplied)
    VALUES(@Pay3, 2, 00.01); 
    PRINT 'FAIL Test 11: payment 1 cent over the total was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK Test 11: ' + ERROR_MESSAGE();
END CATCH;

-- Test 12 Allowed - Payment 1, $120 refunded
BEGIN TRY
    UPDATE Payment
    SET PayStatus = 'Refunded'
    WHERE PaymentID = @Pay1;
    PRINT 'OK   Test 12: $120 Refund was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 12: $120 Refund was rejected: ' + ERROR_MESSAGE();
END CATCH;
    
--Test 13: ALLOWED - $120 on payment 3, fits after the refund (total 200)
BEGIN TRY
    INSERT INTO PaymentDetail(PaymentID, MethodID, AmountApplied)
    VALUES(@Pay3, 2, 120);
    PRINT 'OK   Test 13: $120 payment was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 13: 120 payment was rejected: ' + ERROR_MESSAGE();
END CATCH;

--Test 14: REJECTED (50008) - un-refund payment 1, total would be $320
BEGIN TRY
    UPDATE Payment
    SET PayStatus = 'Completed'
    WHERE PaymentID = @Pay1;
    PRINT 'FAIL Test 14: un-refunding payment 1 was allowed (total $320)';
END TRY
BEGIN CATCH
    PRINT 'OKTest 14: rejected: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + ERROR_MESSAGE();
END CATCH;

-- Test 15: REJECTED (50008) - raise payment 2 from $80 to $81, total would be $201
BEGIN TRY
    UPDATE PaymentDetail
    SET AmountApplied = 81
    WHERE PaymentID = @Pay2 AND MethodID = 2; 
    PRINT 'FAIL Test 15: payment $1 over the total was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK Test 15: rejected ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + ERROR_MESSAGE();
END CATCH;

DECLARE @CancelledApptID INT;
-- Setup for tests 16–17: a cancelled $150 appointment (Mon Oct 26 11:00)
INSERT INTO Appointment (OfficeID, DoctorID, PatientID, ReferralID, Date_Time,
                         AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
VALUES (1000000, 1000000, 1000007, NULL, '2026-10-26 11:00',
        'Cancelled', 150.00, 'Phone', 'No transportation available', 'Patient');
SET  @CancelledApptID = SCOPE_IDENTITY();

-- Test 16: REJECTED (50007) - completed payment on a cancelled appointment
BEGIN TRY
    INSERT INTO Payment (AppointmentID, InstallmentNumber, PaymentDate, PayStatus)
    VALUES (@CancelledApptID, 1, '2026-10-14', 'Completed');

    PRINT 'FAIL Test 16: a completed payment on a cancelled appointment was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK Test 16: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + ERROR_MESSAGE();
END CATCH;

-- Test 17: ALLOWED - refunded payment on a cancelled appointment
BEGIN TRY
    INSERT INTO Payment (AppointmentID, InstallmentNumber, PaymentDate, PayStatus)
    VALUES (@CancelledApptID, 1, '2026-10-14', 'Refunded');

    PRINT 'OK   Test 17: Refund was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 13: Refund was rejected: ' + ERROR_MESSAGE();
END CATCH;

--Test 18: REJECTED (50005) - cancelled appointment back to Scheduled.
Begin TRY
    UPDATE Appointment
    SET AppointStatus = 'Scheduled',
        CancelReason = NULL,
        CancelledBy = NULL
    WHERE AppointmentID = @CancelledApptID;

    PRINT 'FAIL Test 18: reopening a cancelled appointment was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK Test 18: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + ERROR_MESSAGE();
END CATCH;

--Test 19: ALLOWED - normal flow, Scheduled -> Completed
Begin TRY
    UPDATE Appointment
    SET AppointStatus = 'Completed'
    WHERE AppointmentID = @ApptID;

    PRINT 'OK   Test 19: completing a scheduled appointment was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 19: completing was rejected: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + ERROR_MESSAGE();
END CATCH;

-- Test 20: REJECTED (50005) - completed appointment back to Scheduled
Begin TRY
    UPDATE Appointment
    SET AppointStatus = 'Scheduled'
    WHERE AppointmentID = @ApptID;

    PRINT 'FAIL Test 20: reopening a completed appointment was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK Test 20: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + ERROR_MESSAGE();
END CATCH;

-- Test 21: REJECTED (50005) - completed appointment to Cancelled
Begin TRY
    UPDATE Appointment
    SET AppointStatus = 'Cancelled',
        CancelReason = 'Work time conflict',
        CancelledBy = 'Patient'
    WHERE AppointmentID = @ApptID;

    PRINT 'FAIL Test 21: cancelling a completed appointment was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK Test 21: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + ERROR_MESSAGE();
END CATCH;

-- Test 22: ALLOWED - edit a cancelled appointment's reason (status unchanged)
BEGIN TRY
    UPDATE Appointment
    SET CancelReason = 'No transportation available that day'
    WHERE AppointmentID = @CancelledApptID;

    PRINT 'OK   Test 22: editing the cancel reason was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 22: editing the cancel reason was rejected: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + ERROR_MESSAGE();
END CATCH;

GO
PRINT '=== Trigger 4: referral must be issued by the patient''s primary  ===';
DECLARE @RefID INT;
-- Test 23: ALLOWED - Olivia's primary (Ramirez) refers her to Chen
BEGIN TRY
    INSERT INTO Referral (PatientID, SpecialistID, PrimaryID, DateIssued, RefStatus)
    VALUES (1000006, 1000001, 1000000, '2026-10-14','Scheduled');
    SET @RefID = SCOPE_IDENTITY();
    PRINT 'OK   Test 23: Referral was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 23: Referral was rejected: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + ERROR_MESSAGE();
END CATCH;

-- Test 24: REJECTED - Chen (Olivia's specialist, not primary) refers her to Patel
BEGIN TRY
    INSERT INTO Referral (PatientID, SpecialistID, PrimaryID, DateIssued, RefStatus)
    VALUES (1000006, 1000002, 1000001, '2026-10-14','Scheduled');

    PRINT 'FAIL Test 24: non-primary referral was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK Test 24: rejected ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + ERROR_MESSAGE();
END CATCH;

-- Test 25: REJECTED - UPDATE test 23's referral so Patel (not primary) is the issuer
BEGIN TRY
    UPDATE Referral
    SET PrimaryID = 1000002
    WHERE ReferralID = @RefID;

    PRINT 'FAIL Test 25: update to non-primary issuer was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK Test 25: rejected ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' ' + ERROR_MESSAGE();
END CATCH;

-- Test 26: ALLOWED - change only RefStatus (shortcut skips the check), then restore it
DECLARE @Rows INT;
BEGIN TRY
    UPDATE Referral
    SET RefStatus = 'Cancelled'
    WHERE ReferralID = @RefID;
    SET @Rows = @@ROWCOUNT;              -- capture right away; the next statement resets it

    IF @Rows = 1
        PRINT 'OK   Test 26: status-only update was allowed';
    ELSE
        PRINT 'FAIL Test 26: no referral updated (is @RefID NULL?)';

    UPDATE Referral                      -- restore, so trigger 3 tests can use this referral
    SET RefStatus = 'Scheduled'
    WHERE ReferralID = @RefID;
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 26: status-only update was rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

-- Test 27: REJECTED - multi-row insert, one good row (Ethan / Ramirez -> Patel)
--          and one bad row (Olivia / Chen -> Patel); the whole statement must fail
DECLARE @EthanRefs INT;
BEGIN TRY
    INSERT INTO Referral (PatientID, SpecialistID, PrimaryID, DateIssued, RefStatus)
    VALUES (1000007, 1000002, 1000000, '2026-10-14', 'Scheduled'),   -- good
           (1000006, 1000002, 1000001, '2026-10-14', 'Scheduled');   -- bad

    PRINT 'FAIL Test 27: multi-row insert with a bad row was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK   Test 27: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

SELECT @EthanRefs = COUNT(*) FROM Referral WHERE PatientID = 1000007;
IF @EthanRefs = 0
    PRINT 'OK   Test 27: good row was rolled back too (Ethan referrals = 0)';
ELSE
    PRINT 'FAIL Test 27: good row was saved (Ethan referrals = ' + CAST(@EthanRefs AS VARCHAR(10)) + ')';

PRINT '=== Trigger 3: specialist visits need a valid referral ===';
DECLARE @SpecApptID INT;

-- Test 28: ALLOWED - Olivia sees Chen (specialist) with test 23's open referral
BEGIN TRY
    INSERT INTO Appointment (PatientID, DoctorID, OfficeID, ReferralID, Date_Time, AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES (1000006, 1000001, 1000001, @RefID, '2026-10-20 10:00', 'Scheduled', 150.00, 'Phone', NULL, NULL);
    SET @SpecApptID = SCOPE_IDENTITY();
    PRINT 'OK   Test 28: specialist visit with a valid referral was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 28: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

-- Test 29: REJECTED - Ethan sees Chen with no referral
BEGIN TRY
    INSERT INTO Appointment (PatientID, DoctorID, OfficeID, ReferralID, Date_Time, AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES (1000007, 1000001, 1000001, NULL, '2026-10-20 11:00', 'Scheduled', 150.00, 'Phone', NULL, NULL);
    PRINT 'FAIL Test 29: specialist visit without a referral was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK   Test 29: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

-- Test 30: REJECTED - Olivia sees Patel; her referral is to Chen, not Patel
BEGIN TRY
    INSERT INTO Appointment (PatientID, DoctorID, OfficeID, ReferralID, Date_Time, AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES (1000006, 1000002, 1000000, NULL, '2026-10-22 10:00', 'Scheduled', 150.00, 'Phone', NULL, NULL);
    PRINT 'FAIL Test 30: visit to a specialist without their referral was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK   Test 30: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

-- Test 31: ALLOWED - cancelled specialist visit without a referral (cancelled is exempt)
BEGIN TRY
    INSERT INTO Appointment (PatientID, DoctorID, OfficeID, ReferralID, Date_Time, AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES (1000007, 1000001, 1000001, NULL, '2026-10-20 12:00', 'Cancelled', 150.00, 'Phone', 'Patient rescheduled', 'Patient');
    PRINT 'OK   Test 31: cancelled specialist visit was allowed';
END TRY
BEGIN CATCH
    PRINT 'FAIL Test 31: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

-- Test 32: REJECTED - UPDATE test 28's visit so Ethan (no referral) is the patient
BEGIN TRY
    UPDATE Appointment
    SET PatientID = 1000007
    WHERE AppointmentID = @SpecApptID;
    PRINT 'FAIL Test 32: changing to a patient without a referral was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK   Test 32: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;

-- Test 33: REJECTED - Olivia's referral to Chen is cancelled, so a new Chen visit fails
UPDATE Referral SET RefStatus = 'Cancelled' WHERE ReferralID = @RefID;   -- outside TRY
BEGIN TRY
    INSERT INTO Appointment (PatientID, DoctorID, OfficeID, ReferralID, Date_Time, AppointStatus, TotalCost, Channel, CancelReason, CancelledBy)
    VALUES (1000006, 1000001, 1000001, NULL, '2026-10-22 10:00', 'Scheduled', 150.00, 'Phone', NULL, NULL);
    PRINT 'FAIL Test 33: visit with a cancelled referral was allowed';
END TRY
BEGIN CATCH
    PRINT 'OK   Test 33: rejected (' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + '): ' + ERROR_MESSAGE();
END CATCH;
UPDATE Referral SET RefStatus = 'Scheduled' WHERE ReferralID = @RefID;   -- restore, outside TRY