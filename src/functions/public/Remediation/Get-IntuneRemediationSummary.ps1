function Get-IntuneRemediationSummary {
    <#
    .SYNOPSIS
    Retrieves remediation summary statistics for all Intune proactive remediations.

    .DESCRIPTION
    Queries Microsoft Graph (beta) for all device health scripts (proactive remediations)
    and returns one summary row per remediation, including status and key issue counters.

    Requires an authenticated Graph session with appropriate scopes.

    Scopes (minimum):
        - DeviceManagementConfiguration.Read.All

    .EXAMPLE
    Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All"
    Get-IntuneRemediationSummary

    Returns one row per remediation with status and issue/remediation counters.

    .OUTPUTS
    PSCustomObject with the following properties
    - Name (string)
    - Status (string)
    - WithoutIssues (int)
    - WithIssues (int)
    - IssueFixed (int)
    - IssueRecurred (int)
    - TotalRemediated (int)

    .NOTES
    Author: FHN & GitHub Copilot
    - Uses /beta Graph endpoints.
    #>

    [OutputType([PSCustomObject])]
    [CmdletBinding(SupportsShouldProcess = $false)]
    param()

    begin {
        $listUri = 'https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts?$select=id,displayName'
    }

    process {
        Write-Verbose -Message 'Retrieving proactive remediations from Microsoft Graph'

        try {
            $scriptsResponse = Invoke-GraphGet -Uri $listUri
        } catch {
            if ($_.FullyQualifiedErrorId -match 'GraphRequestFailed' -and $_.Exception.Message -match 'Forbidden|403') {
                $Exception = [Exception]::new("Failed to retrieve proactive remediations: access denied by Intune RBAC or tenant policy. Ensure your account has an Intune role with permission to read Device configurations (Endpoint Analytics/Remediations), then reconnect and try again. Original error: $($_.Exception.Message)", $_.Exception)
                $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $Exception,
                    'RemediationListAccessDenied',
                    [System.Management.Automation.ErrorCategory]::PermissionDenied,
                    $listUri
                )
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            $Exception = [Exception]::new("Failed to retrieve proactive remediations: $($_.Exception.Message)", $_.Exception)
            $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                $Exception,
                'RemediationListFailed',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $listUri
            )
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        $scripts = @()
        if ($null -ne $scriptsResponse) {
            if ($null -ne $scriptsResponse.value) {
                $scripts = @($scriptsResponse.value)
            } else {
                $scripts = @($scriptsResponse)
            }
        }

        foreach ($script in $scripts) {
            if ($null -eq $script.id) {
                continue
            }

            $scriptName = [string]$script.displayName
            if ([string]::IsNullOrWhiteSpace($scriptName)) {
                $scriptName = [string](Get-FirstPropertyValue -InputObject $script -PropertyNames @('displayName', 'name') -DefaultValue $script.id)
            }

            Write-Verbose -Message "Processing remediation summary for '$scriptName'"

            $summaryUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($script.id)/runSummary"
            try {
                $summaryResponse = Invoke-GraphGet -Uri $summaryUri
            } catch {
                Write-Warning -Message "Failed to retrieve run summary for '$scriptName' ($($script.id)): $($_.Exception.Message)"
                continue
            }

            $summary = $summaryResponse
            if ($null -ne $summaryResponse.value) {
                if ($summaryResponse.value -is [array]) {
                    $summary = $summaryResponse.value | Select-Object -First 1
                } else {
                    $summary = $summaryResponse.value
                }
            }

            if ($null -eq $summary) {
                $summary = $summaryResponse
            }

            # Some tenants return nested shapes for run summary payloads.
            # Resolve to the first object that actually contains known summary counters.
            $summaryCandidates = @()
            if ($null -ne $summary) {
                $summaryCandidates += $summary
                if ($null -ne $summary.runSummary) {
                    $summaryCandidates += $summary.runSummary
                }
            }
            if ($null -ne $summaryResponse) {
                $summaryCandidates += $summaryResponse
                if ($null -ne $summaryResponse.runSummary) {
                    $summaryCandidates += $summaryResponse.runSummary
                }
                if ($null -ne $summaryResponse.value -and $null -ne $summaryResponse.value.runSummary) {
                    $summaryCandidates += $summaryResponse.value.runSummary
                }
            }
            if ($null -ne $summary.value) {
                $summaryCandidates += $summary.value
                if ($null -ne $summary.value.runSummary) {
                    $summaryCandidates += $summary.value.runSummary
                }
            }

            $resolvedSummary = $null
            foreach ($candidate in $summaryCandidates) {
                if ($null -eq $candidate) {
                    continue
                }

                $candidateNoIssue = Get-FirstPropertyValue -InputObject $candidate -PropertyNames @(
                    'noIssueDetectedDeviceCount', 'withoutIssues', 'noIssueCount', 'noIssueDeviceCount', 'devicesWithoutIssues'
                ) -DefaultValue $null
                $candidateWithIssue = Get-FirstPropertyValue -InputObject $candidate -PropertyNames @(
                    'issueDetectedDeviceCount', 'withIssues', 'issueCount', 'issueDeviceCount', 'devicesWithIssues'
                ) -DefaultValue $null
                $candidateFixed = Get-FirstPropertyValue -InputObject $candidate -PropertyNames @(
                    'issueRemediatedDeviceCount', 'issueFixed', 'issueFixedCount', 'issuesFixed', 'issueRemediatedCount'
                ) -DefaultValue $null
                $candidateRecurred = Get-FirstPropertyValue -InputObject $candidate -PropertyNames @(
                    'issueReoccurredDeviceCount', 'issueRecurred', 'issueRecurredCount', 'recurredIssueCount', 'issueRecurredDevicesCount'
                ) -DefaultValue $null
                $candidateTotalRemediated = Get-FirstPropertyValue -InputObject $candidate -PropertyNames @(
                    'issueRemediatedCumulativeDeviceCount', 'totalRemediated', 'remediatedCount', 'remediatedDeviceCount', 'devicesRemediated'
                ) -DefaultValue $null

                if ($null -ne $candidateNoIssue -or $null -ne $candidateWithIssue -or $null -ne $candidateFixed -or $null -ne $candidateRecurred -or $null -ne $candidateTotalRemediated) {
                    $resolvedSummary = $candidate
                    break
                }
            }

            if ($null -ne $resolvedSummary) {
                $summary = $resolvedSummary
            }

            $status = Get-FirstPropertyValue -InputObject $script -PropertyNames @(
                'status'
            ) -DefaultValue $null

            if ([string]::IsNullOrWhiteSpace([string]$status)) {
                $status = Get-FirstPropertyValue -InputObject $summary -PropertyNames @(
                    'status',
                    'remediationStatus',
                    'scriptExecutionStatus'
                ) -DefaultValue $null
            }

            $withoutIssues = [int](Get-FirstPropertyValue -InputObject $summary -PropertyNames @(
                    'noIssueDetectedDeviceCount', 'withoutIssues', 'noIssueCount', 'noIssueDeviceCount', 'devicesWithoutIssues'
                ) -DefaultValue 0)
            $withIssues = [int](Get-FirstPropertyValue -InputObject $summary -PropertyNames @(
                    'issueDetectedDeviceCount', 'withIssues', 'issueCount', 'issueDeviceCount', 'devicesWithIssues'
                ) -DefaultValue 0)
            $issueFixed = [int](Get-FirstPropertyValue -InputObject $summary -PropertyNames @(
                    'issueRemediatedDeviceCount', 'issueFixed', 'issueFixedCount', 'issuesFixed', 'issueRemediatedCount'
                ) -DefaultValue 0)
            $issueRecurred = [int](Get-FirstPropertyValue -InputObject $summary -PropertyNames @(
                    'issueReoccurredDeviceCount', 'issueRecurred', 'issueRecurredCount', 'recurredIssueCount', 'issueRecurredDevicesCount'
                ) -DefaultValue 0)
            $totalRemediated = [int](Get-FirstPropertyValue -InputObject $summary -PropertyNames @(
                    'issueRemediatedCumulativeDeviceCount', 'totalRemediated', 'remediatedCount', 'remediatedDeviceCount', 'devicesRemediated'
                ) -DefaultValue 0)

            if ($withoutIssues -eq 0 -and $withIssues -eq 0 -and $issueFixed -eq 0 -and $issueRecurred -eq 0 -and $totalRemediated -eq 0) {
                $historyUri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($script.id)/getRemediationHistory"
                try {
                    $historyResponse = Invoke-GraphGet -Uri $historyUri

                    $historyRoot = $historyResponse
                    if ($null -ne $historyResponse.value) {
                        $historyRoot = $historyResponse.value
                    }

                    $historyData = @()
                    if ($null -ne $historyRoot.historyData) {
                        $historyData = @($historyRoot.historyData)
                    } elseif ($historyRoot -is [array]) {
                        $historyData = @($historyRoot)
                    } elseif ($null -ne $historyRoot.date) {
                        $historyData = @($historyRoot)
                    }

                    $latestHistory = $null
                    if ($historyData.Count -gt 0) {
                        $latestHistory = $historyData |
                            Sort-Object -Property date -Descending |
                            Select-Object -First 1
                    }

                    if ($null -ne $latestHistory) {
                        $historyNoIssue = [int](Get-FirstPropertyValue -InputObject $latestHistory -PropertyNames @('noIssueDeviceCount', 'noIssueCount', 'withoutIssues') -DefaultValue 0)
                        $historyDetectFailed = [int](Get-FirstPropertyValue -InputObject $latestHistory -PropertyNames @('detectFailedDeviceCount', 'issueDetectedDeviceCount', 'issueCount', 'withIssues') -DefaultValue 0)
                        $historyRemediated = [int](Get-FirstPropertyValue -InputObject $latestHistory -PropertyNames @('remediatedDeviceCount', 'issueRemediatedDeviceCount', 'issueFixedCount', 'issueFixed') -DefaultValue 0)

                        if ($historyNoIssue -eq 0 -and $historyDetectFailed -eq 0 -and $historyRemediated -eq 0 -and $historyData.Count -gt 0) {
                            $historyNoIssue = ($historyData | ForEach-Object {
                                    [int](Get-FirstPropertyValue -InputObject $_ -PropertyNames @('noIssueDeviceCount', 'noIssueCount', 'withoutIssues') -DefaultValue 0)
                                } | Measure-Object -Maximum).Maximum

                            $historyDetectFailed = ($historyData | ForEach-Object {
                                    [int](Get-FirstPropertyValue -InputObject $_ -PropertyNames @('detectFailedDeviceCount', 'issueDetectedDeviceCount', 'issueCount', 'withIssues') -DefaultValue 0)
                                } | Measure-Object -Maximum).Maximum

                            $historyRemediated = ($historyData | ForEach-Object {
                                    [int](Get-FirstPropertyValue -InputObject $_ -PropertyNames @('remediatedDeviceCount', 'issueRemediatedDeviceCount', 'issueFixedCount', 'issueFixed') -DefaultValue 0)
                                } | Measure-Object -Sum).Sum
                        }

                        $withoutIssues = $historyNoIssue
                        $issueFixed = $historyRemediated
                        if ($totalRemediated -eq 0) {
                            $totalRemediated = $historyRemediated
                        }
                        if ($withIssues -eq 0) {
                            $withIssues = $historyRemediated + $historyDetectFailed
                        }
                    }

                    if ($null -ne $historyRoot.lastModifiedDateTime -and [string]::IsNullOrWhiteSpace([string]$status)) {
                        $status = 'Completed'
                    }
                } catch {
                    Write-Verbose -Message "No remediation history fallback available for '$scriptName' ($($script.id)): $($_.Exception.Message)"
                }
            }

            if ([string]::IsNullOrWhiteSpace([string]$status)) {
                $pendingCount = [int](Get-FirstPropertyValue -InputObject $summary -PropertyNames @(
                        'detectionScriptPendingDeviceCount'
                    ) -DefaultValue 0)
                $lastRun = Get-FirstPropertyValue -InputObject $summary -PropertyNames @(
                    'lastScriptRunDateTime'
                ) -DefaultValue $null

                if ($pendingCount -gt 0) {
                    $status = 'Pending'
                } elseif ($null -ne $lastRun -and -not [string]::IsNullOrWhiteSpace([string]$lastRun)) {
                    $status = 'Completed'
                } else {
                    $status = 'Unknown'
                }
            }

            [PSCustomObject]@{
                Name            = [string]$scriptName
                Status          = [string]$status
                WithoutIssues   = $withoutIssues
                WithIssues      = $withIssues
                IssueFixed      = $issueFixed
                IssueRecurred   = $issueRecurred
                TotalRemediated = $totalRemediated
            }
        }
    } # Process
} # Cmdlet
