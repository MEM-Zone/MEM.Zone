/*
.SYNOPSIS
    This SQL Query is used to get the MBAM compliance in SCCM.
.DESCRIPTION
    This SQL Query is used to get the MBAM compliance in SCCM, and displays verbose info.
.NOTES
    Created by
        Ioan Popovici   2018-09-2018
    Release notes
        ---https://github.com/Ioan-Popovici/SCCMZone/blob/master/Reporting/Hardware/HW%20BIOS%20by%20Company%20or%20Manufacturer/CHANGELOG.md
    This query is part of a report should not be run separately.
.LINK
    https://SCCM-Zone.com
.LINK
    https://github.com/Ioan-Popovici/SCCMZone
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* Initialize KeyProtectorTypesTable descriptor table */
DECLARE @KeyProtectorTypesTable TABLE
(
    KeyProtectorType varchar(2),
    KeyProtectorName varchar(60)
)

/* Initialize ReasonsForNonComplianceTable descriptor table */
DECLARE @ReasonsForNonComplianceTable TABLE
(
    NonComplianceCode varchar(2),
    ReasonForNonCompliance varchar(110)
)

/* Populate KeyProtectorTypesTable table */
INSERT INTO @KeyProtectorTypesTable
    (KeyProtectorType, KeyProtectorName)
VALUES
    ('0', 'Unknown or other protector type'),
    ('1', 'Trusted Platform Module (TPM)'),
    ('2', 'External key'),
    ('3', 'Numerical password'),
    ('4', 'TPM And PIN'),
    ('5', 'TPM And Startup Key'),
    ('6', 'TPM And PIN And Startup Key'),
    ('7', 'Public Key'),
    ('8', 'Passphrase'),
    ('9', 'TPM Certificate'),
    ('10', 'CryptoAPI Next Generation (CNG) Protector');

/* Populate ReasonsForNonComplianceTable table */
INSERT INTO @ReasonsForNonComplianceTable
    (NonComplianceCode, ReasonForNonCompliance)
VALUES
    ('0', 'Cipher strength not AES 256'),
    ('1', 'MBAM Policy requires this volume to be encrypted but it is not'),
    ('2', 'MBAM Policy requires this volume to NOT be encrypted, but it is'),
    ('3', 'MBAM Policy requires this volume use a TPM protector, but it does not'),
    ('4', 'MBAM Policy requires this volume use a TPM+PIN protector, but it does not'),
    ('5', 'MBAM Policy does not allow non TPM machines to report as compliant'),
    ('6', 'Volume has a TPM protector but the TPM is not visible (booted with recover key after disabling TPM in BIOS?)'),
    ('7', 'MBAM Policy requires this volume use a password protector, but it does not have one'),
    ('8', 'MBAM Policy requires this volume NOT use a password protector, but it has one'),
    ('9', 'MBAM Policy requires this volume use an auto-unlock protector, but it does not have one'),
    ('10', 'MBAM Policy requires this volume NOT use an auto-unlock protector, but it has one'),
    ('11', 'Policy conflict detected preventing MBAM from reporting this volume as compliant'),
    ('12', 'A system volume is needed to encrypt the OS volume but it is not present'),
    ('13', 'Protection is suspended for the volume'),
    ('14', 'AutoUnlock unsafe unless the OS volume is encrypted'),
    ('15', 'Policy requires minimum cypher strength is XTS-AES-128 bit, actual cypher strength is weaker than that'),
    ('16', 'Policy requires minimum cypher strength is XTS-AES-256 bit, actual cypher strength is weaker than that');

/* Get MBAM data */
SELECT
    DriveLetter0 AS DriveLetter,
    Compliance =
	(
		CASE Compliant0
			WHEN 0 THEN 'NotCompliant'
			WHEN 1 THEN 'Compliant'
			WHEN 2 THEN 'NotApplicable'
		END
	),
    ConversionStatus =
	(
		CASE ConversionStatus0
			WHEN 0 THEN 'FullyDecrypted'
			WHEN 1 THEN 'FullyEncrypted'
			WHEN 2 THEN 'EncryptionInProgress'
			WHEN 3 THEN 'DecryptionInProgress'
			WHEN 4 THEN 'EncryptionPaused'
			WHEN 5 THEN 'DecryptionPaused'
		END
	),
    EncryptionMethod =
	(
		CASE EncryptionMethod0
			WHEN 0 THEN 'None'
			WHEN 1 THEN 'AES_128_WITH_DIFFUSER'
			WHEN 2 THEN 'AES_256_WITH_DIFFUSER'
			WHEN 3 THEN 'AES_128'
			WHEN 4 THEN 'AES_256'
			WHEN 5 THEN 'HARDWARE_ENCRYPTION'
			WHEN 6 THEN 'XTS_AES_128'
			WHEN 7 THEN 'XTS_AES_256'
			WHEN -1 THEN 'UNKNOWN'
		END
	),
    KeyProtectorTypes =
    (
		STUFF (
			REPLACE (
				(
					SELECT '#!' + LTRIM(RTRIM(KeyprotectorName)) AS [data()]
                    FROM @KeyProtectorTypesTable
                    WHERE KeyProtectorTypes0 LIKE '%'+KeyProtectorType+'%'
                    FOR XML PATH('')
                ),
			    ' #!',', '
			),
			1, 2, ''
		)
    ),
    MbamVolumeType =
    (
		CASE MbamVolumeType0
			WHEN 0 THEN 'OSVolume'
			WHEN 1 THEN 'FixedDataVolume'
			WHEN 2 THEN 'PortableDataVolume'
			WHEN 3 THEN 'VirtualDataVolume'
		END
    ),
    ReasonsForNonCompliance =
    (
		STUFF (
			REPLACE (
				(
					SELECT '#!' + LTRIM(RTRIM(ReasonForNonCompliance)) AS [data()]
                    FROM @ReasonsForNonComplianceTable
                    WHERE ReasonsForNonCompliance0 LIKE '%'+NonComplianceCode+'%'
                    FOR XML PATH('')
                ),
				' #!','; '
			),
			1, 2, ''
		)
	),
    IsAutoUnlockEnabled =
    (
		CASE IsAutoUnlockEnabled0
			WHEN 0 THEN 'Yes'
			ELSE 'No'
		END
    )
FROM
    fn_rbac_GS_BITLOCKER_DETAILS(1)

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/
