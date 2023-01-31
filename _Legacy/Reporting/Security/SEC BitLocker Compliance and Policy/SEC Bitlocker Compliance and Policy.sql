/*
.SYNOPSIS
    Gets the BitLocker compliance in SCCM.
.DESCRIPTION
    Gets the BitLocker compliance and policy with SCCM custom HWI extensions.
.NOTES
    Created by Ioan Popovici
    Requires SCCM with SSRS/SQL, HWI Extension
.LINK
    BlogPost: https://SCCM.Zone/SEC-BitLocker-Compliance-And-Policy
.LINK
    Changes : https://SCCM.Zone/SEC-BitLocker-Compliance-And-Policy-CHANGELOG
.LINK
    Github  : https://SCCM.Zone/SEC-BitLocker-Compliance-And-Policy-GIT
.LINK
    Issues  : https://SCCM.Zone/Issues
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* Testing variables !! Need to be commented for Production !! */
--DECLARE @UserSIDs               NVARCHAR (16) = 'Disabled';
--DECLARE @CollectionID           NVARCHAR (16) = 'A01000B3';
--DECLARE @ExcludeVirtualMachines NVARCHAR (3)  = 'No';

/* Get BitLocker data */
SELECT
    DeviceName                         = ComputerSystem.Name0
	, Manufacturer                     = ComputerSystem.Manufacturer0
    , Model                            =
    (
        CASE
            WHEN ComputerSystem.Model0 LIKE '10AA%' THEN 'ThinkCentre M93p'
            WHEN ComputerSystem.Model0 LIKE '10AB%' THEN 'ThinkCentre M93p'
            WHEN ComputerSystem.Model0 LIKE '10AE%' THEN 'ThinkCentre M93z'
            WHEN ComputerSystem.Model0 LIKE '10FLS1TJ%' THEN 'ThinkCentre M900'
            WHEN ComputerProduct.Version0 = 'Lenovo Product' THEN ('Unknown ' + ComputerSystem.Model0)
            WHEN ComputerSystem.Manufacturer0 = 'LENOVO' THEN ComputerProduct.Version0
            ELSE ComputerSystem.Model0
        END
    )
    , OperatingSystem                  =
	(
        CONCAT(
            CASE
                WHEN OperatingSystem.Caption0 != '' THEN
                    CONCAT(
                        REPLACE(OperatingSystem.Caption0, 'Microsoft ', ''),         --Remove 'Microsoft ' from OperatingSystem
                        REPLACE(OperatingSystem.CSDVersion0, 'Service Pack ', ' SP') --Replace 'Service Pack ' with ' SP' in OperatingSystem
                    )
                ELSE

                /* Workaround for systems not in GS_OPERATING_SYSTEM table */
                (
                    CASE
                        WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.1%'    THEN 'Windows 7'
                        WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.2%'    THEN 'Windows 8'
                        WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.3%'    THEN 'Windows 8.1'
                        WHEN CombinedResources.DeviceOS LIKE '%Workstation 10.0%'   THEN 'Windows 10'
                        WHEN CombinedResources.DeviceOS LIKE '%Server 6.0'          THEN 'Windows Server 2008'
                        WHEN CombinedResources.DeviceOS LIKE '%Server 6.1'          THEN 'Windows Server 2008R2'
                        WHEN CombinedResources.DeviceOS LIKE '%Server 6.2'          THEN 'Windows Server 2012'
                        WHEN CombinedResources.DeviceOS LIKE '%Server 6.3'          THEN 'Windows Server 2012 R2'
                        WHEN CombinedResources.DeviceOS LIKE '%Server 10.0'         THEN 'Windows Server 2016'
                        ELSE 'Unknown'
                    END
                )
            END
            , ' ' +
            (
                SELECT OSLocalizedNames.Value
                FROM fn_GetWindowsServicingLocalizedNames() AS OSLocalizedNames
                    INNER JOIN fn_GetWindowsServicingStates() AS OSServicingStates ON OSServicingStates.Build = System.Build01
                WHERE OSLocalizedNames.Name = OSServicingStates.Name
                    AND System.OSBranch01 = OSServicingStates.branch --Select only the branch of the installed OS
            )
        )
	)
    , BuildNumber                      = OperatingSystem.Version0
	, ManufacturerID                   = TPM.ManufacturerId0
	, ManufacturerVersion              = TPM.ManufacturerVersion0
	, PhysicalPresenceVersion          = TPM.PhysicalPresenceVersionInfo0
	, SpecVersion                      = TPM.SpecVersion0
	, BitlockerPolicy                  =
    (

    /* Only keys with values will be selected. It looks like shit, need to create a function in SSRS for this */
        SELECT
            'General:;;'
            + CASE ActiveDirectoryBackup0        WHEN '' THEN '' ELSE 'ActiveDirectoryBackup'                        + ' = ' + COALESCE(CAST(ActiveDirectoryBackup0        AS NVARCHAR), '') + ';' END
            + CASE ActiveDirectoryInfoToStore0   WHEN '' THEN '' ELSE 'ActiveDirectoryInfoToStore'                   + ' = ' + COALESCE(CAST(ActiveDirectoryInfoToStore0   AS NVARCHAR), '') + ';' END
            + CASE CertificateOID0               WHEN '' THEN '' ELSE 'CertificateOID'                               + ' = ' + COALESCE(CAST(CertificateOID0               AS NVARCHAR), '') + ';' END
            + CASE DefaultRecoveryFolderPath0    WHEN '' THEN '' ELSE 'DefaultRecoveryFolderPath'                    + ' = ' + COALESCE(CAST(DefaultRecoveryFolderPath0    AS NVARCHAR), '') + ';' END
            + CASE DisableExternalDMAUnderLock0  WHEN '' THEN '' ELSE 'DisableExternalDMAUnderLock'                  + ' = ' + COALESCE(CAST(DisableExternalDMAUnderLock0  AS NVARCHAR), '') + ';' END
            + CASE DisallowStandardUserPINReset0 WHEN '' THEN '' ELSE 'DisallowStandardUserPINReset'                 + ' = ' + COALESCE(CAST(DisallowStandardUserPINReset0 AS NVARCHAR), '') + ';' END
            + CASE EnableBDEWithNoTPM0           WHEN '' THEN '' ELSE 'EnableBDEWithNoTPM'                           + ' = ' + COALESCE(CAST(EnableBDEWithNoTPM0           AS NVARCHAR), '') + ';' END
            + CASE EnableNonTPM0                 WHEN '' THEN '' ELSE 'EnableNonTPM'                                 + ' = ' + COALESCE(CAST(EnableNonTPM0                 AS NVARCHAR), '') + ';' END
            + CASE EncryptionMethod0             WHEN '' THEN '' ELSE 'EncryptionMethod'                             + ' = ' + COALESCE(CAST(EncryptionMethod0             AS NVARCHAR), '') + ';' END
            + CASE EncryptionMethodNoDiffuser0   WHEN '' THEN '' ELSE 'EncryptionMethodNoDiffuser'                   + ' = ' + COALESCE(CAST(EncryptionMethodNoDiffuser0   AS NVARCHAR), '') + ';' END
            + CASE EncryptionMethodWithXtsFdv0   WHEN '' THEN '' ELSE 'EncryptionMethodWithXtsFdv'                   + ' = ' + COALESCE(CAST(EncryptionMethodWithXtsFdv0   AS NVARCHAR), '') + ';' END
            + CASE EncryptionMethodWithXtsOs0    WHEN '' THEN '' ELSE 'EncryptionMethodWithXtsOs'                    + ' = ' + COALESCE(CAST(EncryptionMethodWithXtsOs0    AS NVARCHAR), '') + ';' END
            + CASE EncryptionMethodWithXtsRdv0   WHEN '' THEN '' ELSE 'EncryptionMethodWithXtsRdv'                   + ' = ' + COALESCE(CAST(EncryptionMethodWithXtsRdv0   AS NVARCHAR), '') + ';' END
            + CASE IdentificationField0          WHEN '' THEN '' ELSE 'IdentificationField'                          + ' = ' + COALESCE(CAST(IdentificationField0          AS NVARCHAR), '') + ';' END
            + CASE IdentificationFieldString0    WHEN '' THEN '' ELSE 'IdentificationFieldString'                    + ' = ' + COALESCE(CAST(IdentificationFieldString0    AS NVARCHAR), '') + ';' END
            + CASE MinimumPIN0                   WHEN '' THEN '' ELSE 'MinimumPIN'                                   + ' = ' + COALESCE(CAST(MinimumPIN0                   AS NVARCHAR), '') + ';' END
            + CASE MorBehavior0                  WHEN '' THEN '' ELSE 'MorBehavior'                                  + ' = ' + COALESCE(CAST(MorBehavior0                  AS NVARCHAR), '') + ';' END
            + CASE RecoveryKeyMessage0           WHEN '' THEN '' ELSE 'RecoveryKeyMessage'                           + ' = ' + COALESCE(CAST(RecoveryKeyMessage0           AS NVARCHAR), '') + ';' END
            + CASE RecoveryKeyMessageSource0     WHEN '' THEN '' ELSE 'RecoveryKeyMessageSource'                     + ' = ' + COALESCE(CAST(RecoveryKeyMessageSource0     AS NVARCHAR), '') + ';' END
            + CASE RecoveryKeyUrl0               WHEN '' THEN '' ELSE 'RecoveryKeyUrl'                               + ' = ' + COALESCE(CAST(RecoveryKeyUrl0               AS NVARCHAR), '') + ';' END
            + CASE RequireActiveDirectoryBackup0 WHEN '' THEN '' ELSE 'RequireActiveDirectoryBackup'                 + ' = ' + COALESCE(CAST(RequireActiveDirectoryBackup0 AS NVARCHAR), '') + ';' END
            + CASE SecondaryIdentificationField0 WHEN '' THEN '' ELSE 'SecondaryIdentificationField'                 + ' = ' + COALESCE(CAST(SecondaryIdentificationField0 AS NVARCHAR), '') + ';' END
            + CASE TPMAutoReseal0                WHEN '' THEN '' ELSE 'TPMAutoReseal'                                + ' = ' + COALESCE(CAST(TPMAutoReseal0                AS NVARCHAR), '') + ';' END
            + CASE UseAdvancedStartup0           WHEN '' THEN '' ELSE 'UseAdvancedStartup'                           + ' = ' + COALESCE(CAST(UseAdvancedStartup0           AS NVARCHAR), '') + ';' END
            + CASE UseEnhancedPin0               WHEN '' THEN '' ELSE 'UseEnhancedPin'                               + ' = ' + COALESCE(CAST(UseEnhancedPin0               AS NVARCHAR), '') + ';' END
            + CASE UsePartialEncryptionKey0      WHEN '' THEN '' ELSE 'UsePartialEncryptionKey'                      + ' = ' + COALESCE(CAST(UsePartialEncryptionKey0      AS NVARCHAR), '') + ';' END
            + CASE UsePIN0                       WHEN '' THEN '' ELSE 'UsePIN'                                       + ' = ' + COALESCE(CAST(UsePIN0                       AS NVARCHAR), '') + ';' END
            + CASE UseRecoveryDrive0             WHEN '' THEN '' ELSE 'UseRecoveryDrive'                             + ' = ' + COALESCE(CAST(UseRecoveryDrive0             AS NVARCHAR), '') + ';' END
            + CASE UseRecoveryPassword0          WHEN '' THEN '' ELSE 'UseRecoveryPassword'                          + ' = ' + COALESCE(CAST(UseRecoveryPassword0          AS NVARCHAR), '') + ';' END
            + CASE UseTPM0                       WHEN '' THEN '' ELSE 'UseTPM'                                       + ' = ' + COALESCE(CAST(UseTPM0                       AS NVARCHAR), '') + ';' END
            + CASE UseTPMKey0                    WHEN '' THEN '' ELSE 'UseTPMKey'                                    + ' = ' + COALESCE(CAST(UseTPMKey0                    AS NVARCHAR), '') + ';' END
            + CASE UseTPMKeyPIN0                 WHEN '' THEN '' ELSE 'UseTPMKeyPIN'                                 + ' = ' + COALESCE(CAST(UseTPMKeyPIN0                 AS NVARCHAR), '') + ';' END
            + CASE UseTPMPIN0                    WHEN '' THEN '' ELSE 'UseTPMPIN'                                    + ' = ' + COALESCE(CAST(UseTPMPIN0                    AS NVARCHAR), '') + ';' END
            + ';OSDrives:;;'
            + CASE OSActiveDirectoryBackup0      WHEN '' THEN '' ELSE 'OSActiveDirectoryBackup'                      + ' = ' + COALESCE(CAST(OSActiveDirectoryBackup0      AS NVARCHAR), '') + ';' END
            + CASE OSActiveDirectoryInfoToStore0 WHEN '' THEN '' ELSE 'OSActiveDirectoryInfoToStore'                 + ' = ' + COALESCE(CAST(OSActiveDirectoryInfoToStore0 AS NVARCHAR), '') + ';' END
            + CASE OSAllowedHardwareEncryptionA0 WHEN '' THEN '' ELSE 'OSAllowedHardwareEncryptionAlgorithms'        + ' = ' + COALESCE(CAST(OSAllowedHardwareEncryptionA0 AS NVARCHAR), '') + ';' END
            + CASE OSAllowSecureBootForIntegrit0 WHEN '' THEN '' ELSE 'OSAllowSecureBootForIntegrity'                + ' = ' + COALESCE(CAST(OSAllowSecureBootForIntegrit0 AS NVARCHAR), '') + ';' END
            + CASE OSAllowSoftwareEncryptionFai0 WHEN '' THEN '' ELSE 'OSAllowSoftwareEncryptionFailover'            + ' = ' + COALESCE(CAST(OSAllowSoftwareEncryptionFai0 AS NVARCHAR), '') + ';' END
            + CASE OSBcdAdditionalExcludedSetti0 WHEN '' THEN '' ELSE 'OSBcdAdditionalExcludedSettings'              + ' = ' + COALESCE(CAST(OSBcdAdditionalExcludedSetti0 AS NVARCHAR), '') + ';' END
            + CASE OSBcdAdditionalSecurityCriti0 WHEN '' THEN '' ELSE 'OSBcdAdditionalSecurityCriticalSettings'      + ' = ' + COALESCE(CAST(OSBcdAdditionalSecurityCriti0 AS NVARCHAR), '') + ';' END
            + CASE OSEnablePrebootInputProtecto0 WHEN '' THEN '' ELSE 'OSEnablePrebootInputProtectorsOnSlates'       + ' = ' + COALESCE(CAST(OSEnablePrebootInputProtecto0 AS NVARCHAR), '') + ';' END
            + CASE OSEnablePreBootPinExceptionO0 WHEN '' THEN '' ELSE 'OSEnablePreBootPinExceptionOnDECapableDevice' + ' = ' + COALESCE(CAST(OSEnablePreBootPinExceptionO0 AS NVARCHAR), '') + ';' END
            + CASE OSEncryptionType0             WHEN '' THEN '' ELSE 'OSEncryptionType'                             + ' = ' + COALESCE(CAST(OSEncryptionType0             AS NVARCHAR), '') + ';' END
            + CASE OSHardwareEncryption0         WHEN '' THEN '' ELSE 'OSHardwareEncryption'                         + ' = ' + COALESCE(CAST(OSHardwareEncryption0         AS NVARCHAR), '') + ';' END
            + CASE OSHideRecoveryPage0           WHEN '' THEN '' ELSE 'OSHideRecoveryPage'                           + ' = ' + COALESCE(CAST(OSHideRecoveryPage0           AS NVARCHAR), '') + ';' END
            + CASE OSManageDRA0                  WHEN '' THEN '' ELSE 'OSManageDRA'                                  + ' = ' + COALESCE(CAST(OSManageDRA0                  AS NVARCHAR), '') + ';' END
            + CASE OSManageNKP0                  WHEN '' THEN '' ELSE 'OSManageNKP'                                  + ' = ' + COALESCE(CAST(OSManageNKP0                  AS NVARCHAR), '') + ';' END
            + CASE OSPassphrase0                 WHEN '' THEN '' ELSE 'OSPassphrase'                                 + ' = ' + COALESCE(CAST(OSPassphrase0                 AS NVARCHAR), '') + ';' END
            + CASE OSPassphraseASCIIOnly0        WHEN '' THEN '' ELSE 'OSPassphraseASCIIOnly'                        + ' = ' + COALESCE(CAST(OSPassphraseASCIIOnly0        AS NVARCHAR), '') + ';' END
            + CASE OSPassphraseComplexity0       WHEN '' THEN '' ELSE 'OSPassphraseComplexity'                       + ' = ' + COALESCE(CAST(OSPassphraseComplexity0       AS NVARCHAR), '') + ';' END
            + CASE OSPassphraseLength0           WHEN '' THEN '' ELSE 'OSPassphraseLength'                           + ' = ' + COALESCE(CAST(OSPassphraseLength0           AS NVARCHAR), '') + ';' END
            + CASE OSRecovery0                   WHEN '' THEN '' ELSE 'OSRecovery'                                   + ' = ' + COALESCE(CAST(OSRecovery0                   AS NVARCHAR), '') + ';' END
            + CASE OSRecoveryKey0                WHEN '' THEN '' ELSE 'OSRecoveryKey'                                + ' = ' + COALESCE(CAST(OSRecoveryKey0                AS NVARCHAR), '') + ';' END
            + CASE OSRecoveryPassword0           WHEN '' THEN '' ELSE 'OSRecoveryPassword'                           + ' = ' + COALESCE(CAST(OSRecoveryPassword0           AS NVARCHAR), '') + ';' END
            + CASE OSRequireActiveDirectoryBack0 WHEN '' THEN '' ELSE 'OSRequireActiveDirectoryBackup'               + ' = ' + COALESCE(CAST(OSRequireActiveDirectoryBack0 AS NVARCHAR), '') + ';' END
            + CASE OSRestrictHardwareEncryption0 WHEN '' THEN '' ELSE 'OSRestrictHardwareEncryptionAlgorithms'       + ' = ' + COALESCE(CAST(OSRestrictHardwareEncryption0 AS NVARCHAR), '') + ';' END
            + CASE OSUseEnhancedBcdProfile0      WHEN '' THEN '' ELSE 'OSUseEnhancedBcdProfile'                      + ' = ' + COALESCE(CAST(OSUseEnhancedBcdProfile0      AS NVARCHAR), '') + ';' END
            + ';FixedDrives:;;'
            + CASE FDVActiveDirectoryBackup0     WHEN '' THEN '' ELSE 'FDVActiveDirectoryBackup'                     + ' = ' + COALESCE(CAST(FDVActiveDirectoryBackup0     AS NVARCHAR), '') + ';' END
            + CASE FDVActiveDirectoryInfoToStor0 WHEN '' THEN '' ELSE 'FDVActiveDirectoryInfoToStore'                + ' = ' + COALESCE(CAST(FDVActiveDirectoryInfoToStor0 AS NVARCHAR), '') + ';' END
            + CASE FDVAllowedHardwareEncryption0 WHEN '' THEN '' ELSE 'FDVAllowedHardwareEncryptionAlgorithms'       + ' = ' + COALESCE(CAST(FDVAllowedHardwareEncryption0 AS NVARCHAR), '') + ';' END
            + CASE FDVAllowSoftwareEncryptionFa0 WHEN '' THEN '' ELSE 'FDVAllowSoftwareEncryptionFailover'           + ' = ' + COALESCE(CAST(FDVAllowSoftwareEncryptionFa0 AS NVARCHAR), '') + ';' END
            + CASE FDVAllowUserCert0             WHEN '' THEN '' ELSE 'FDVAllowUserCert'                             + ' = ' + COALESCE(CAST(FDVAllowUserCert0             AS NVARCHAR), '') + ';' END
            + CASE FDVDiscoveryVolumeType0       WHEN '' THEN '' ELSE 'FDVDiscoveryVolumeType'                       + ' = ' + COALESCE(CAST(FDVDiscoveryVolumeType0       AS NVARCHAR), '') + ';' END
            + CASE FDVEncryptionType0            WHEN '' THEN '' ELSE 'FDVEncryptionType'                            + ' = ' + COALESCE(CAST(FDVEncryptionType0            AS NVARCHAR), '') + ';' END
            + CASE FDVEnforcePassphrase0         WHEN '' THEN '' ELSE 'FDVEnforcePassphrase'                         + ' = ' + COALESCE(CAST(FDVEnforcePassphrase0         AS NVARCHAR), '') + ';' END
            + CASE FDVEnforceUserCert0           WHEN '' THEN '' ELSE 'FDVEnforceUserCert'                           + ' = ' + COALESCE(CAST(FDVEnforceUserCert0           AS NVARCHAR), '') + ';' END
            + CASE FDVHardwareEncryption0        WHEN '' THEN '' ELSE 'FDVHardwareEncryption'                        + ' = ' + COALESCE(CAST(FDVHardwareEncryption0        AS NVARCHAR), '') + ';' END
            + CASE FDVHideRecoveryPage0          WHEN '' THEN '' ELSE 'FDVHideRecoveryPage'                          + ' = ' + COALESCE(CAST(FDVHideRecoveryPage0          AS NVARCHAR), '') + ';' END
            + CASE FDVManageDRA0                 WHEN '' THEN '' ELSE 'FDVManageDRA'                                 + ' = ' + COALESCE(CAST(FDVManageDRA0                 AS NVARCHAR), '') + ';' END
            + CASE FDVNoBitLockerToGoReader0     WHEN '' THEN '' ELSE 'FDVNoBitLockerToGoReader'                     + ' = ' + COALESCE(CAST(FDVNoBitLockerToGoReader0     AS NVARCHAR), '') + ';' END
            + CASE FDVPassphrase0                WHEN '' THEN '' ELSE 'FDVPassphrase'                                + ' = ' + COALESCE(CAST(FDVPassphrase0                AS NVARCHAR), '') + ';' END
            + CASE FDVPassphraseComplexity0      WHEN '' THEN '' ELSE 'FDVPassphraseComplexity'                      + ' = ' + COALESCE(CAST(FDVPassphraseComplexity0      AS NVARCHAR), '') + ';' END
            + CASE FDVPassphraseLength0          WHEN '' THEN '' ELSE 'FDVPassphraseLength'                          + ' = ' + COALESCE(CAST(FDVPassphraseLength0          AS NVARCHAR), '') + ';' END
            + CASE FDVRecovery0                  WHEN '' THEN '' ELSE 'FDVRecovery'                                  + ' = ' + COALESCE(CAST(FDVRecovery0                  AS NVARCHAR), '') + ';' END
            + CASE FDVRecoveryKey0               WHEN '' THEN '' ELSE 'FDVRecoveryKey'                               + ' = ' + COALESCE(CAST(FDVRecoveryKey0               AS NVARCHAR), '') + ';' END
            + CASE FDVRecoveryPassword0          WHEN '' THEN '' ELSE 'FDVRecoveryPassword'                          + ' = ' + COALESCE(CAST(FDVRecoveryPassword0          AS NVARCHAR), '') + ';' END
            + CASE FDVRequireActiveDirectoryBac0 WHEN '' THEN '' ELSE 'FDVRequireActiveDirectoryBackup'              + ' = ' + COALESCE(CAST(FDVRequireActiveDirectoryBac0 AS NVARCHAR), '') + ';' END
            + CASE FDVRestrictHardwareEncryptio0 WHEN '' THEN '' ELSE 'FDVRestrictHardwareEncryptionAlgorithms'      + ' = ' + COALESCE(CAST(FDVRestrictHardwareEncryptio0 AS NVARCHAR), '') + ';' END
            + ';RemovableDrives:;;'
            + CASE RDVActiveDirectoryBackup0     WHEN '' THEN '' ELSE 'RDVActiveDirectoryBackup'                     + ' = ' + COALESCE(CAST(RDVActiveDirectoryBackup0     AS NVARCHAR), '') + ';' END
            + CASE RDVActiveDirectoryInfoToStor0 WHEN '' THEN '' ELSE 'RDVActiveDirectoryInfoToStore'                + ' = ' + COALESCE(CAST(RDVActiveDirectoryInfoToStor0 AS NVARCHAR), '') + ';' END
            + CASE RDVAllowBDE0                  WHEN '' THEN '' ELSE 'RDVAllowBDE'                                  + ' = ' + COALESCE(CAST(RDVAllowBDE0                  AS NVARCHAR), '') + ';' END
            + CASE RDVAllowedHardwareEncryption0 WHEN '' THEN '' ELSE 'RDVAllowedHardwareEncryptionAlgorithms'       + ' = ' + COALESCE(CAST(RDVAllowedHardwareEncryption0 AS NVARCHAR), '') + ';' END
            + CASE RDVAllowSoftwareEncryptionFa0 WHEN '' THEN '' ELSE 'RDVAllowSoftwareEncryptionFailover'           + ' = ' + COALESCE(CAST(RDVAllowSoftwareEncryptionFa0 AS NVARCHAR), '') + ';' END
            + CASE RDVAllowUserCert0             WHEN '' THEN '' ELSE 'RDVAllowUserCert'                             + ' = ' + COALESCE(CAST(RDVAllowUserCert0             AS NVARCHAR), '') + ';' END
            + CASE RDVConfigureBDE0              WHEN '' THEN '' ELSE 'RDVConfigureBDE'                              + ' = ' + COALESCE(CAST(RDVConfigureBDE0              AS NVARCHAR), '') + ';' END
            + CASE RDVDenyCrossOrg0              WHEN '' THEN '' ELSE 'RDVDenyCrossOrg'                              + ' = ' + COALESCE(CAST(RDVDenyCrossOrg0              AS NVARCHAR), '') + ';' END
            + CASE RDVDisableBDE0                WHEN '' THEN '' ELSE 'RDVDisableBDE'                                + ' = ' + COALESCE(CAST(RDVDisableBDE0                AS NVARCHAR), '') + ';' END
            + CASE RDVDiscoveryVolumeType0       WHEN '' THEN '' ELSE 'RDVDiscoveryVolumeType'                       + ' = ' + COALESCE(CAST(RDVDiscoveryVolumeType0       AS NVARCHAR), '') + ';' END
            + CASE RDVEncryptionType0            WHEN '' THEN '' ELSE 'RDVEncryptionType'                            + ' = ' + COALESCE(CAST(RDVEncryptionType0            AS NVARCHAR), '') + ';' END
            + CASE RDVEnforcePassphrase0         WHEN '' THEN '' ELSE 'RDVEnforcePassphrase'                         + ' = ' + COALESCE(CAST(RDVEnforcePassphrase0         AS NVARCHAR), '') + ';' END
            + CASE RDVEnforceUserCert0           WHEN '' THEN '' ELSE 'RDVEnforceUserCert'                           + ' = ' + COALESCE(CAST(RDVEnforceUserCert0           AS NVARCHAR), '') + ';' END
            + CASE RDVHardwareEncryption0        WHEN '' THEN '' ELSE 'RDVHardwareEncryption'                        + ' = ' + COALESCE(CAST(RDVHardwareEncryption0        AS NVARCHAR), '') + ';' END
            + CASE RDVHideRecoveryPage0          WHEN '' THEN '' ELSE 'RDVHideRecoveryPage'                          + ' = ' + COALESCE(CAST(RDVHideRecoveryPage0          AS NVARCHAR), '') + ';' END
            + CASE RDVManageDRA0                 WHEN '' THEN '' ELSE 'RDVManageDRA'                                 + ' = ' + COALESCE(CAST(RDVManageDRA0                 AS NVARCHAR), '') + ';' END
            + CASE RDVNoBitLockerToGoReader0     WHEN '' THEN '' ELSE 'RDVNoBitLockerToGoReader'                     + ' = ' + COALESCE(CAST(RDVNoBitLockerToGoReader0     AS NVARCHAR), '') + ';' END
            + CASE RDVPassphrase0                WHEN '' THEN '' ELSE 'RDVPassphrase'                                + ' = ' + COALESCE(CAST(RDVPassphrase0                AS NVARCHAR), '') + ';' END
            + CASE RDVPassphraseComplexity0      WHEN '' THEN '' ELSE 'RDVPassphraseComplexity'                      + ' = ' + COALESCE(CAST(RDVPassphraseComplexity0      AS NVARCHAR), '') + ';' END
            + CASE RDVPassphraseLength0          WHEN '' THEN '' ELSE 'RDVPassphraseLength'                          + ' = ' + COALESCE(CAST(RDVPassphraseLength0          AS NVARCHAR), '') + ';' END
            + CASE RDVRecovery0                  WHEN '' THEN '' ELSE 'RDVRecovery'                                  + ' = ' + COALESCE(CAST(RDVRecovery0                  AS NVARCHAR), '') + ';' END
            + CASE RDVRecoveryKey0               WHEN '' THEN '' ELSE 'RDVRecoveryKey'                               + ' = ' + COALESCE(CAST(RDVRecoveryKey0               AS NVARCHAR), '') + ';' END
            + CASE RDVRecoveryPassword0          WHEN '' THEN '' ELSE 'RDVRecoveryPassword'                          + ' = ' + COALESCE(CAST(RDVRecoveryPassword0          AS NVARCHAR), '') + ';' END
            + CASE RDVRequireActiveDirectoryBac0 WHEN '' THEN '' ELSE 'RDVRequireActiveDirectoryBackup'              + ' = ' + COALESCE(CAST(RDVRequireActiveDirectoryBac0 AS NVARCHAR), '') + ';' END
            + CASE RDVRestrictHardwareEncryptio0 WHEN '' THEN '' ELSE 'RDVRestrictHardwareEncryptionAlgorithms'      + ' = ' + COALESCE(CAST(RDVRestrictHardwareEncryptio0 AS NVARCHAR), '') + ';' END
        FROM v_GS_CUSTOM_BITLOCKER_POLICY0
        WHERE ResourceID = BitLocker.ResourceID
    )
    , IsVolumeInitializedForProtection =
    (
		CASE BitLocker.IsVolumeInitializedForProtec0
			WHEN 0 THEN 'No'
			WHEN 1 THEN 'Yes'
        END
	)
    , Volume                           = BitLocker.DriveLetter0
    , ProtectionStatus                 =
    (
		CASE BitLocker.ProtectionStatus0
			WHEN 0 THEN 'OFF'
			WHEN 1 THEN 'ON'
			WHEN 2 THEN 'UNKNOWN'
        END
	)
    , ConversionStatus                  =
    (
		CASE BitLocker.ConversionStatus0
			WHEN 0 THEN 'FullyDecrypted'
			WHEN 1 THEN 'FullyEncrypted'
			WHEN 2 THEN 'EncryptionInProgress'
			WHEN 3 THEN 'DecryptionInProgress'
			WHEN 4 THEN 'EncryptionPaused'
			WHEN 5 THEN 'DecryptionPaused'
        END
	)
    , EncryptionMethod                  =
    (
		CASE BitLocker.EncryptionMethod0
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
	)
    , VolumeType                        =
    (
		CASE BitLocker.VolumeType0
			WHEN 0 THEN 'OSVolume'
			WHEN 1 THEN 'FixedDataVolume'
			WHEN 2 THEN 'PortableDataVolume'
			WHEN 3 THEN 'VirtualDataVolume'
        END
    )
    , DeviceID                          =
    (
        SELECT SUBSTRING (
            BitLocker.DeviceID0,
            CHARINDEX ('{', BitLocker.DeviceID0) + LEN ('{'),
            CHARINDEX ('}', BitLocker.DeviceID0) - CHARINDEX ('{', BitLocker.DeviceID0) - LEN ('{')
        )
	)
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
    LEFT JOIN fn_rbac_R_System(@UserSIDs) AS System ON System.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_COMPUTER_SYSTEM(@UserSIDs) AS ComputerSystem ON ComputerSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_COMPUTER_SYSTEM_PRODUCT(@UserSIDs) AS ComputerProduct ON ComputerProduct.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_TPM (@UserSIDs) Tpm on Tpm.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN dbo.v_GS_CUSTOM_ENCRYPTABLE_VOLUME_EXT0 AS BitLocker ON BitLocker.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN dbo.v_GS_CUSTOM_BITLOCKER_POLICY0 AS BitLockerPolicy ON BitLockerPolicy.ResourceID = CollectionMembers.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID
    AND ComputerSystem.Model0 NOT LIKE
        (
            CASE @ExcludeVirtualMachines
                WHEN 'YES' THEN '%Virtual%'
                ELSE ''
            END
        )
GROUP BY
	ComputerSystem.Name0
	, ComputerSystem.Manufacturer0
	, ComputerSystem.Model0
	, System.Build01
	, System.OSBranch01
	, CombinedResources.DeviceOS
	, ComputerProduct.Version0
	, OperatingSystem.Caption0
	, OperatingSystem.Version0
	, OperatingSystem.CSDVersion0
	, TPM.ManufacturerId0
	, TPM.ManufacturerVersion0
	, TPM.PhysicalPresenceVersionInfo0
	, TPM.SpecVersion0
	, BitLocker.ResourceID
	, BitLocker.IsVolumeInitializedForProtec0
	, BitLocker.DriveLetter0
	, BitLocker.ProtectionStatus0
	, BitLocker.ConversionStatus0
	, BitLocker.EncryptionMethod0
	, BitLocker.VolumeType0
	, BitLocker.DeviceID0

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/