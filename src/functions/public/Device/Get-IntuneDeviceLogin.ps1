function Get-IntuneDeviceLogin {
    <#
    .SYNOPSIS
    Retrieves logged-on user info for an Intune-managed device by DeviceId (GUID) or device name.

    .DESCRIPTION
    Uses Microsoft Graph (beta) to read managed device metadata and the `usersLoggedOn` collection.
    When given a DeviceId, queries that specific device. When given a DeviceName, resolves one or more
    matching managed devices (`deviceName eq '<name>'`) and returns logon info for each match.

    Requires an authenticated Graph session with appropriate scopes.

    Scopes (minimum):
        - DeviceManagementManagedDevices.Read.All
        - User.Read.All

    .PARAMETER DeviceId
    The Intune managed device identifier (GUID). Parameter set: ById.

    .PARAMETER DeviceName
    The device name to resolve in Intune managed devices. Parameter set: ByName.
    If multiple devices share the same name, all matches are processed.

    .EXAMPLE
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All","User.Read.All"
    Get-IntuneDeviceLogin -DeviceId "c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a"

    Gets logged-on user info for the specified device.

    .EXAMPLE
    Get-IntuneDeviceLogin -DeviceName PC-001

    Resolves the device name and returns logged-on user info for the match.

    .INPUTS
    System.String (DeviceId via -DeviceId, or DeviceName via -DeviceName with ValueFromPipeline/PropertyName)

    .OUTPUTS
    PSCustomObject with the following properties:
    - DeviceId (string)
    - DeviceName (string)
    - UserId (string)
    - UserPrincipalName (string)
    - LastLogonDateTime (datetime)

    .NOTES
    Author: fhn.it & ChatGPT
    - Uses /beta Graph endpoints because usersLoggedOn is exposed there.
    - Emits no output if no users are logged on for a device.
    - Errors are terminating for request/HTTP failures; use try/catch around calls if desired.
    #>

    [OutputType([PSCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'ById', SupportsShouldProcess = $false)]
    param(
        # ById: DeviceId (GUID)
        [Parameter(
            ParameterSetName = 'ById',
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidatePattern('^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$')]
        [Alias('Id', 'ManagedDeviceId')]
        [string]$DeviceId,

        # ByName: DeviceName (string)
        [Parameter(
            ParameterSetName = 'ByName',
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('Name', 'ComputerName')]
        [string]$DeviceName
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                Write-Verbose "Resolving usersLoggedOn for device id: $DeviceId"
                $device = Get-UsersLoggedOnForDevice -Id $DeviceId

                if (-not $device) {
                    Write-Verbose "Managed device not found for id '$DeviceId'."
                    return
                }

                if (-not $device.usersLoggedOn -or $device.usersLoggedOn.Count -eq 0) {
                    Write-Verbose "No logged-on users found for device '$($device.deviceName)' ($DeviceId)."
                    return
                }

                foreach ($entry in $device.usersLoggedOn) {
                    $user = Resolve-EntraUserById -UserId $entry.userId
                    [PSCustomObject]@{
                        DeviceId          = $device.id
                        DeviceName        = $device.deviceName
                        UserId            = $entry.userId
                        UserPrincipalName = $user.userPrincipalName
                        LastLogonDateTime = [datetime]$entry.lastLogOnDateTime
                    }
                }
            }

            'ByName' {
                Write-Verbose "Resolving device(s) by name: $DeviceName"
                $devices = Resolve-IntuneDeviceByName -Name $DeviceName

                if ($devices.Count -gt 1) {
                    Write-Verbose "Multiple devices matched name '$DeviceName' ($($devices.Count) matches). Returning results for all."
                }

                foreach ($dev in $devices) {
                    if (-not $dev.usersLoggedOn -or $dev.usersLoggedOn.Count -eq 0) {
                        Write-Verbose "No logged-on users found for device '$($dev.deviceName)' ($($dev.id))."
                        continue
                    }

                    foreach ($entry in $dev.usersLoggedOn) {
                        $user = Resolve-EntraUserById -UserId $entry.userId
                        [PSCustomObject]@{
                            DeviceId          = $dev.id
                            DeviceName        = $dev.deviceName
                            UserId            = $entry.userId
                            UserPrincipalName = $user.userPrincipalName
                            LastLogonDateTime = [datetime]$entry.lastLogOnDateTime
                        }
                    }
                }
            }
        }
    }
}
