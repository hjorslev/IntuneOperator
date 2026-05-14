function Get-IntuneRemediationDeviceStatus {
    <#
    .SYNOPSIS
    Retrieves per-device run state and pre/post remediation output for a specific Intune proactive remediation.

    .DESCRIPTION
    Queries Microsoft Graph (beta) for the device run states of a proactive remediation script
    (device health script). Returns one row per device, including the detection and remediation
    states and the captured pre/post-remediation detection script output.

    Requires an authenticated Graph session with appropriate scopes.

    Scopes (minimum):
        - DeviceManagementConfiguration.Read.All

    .PARAMETER Name
    The display name of the remediation script. Supports wildcards (*).
    When multiple scripts match, all are processed.
    Parameter set: ByName.

    .PARAMETER Id
    The ID (GUID) of the device health script (remediation) to query.
    Parameter set: ById.

    .PARAMETER ConvertPreRemediationOutput
    Parses PreRemediationOutput as JSON and adds a PreRemediationData property when valid JSON is present.

    .PARAMETER ConvertPostRemediationOutput
    Parses PostRemediationOutput as JSON and adds a PostRemediationData property when valid JSON is present.

    .EXAMPLE
    Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All"
    Get-IntuneRemediationDeviceStatus -Name "BitLocker*"

    Returns per-device run states for all remediations whose name starts with "BitLocker".

    .EXAMPLE
    Get-IntuneRemediationDeviceStatus -Id "f1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a"

    Returns per-device run states for the remediation with the specified ID.

    .EXAMPLE
    Get-IntuneRemediationSummary | Where-Object WithIssues -gt 0 | Get-IntuneRemediationDeviceStatus

    Pipes remediations that have devices with issues into this cmdlet to get device-level detail.

    .EXAMPLE
    Get-IntuneRemediationDeviceStatus -Name 'Win | Device | All | Detection | Secure Boot Status' -ConvertPreRemediationOutput |
        Where-Object { $null -ne $_.PreRemediationData }

    Parses valid JSON found in PreRemediationOutput and exposes it as PreRemediationData.

    .EXAMPLE
    Get-IntuneRemediationDeviceStatus -Name 'Win | Device | All | Detection | Secure Boot Status' -ConvertPreRemediationOutput -ConvertPostRemediationOutput |
        Select-Object DeviceName, DetectionState, RemediationState, PreRemediationData, PostRemediationData

    Parses valid JSON from both remediation output fields and selects the parsed data alongside device state.

    .INPUTS
    System.String (Name or Id via pipeline by property name)

    .OUTPUTS
    PSCustomObject with the following properties
    - RemediationName (string)         : Display name of the remediation script
    - RemediationId (string)           : GUID of the device health script
    - DeviceId (string)                : Managed device ID
    - DeviceName (string)              : Managed device display name
    - UserPrincipalName (string)       : Primary user UPN of the device
    - LastStateUpdate (datetime / null): When the run state was last updated
    - DetectionState (string)          : Outcome of the last detection script run
    - RemediationState (string)        : Outcome of the last remediation script run
    - PreRemediationOutput (string)    : stdout captured before remediation ran
    - PostRemediationOutput (string)   : stdout captured after remediation ran
    - PreRemediationData (object/null) : Parsed JSON from PreRemediationOutput when -ConvertPreRemediationOutput is used
    - PostRemediationData (object/null): Parsed JSON from PostRemediationOutput when -ConvertPostRemediationOutput is used
    - DetectionOutput (string)         : Detection-only script stdout
    - PreRemediationError (string)     : stderr captured before remediation ran
    - RemediationError (string)        : stderr from the remediation script
    - DetectionError (string)          : stderr from the detection script

    .NOTES
    Author: FHN & GitHub Copilot
    - Uses /beta Graph endpoints.
    - Expands managedDevice to include DeviceName and UserPrincipalName inline.
    #>

    [OutputType([PSCustomObject])]
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess = $false)]
    param(
        [Parameter(
            ParameterSetName = 'ByName',
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'Display name (supports wildcards) of the remediation script'
        )]
        [ValidateNotNullOrEmpty()]
        [Alias('RemediationName')]
        [string]$Name,

        [Parameter(
            ParameterSetName = 'ById',
            Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'GUID of the device health / remediation script'
        )]
        [ValidatePattern('^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$')]
        [Alias('RemediationId')]
        [string]$Id,

        [Parameter(HelpMessage = 'Parse pre-remediation output as JSON and add PreRemediationData')]
        [switch]$ConvertPreRemediationOutput,

        [Parameter(HelpMessage = 'Parse post-remediation output as JSON and add PostRemediationData')]
        [switch]$ConvertPostRemediationOutput
    )

    begin {
        # Expand managedDevice so device identity fields are available in each run-state row.
        $expandQuery = '$expand=managedDevice($select=id,deviceName,userPrincipalName)'
    }

    process {
        # ------------------------------------------------------------------ #
        # 1. Resolve the target script(s) when called by name                #
        # ------------------------------------------------------------------ #
        $targetScripts = @()

        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            $targetScripts += [PSCustomObject]@{
                id          = $Id
                displayName = $Id   # will be overwritten once we fetch the real name
            }

            # Resolve display name for friendlier output while still accepting direct ID input.
            try {
                $scriptDetailUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($Id)?`$select=id,displayName"
                $scriptDetail = Invoke-GraphGet -Uri $scriptDetailUri
                if ($null -ne $scriptDetail -and -not [string]::IsNullOrWhiteSpace($scriptDetail.displayName)) {
                    $targetScripts[0] = [PSCustomObject]@{
                        id          = $Id
                        displayName = [string]$scriptDetail.displayName
                    }
                }
            } catch {
                Write-Warning -Message "Could not fetch display name for remediation '$Id': $($_.Exception.Message)"
            }
        } else {
            # ByName – list all scripts then filter
            $listUri = 'https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts?$select=id,displayName'
            try {
                $listResponse = Invoke-GraphGet -Uri $listUri
            } catch {
                if ($_.FullyQualifiedErrorId -match 'GraphRequestFailed' -and $_.Exception.Message -match 'Forbidden|403') {
                    $Exception = [Exception]::new("Failed to list proactive remediations: access denied. Ensure your account has an Intune role with permission to read Device configurations, then reconnect and try again. Original error: $($_.Exception.Message)", $_.Exception)
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                        $Exception,
                        'RemediationListAccessDenied',
                        [System.Management.Automation.ErrorCategory]::PermissionDenied,
                        $listUri
                    )
                    $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                }

                $Exception = [Exception]::new("Failed to list proactive remediations: $($_.Exception.Message)", $_.Exception)
                $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $Exception,
                    'RemediationListFailed',
                    [System.Management.Automation.ErrorCategory]::NotSpecified,
                    $listUri
                )
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            # Normalize payload shape before wildcard name matching.
            $allScripts = @()
            if ($null -ne $listResponse) {
                if ($null -ne $listResponse.value) {
                    $allScripts = @($listResponse.value)
                } else {
                    $allScripts = @($listResponse)
                }
            }

            $targetScripts = @($allScripts | Where-Object { $_.displayName -like $Name })

            if ($targetScripts.Count -eq 0) {
                $Exception = [Exception]::new("No remediation script found matching name '$Name'.")
                $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $Exception,
                    'RemediationNotFound',
                    [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                    $Name
                )
                $PSCmdlet.WriteError($ErrorRecord)
                return
            }
        }

        # ------------------------------------------------------------------ #
        # 2. For each matched script, retrieve per-device run states         #
        # ------------------------------------------------------------------ #
        foreach ($script in $targetScripts) {
            $remediationName = [string]$script.displayName
            $remediationId = [string]$script.id

            Write-Verbose -Message "Retrieving device run states for remediation '$remediationName' ($remediationId)"

            $runStatesUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$remediationId/deviceRunStates?$expandQuery"

            try {
                $runStatesResponse = Invoke-GraphGet -Uri $runStatesUri
            } catch {
                Write-Warning -Message "Failed to retrieve device run states for '$remediationName' ($remediationId): $($_.Exception.Message)"
                continue
            }

            # Normalize run-state list: handle both .value and direct response shapes.
            $runStates = @()
            if ($null -ne $runStatesResponse) {
                if ($null -ne $runStatesResponse.value) {
                    $runStates = @($runStatesResponse.value)
                } else {
                    $runStates = @($runStatesResponse)
                }
            }

            if ($runStates.Count -eq 0) {
                Write-Verbose -Message "No device run states found for '$remediationName'."
                continue
            }

            foreach ($state in $runStates) {
                # Resolve device fields from the expanded managedDevice object
                $device = $null
                $deviceId = $null
                $deviceName = $null
                $upn = $null

                if ($null -ne $state.managedDevice) {
                    $device = $state.managedDevice
                    $deviceId = [string]$device.id
                    $deviceName = [string]$device.deviceName
                    $upn = [string]$device.userPrincipalName
                }

                # Resolve last-state timestamp
                $lastUpdate = $null
                $rawDate = $state.lastStateUpdateDateTime
                if ($null -ne $rawDate -and -not [string]::IsNullOrWhiteSpace([string]$rawDate)) {
                    # Guard output typing: invalid timestamps should not break object emission.
                    try {
                        $lastUpdate = [datetime]$rawDate
                    } catch {
                        $lastUpdate = $null
                    }
                }

                # Capture the raw script output once so optional JSON parsing stays local.
                $preRemediationOutput = [string]$state.preRemediationDetectionScriptOutput
                $postRemediationOutput = [string]$state.postRemediationDetectionScriptOutput

                # Build the output object in-order and extend it only when JSON parsing is requested.
                $outputObject = [ordered]@{
                    RemediationName       = $remediationName
                    RemediationId         = $remediationId
                    DeviceId              = $deviceId
                    DeviceName            = $deviceName
                    UserPrincipalName     = $upn
                    LastStateUpdate       = $lastUpdate
                    DetectionState        = [string]$state.detectionState
                    RemediationState      = [string]$state.remediationState
                    PreRemediationOutput  = $preRemediationOutput
                    PostRemediationOutput = $postRemediationOutput
                    DetectionOutput       = [string]$state.detectionScriptOutput
                    PreRemediationError   = [string]$state.preRemediationDetectionScriptError
                    RemediationError      = [string]$state.remediationScriptError
                    DetectionError        = [string]$state.detectionScriptError
                }

                if ($ConvertPreRemediationOutput.IsPresent) {
                    $outputObject.PreRemediationData = $null
                    if (-not [string]::IsNullOrWhiteSpace($preRemediationOutput) -and $preRemediationOutput.Trim().StartsWith('{')) {
                        try {
                            $outputObject.PreRemediationData = $preRemediationOutput | ConvertFrom-Json -ErrorAction Stop
                        } catch {
                            Write-Verbose -Message "Failed to parse pre-remediation JSON for device '$deviceName'."
                        }
                    }
                }

                if ($ConvertPostRemediationOutput.IsPresent) {
                    $outputObject.PostRemediationData = $null
                    if (-not [string]::IsNullOrWhiteSpace($postRemediationOutput) -and $postRemediationOutput.Trim().StartsWith('{')) {
                        try {
                            $outputObject.PostRemediationData = $postRemediationOutput | ConvertFrom-Json -ErrorAction Stop
                        } catch {
                            Write-Verbose -Message "Failed to parse post-remediation JSON for device '$deviceName'."
                        }
                    }
                }

                # Cast Graph fields to predictable output types for downstream filtering/export.
                [PSCustomObject]$outputObject
            }
        }
    } # Process
} # Cmdlet
