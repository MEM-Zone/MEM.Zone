[Flags()]Enum CoManagementWorkloads {
    ConfiguredNoWorkloads    = 8193
    CompliancePolicies       = 2
    ResourceAccessPolicies   = 4
    DeviceConfiguration      = 8
    WindowsUpdatesPolicies   = 16
    EndpointProtection       = 4128
    ClientApps               = 64
    OfficeClicktoRunApps     = 128
}

[CoManagementWorkloads]$CoManagementWorkloads = ''