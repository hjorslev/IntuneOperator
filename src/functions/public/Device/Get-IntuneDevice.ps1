#Requires -Modules @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.28.0' }

function Get-IntuneDevice {
    <#
    .SYNOPSIS
    Retrieves Intune managed device details by DeviceId or DeviceName.

    .DESCRIPTION
    Queries Microsoft Graph (beta) for managed device details and returns a compact device summary.
    Supports lookup by managed device ID or by device name.

    Requires an authenticated Graph session with appropriate scopes.

    Scopes (minimum):
        - DeviceManagementManagedDevices.Read.All

    .PARAMETER DeviceId
    The Intune managed device identifier (GUID). Parameter set: ById.

    .PARAMETER DeviceName
    The device name to resolve in Intune managed devices. Parameter set: ByName.
    If multiple devices share the same name, all matches are returned.

    .EXAMPLE
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All","User.Read.All"
    Get-IntuneDevice -DeviceId "c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a"

    Retrieves summary details for the specified managed device.

    .EXAMPLE
    Get-IntuneDevice -DeviceName PC-001

    Resolves device by name and returns summary details for each matching managed device.

    .INPUTS
    System.String (DeviceId or DeviceName via pipeline/property name)

    .OUTPUTS
    PSCustomObject with the following properties
    - DeviceName (string)
    - PrimaryUser (string)
    - DeviceManufacturer (string)
    - DeviceModel (string)
    - OperatingSystem (string)
    - SerialNumber (string)
    - Compliance (string)
    - LastSyncDateTime (datetime)

    .NOTES
    Author: FHN & GitHub Copilot
    Uses /beta Graph endpoints for managed device properties.
    #>

    [OutputType([PSCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'ById', SupportsShouldProcess = $false)]
    param(
        [Parameter(
            ParameterSetName = 'ById',
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidatePattern('^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$')]
        [Alias('Id', 'ManagedDeviceId')]
        [string]$DeviceId,

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

    begin {
        $baseUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'
        # Request only fields needed for enrichment + output mapping.
        $select = 'deviceName,userPrincipalName,manufacturer,model,operatingSystem,serialNumber,complianceState,lastSyncDateTime'
    }

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                Write-Verbose -Message "Resolving managed device by id: $DeviceId"
                $uri = "$baseUri/$DeviceId?`$select=$select"
                try {
                    $device = Invoke-GraphGet -Uri $uri
                } catch {
                    $errorMessage = $_.Exception.Message
                    # Distinguish 404 (not found) from network/auth failures.
                    if ($errorMessage -match 'Request_ResourceNotFound|NotFound|404') {
                        $exception = [Exception]::new("Managed device not found for id '$DeviceId': $errorMessage", $_.Exception)
                        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $exception,
                            'DeviceNotFound',
                            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                            $DeviceId
                        )
                        $PSCmdlet.WriteError($errorRecord)
                        return
                    }

                    $exception = [Exception]::new("Failed to resolve device id '$DeviceId': $errorMessage", $_.Exception)
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $exception,
                        'DeviceLookupFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        $DeviceId
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }

                # Graph returned null; invalid or removed device.
                if (-not $device) {
                    $exception = [Exception]::new("Managed device not found for id '$DeviceId'.")
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $exception,
                        'DeviceNotFound',
                        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                        $DeviceId
                    )
                    $PSCmdlet.WriteError($errorRecord)
                    return
                }

                # Map to public output contract.
                ConvertTo-IntuneDeviceSummary -Device $device
            }

            'ByName' {
                Write-Verbose -Message "Resolving managed device(s) by name: $DeviceName"

                try {
                    $deviceSummaries = Resolve-IntuneDeviceByName -Name $DeviceName
                } catch {
                    $errorMessage = $_.Exception.Message
                    # Distinguish name resolution failure (no match) from actual Graph errors.
                    if ($errorMessage -match 'Request_ResourceNotFound|NotFound|404') {
                        $exception = [Exception]::new("Managed device not found for name '$DeviceName': $errorMessage", $_.Exception)
                        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $exception,
                            'DeviceNameNotFound',
                            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                            $DeviceName
                        )
                        $PSCmdlet.WriteError($errorRecord)
                        return
                    }

                    $exception = [Exception]::new("Failed to resolve device name '$DeviceName': $errorMessage", $_.Exception)
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $exception,
                        'DeviceNameLookupFailed',
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        $DeviceName
                    )
                    $PSCmdlet.ThrowTerminatingError($errorRecord)
                }

                # Empty result set: name does not match any device.
                if ($null -eq $deviceSummaries -or $deviceSummaries.Count -eq 0) {
                    $exception = [Exception]::new("Managed device not found for name '$DeviceName'.")
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $exception,
                        'DeviceNameNotFound',
                        [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                        $DeviceName
                    )
                    $PSCmdlet.WriteError($errorRecord)
                    return
                }

                # Resolve-IntuneDeviceByName already returns selected managed device fields.
                foreach ($device in $deviceSummaries) {
                    if (-not $device) {
                        continue
                    }

                    # Map to public output contract.
                    ConvertTo-IntuneDeviceSummary -Device $device
                }
            }
        }
    } # Process
} # Cmdlet
