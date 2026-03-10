function Get-IntuneDeviceLogin {
    <#
    .SYNOPSIS
    Retrieves logged-on user info for an Intune-managed device by DeviceId, DeviceName, UserPrincipalName, or UserId.

    .DESCRIPTION
    Uses Microsoft Graph (beta) to read managed device metadata and the `usersLoggedOn` collection.
    When given a DeviceId, queries that specific device. When given a DeviceName, resolves one or more
    matching managed devices (`deviceName eq '<name>'`) and returns logon info for each match.
    When given a UserPrincipalName or UserId, searches all managed devices and returns only those where
    the specified user has logged in.

    Requires an authenticated Graph session with appropriate scopes.

    Scopes (minimum):
        - DeviceManagementManagedDevices.Read.All
        - User.Read.All

    .PARAMETER DeviceId
    The Intune managed device identifier (GUID). Parameter set: ById.

    .PARAMETER DeviceName
    The device name to resolve in Intune managed devices. Parameter set: ByName.
    If multiple devices share the same name, all matches are processed.

    .PARAMETER UserPrincipalName
    The user principal name (UPN) to search for across all managed devices. Parameter set: ByUserPrincipalName.
    Returns all devices where this user has logged in.

    .PARAMETER UserId
    The Entra ID user object identifier (GUID). Parameter set: ByUserId.
    Returns all devices where this user has logged in.

    .EXAMPLE
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All","User.Read.All"
    Get-IntuneDeviceLogin -DeviceId "c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a"

    Gets logged-on user info for the specified device.

    .EXAMPLE
    Get-IntuneDeviceLogin -DeviceName PC-001

    Resolves the device name and returns logged-on user info for the match.

    .EXAMPLE
    Get-IntuneDeviceLogin -UserPrincipalName "john.doe@contoso.com"

    Returns all devices where john.doe@contoso.com has logged in.

    .EXAMPLE
    Get-IntuneDeviceLogin -UserId "c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a"

    Returns all devices where the specified user (by ID) has logged in.

    .INPUTS
    System.String (DeviceId, DeviceName, UserPrincipalName, or UserId via pipeline/property name)

    .OUTPUTS
    PSCustomObject with the following properties
    - DeviceId (string)
    - DeviceName (string)
    - UserId (string)
    - UserPrincipalName (string)
    - LastLogonDateTime (datetime)

    .NOTES
    Author: FHN & ChatGPT & GitHub Copilot
    - Uses /beta Graph endpoints because usersLoggedOn is exposed there.
    #>

    [OutputType([PSCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'ById', SupportsShouldProcess = $false)]
    param(
        # ById: DeviceId (GUID)
        [Parameter(
            ParameterSetName = 'ById',
            Mandatory = $true,
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
        [string]$DeviceName,

        # ByUserPrincipalName: UserPrincipalName (string)
        [Parameter(
            ParameterSetName = 'ByUserPrincipalName',
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('UPN')]
        [string]$UserPrincipalName,

        # ByUserId: UserId (GUID)
        [Parameter(
            ParameterSetName = 'ByUserId',
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidatePattern('^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$')]
        [string]$UserId
    )

    begin {
        $baseUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'
    }

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                Write-Verbose -Message "Resolving usersLoggedOn for device id: $DeviceId"
                $uri = "$baseUri/$DeviceId"
                try {
                    $device = Invoke-GraphGet -Uri $uri
                } catch {
                    $errorMessage = $_.Exception.Message
                    if ($errorMessage -match 'Request_ResourceNotFound|NotFound|404') {
                        $Exception = [Exception]::new("Managed device not found for id '$DeviceId': $errorMessage", $_.Exception)
                        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $Exception,
                            'DeviceNotFound',
                            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                            $DeviceId
                        )
                        $PSCmdlet.WriteError($ErrorRecord)
                        return
                    }

                    $Exception = [Exception]::new("Failed to resolve device id '$DeviceId': $errorMessage", $_.Exception)
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $Exception,
                        'DeviceLookupFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        $DeviceId
                    )
                    $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                }

                if (-not $device) {
                    $Exception = [Exception]::new("Managed device not found for id '$DeviceId'.")
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $Exception,
                        'DeviceNotFound',
                        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                        $DeviceId
                    )
                    $PSCmdlet.WriteError($ErrorRecord)
                    return
                }

                if (-not $device.usersLoggedOn -or $device.usersLoggedOn.Count -eq 0) {
                    Write-Verbose -Message "No logged-on users found for device '$($device.deviceName)' ($DeviceId)."
                    return
                }

                foreach ($entry in $device.usersLoggedOn) {
                    $user = Resolve-EntraUserById -UserId $entry.userId
                    [PSCustomObject]@{
                        DeviceName        = $device.deviceName
                        UserPrincipalName = $user.userPrincipalName
                        DeviceId          = $device.id
                        UserId            = $entry.userId
                        LastLogonDateTime = [datetime]$entry.lastLogOnDateTime
                    }
                }
            }

            'ByName' {
                Write-Verbose -Message "Resolving device(s) by name: $DeviceName"
                try {
                    $deviceSummaries = Resolve-IntuneDeviceByName -Name $DeviceName
                } catch {
                    $errorMessage = $_.Exception.Message
                    if ($errorMessage -match 'Request_ResourceNotFound|NotFound|404') {
                        $Exception = [Exception]::new("Managed device not found for name '$DeviceName': $errorMessage", $_.Exception)
                        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $Exception,
                            'DeviceNameNotFound',
                            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                            $DeviceName
                        )
                        $PSCmdlet.WriteError($ErrorRecord)
                        return
                    }

                    $Exception = [Exception]::new("Failed to resolve device name '$DeviceName': $errorMessage", $_.Exception)
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $Exception,
                        'DeviceNameLookupFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        $DeviceName
                    )
                    $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                }

                if ($null -eq $deviceSummaries -or $deviceSummaries.Count -eq 0) {
                    $Exception = [Exception]::new("Managed device not found for name '$DeviceName'.")
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $Exception,
                        'DeviceNameNotFound',
                        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                        $DeviceName
                    )
                    $PSCmdlet.WriteError($ErrorRecord)
                    return
                }

                if ($deviceSummaries.Count -gt 1) {
                    Write-Verbose -Message "Multiple devices matched name '$DeviceName' ($($deviceSummaries.Count) matches). Returning results for all."
                }

                foreach ($summary in $deviceSummaries) {
                    $uri = "$baseUri/$($summary.Id)"
                    try {
                        $device = Invoke-GraphGet -Uri $uri
                    } catch {
                        $errorMessage = $_.Exception.Message
                        if ($errorMessage -match 'Request_ResourceNotFound|NotFound|404') {
                            $Exception = [Exception]::new("Managed device not found for id '$($summary.Id)' while resolving name '$DeviceName': $errorMessage", $_.Exception)
                            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                                $Exception,
                                'DeviceNotFound',
                                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                                $summary.Id
                            )
                            $PSCmdlet.WriteError($ErrorRecord)
                            continue
                        }

                        $Exception = [Exception]::new("Failed to retrieve device id '$($summary.Id)' while resolving name '$DeviceName': $errorMessage", $_.Exception)
                        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $Exception,
                            'DeviceLookupFailed',
                            [System.Management.Automation.ErrorCategory]::NotSpecified,
                            $summary.Id
                        )
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                    }

                    if (-not $device) {
                        $Exception = [Exception]::new("Managed device not found for id '$($summary.Id)' while resolving name '$DeviceName'.")
                        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $Exception,
                            'DeviceNotFound',
                            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                            $summary.Id
                        )
                        $PSCmdlet.WriteError($ErrorRecord)
                        continue
                    }

                    if (-not $device.usersLoggedOn -or $device.usersLoggedOn.Count -eq 0) {
                        Write-Verbose -Message "No logged-on users found for device '$($summary.DeviceName)' ($($summary.Id))."
                        continue
                    }

                    foreach ($entry in $device.usersLoggedOn) {
                        $user = Resolve-EntraUserById -UserId $entry.userId
                        [PSCustomObject]@{
                            DeviceName        = $device.deviceName
                            UserPrincipalName = $user.userPrincipalName
                            DeviceId          = $device.id
                            UserId            = $entry.userId
                            LastLogonDateTime = [datetime]$entry.lastLogOnDateTime
                        }
                    }
                }
            }

            { $_ -in 'ByUserPrincipalName', 'ByUserId' } {
                # Resolve UPN to UserId if needed
                if ($PSCmdlet.ParameterSetName -eq 'ByUserPrincipalName') {
                    Write-Verbose -Message "Resolving UserPrincipalName '$UserPrincipalName' to UserId"
                    $userUri = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName"
                    try {
                        $userObj = Invoke-GraphGet -Uri $userUri
                        $targetUserId = $userObj.id
                        Write-Verbose -Message "Resolved to UserId: $targetUserId"
                    } catch {
                        $errorMessage = $_.Exception.Message
                        if ($errorMessage -match 'Request_ResourceNotFound|NotFound|404') {
                            $Exception = [Exception]::new("Could not resolve UserPrincipalName '$UserPrincipalName': $errorMessage", $_.Exception)
                            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                                $Exception,
                                'UserResolutionFailed',
                                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                                $UserPrincipalName
                            )
                            $PSCmdlet.WriteError($ErrorRecord)
                            return
                        }

                        $Exception = [Exception]::new("Failed to resolve UserPrincipalName '$UserPrincipalName': $errorMessage", $_.Exception)
                        $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $Exception,
                            'UserResolutionGraphRequestFailed',
                            [System.Management.Automation.ErrorCategory]::NotSpecified,
                            $UserPrincipalName
                        )
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                    }
                } else {
                    $targetUserId = $UserId
                }

                Write-Verbose -Message "Searching for devices where user '$targetUserId' has logged in"

                # Get all managed devices with usersLoggedOn property
                # Note: Graph API may not support filtering on usersLoggedOn collection, so we retrieve all and filter client-side
                # Invoke-GraphGet automatically handles pagination
                $uri = "$baseUri`?`$select=id,deviceName,usersLoggedOn"
                $resp = Invoke-GraphGet -Uri $uri

                if ($null -eq $resp.value -or $resp.value.Count -eq 0) {
                    Write-Verbose -Message "No managed devices found."
                    return
                }

                Write-Verbose -Message "Checking $($resp.value.Count) managed devices for user logons"

                $matchCount = 0
                foreach ($device in $resp.value) {
                    # Check if target user is in the usersLoggedOn collection
                    $userLogon = $device.usersLoggedOn | Where-Object -FilterScript { $_.userId -eq $targetUserId }
                    if ($userLogon) {
                        $matchCount++
                        $user = Resolve-EntraUserById -UserId $targetUserId
                        [PSCustomObject]@{
                            DeviceName        = $device.deviceName
                            UserPrincipalName = $user.userPrincipalName
                            DeviceId          = $device.id
                            UserId            = $targetUserId
                            LastLogonDateTime = [datetime]$userLogon.lastLogOnDateTime
                        }
                    }
                }

                if ($matchCount -eq 0) {
                    Write-Verbose -Message "No devices found where user '$targetUserId' has logged in."
                }
            }
        }
    } # Process
} # Cmdlet
