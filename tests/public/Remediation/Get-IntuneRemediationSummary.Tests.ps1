BeforeAll {
    # Import the module functions
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    $PublicFunctionPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\public\Remediation\Get-IntuneRemediationSummary.ps1'
    $PrivateFunctionsPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\private'

    # Dot-source private dependency
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Invoke-GraphGet.ps1')
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Get-FirstPropertyValue.ps1')

    # Dot-source function under test
    . $PublicFunctionPath
}

Describe 'Get-IntuneRemediationSummary' {
    Context 'When Graph responses are valid' {
        It 'Should return one row per remediation with mapped counters' {
            # Arrange
            $mockScriptId = 'f1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockScriptName = 'BitLocker detection and remediation'

            $mockScriptsResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id          = $mockScriptId
                        displayName = $mockScriptName
                    }
                )
            }

            $mockSummaryResponse = [PSCustomObject]@{
                noIssueDetectedDeviceCount           = 12
                issueDetectedDeviceCount             = 5
                issueRemediatedDeviceCount           = 4
                issueReoccurredDeviceCount           = 1
                issueRemediatedCumulativeDeviceCount = 4
                lastScriptRunDateTime                = '2026-03-12T08:00:00Z'
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match 'deviceHealthScripts\?\$select=id,displayName$') {
                    return $mockScriptsResponse
                }

                if ($Uri -match '/deviceHealthScripts/.+/runSummary$') {
                    return $mockSummaryResponse
                }

                throw "Unexpected URI: $Uri"
            }

            # Act
            $result = @(Get-IntuneRemediationSummary)

            # Assert
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be $mockScriptName
            $result[0].Status | Should -Be 'Completed'
            $result[0].WithoutIssues | Should -Be 12
            $result[0].WithIssues | Should -Be 5
            $result[0].IssueFixed | Should -Be 4
            $result[0].IssueRecurred | Should -Be 1
            $result[0].TotalRemediated | Should -Be 4
        }

        It 'Should default counters to 0 and status to Unknown when fields are missing' {
            # Arrange
            $mockScriptId = 'a1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockScriptsResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id          = $mockScriptId
                        displayName = 'Windows Defender remediation'
                    }
                )
            }

            $mockSummaryResponse = [PSCustomObject]@{}

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match 'deviceHealthScripts\?\$select=id,displayName$') {
                    return $mockScriptsResponse
                }

                if ($Uri -match '/deviceHealthScripts/.+/runSummary$') {
                    return $mockSummaryResponse
                }

                throw "Unexpected URI: $Uri"
            }

            # Act
            $result = @(Get-IntuneRemediationSummary)

            # Assert
            $result.Count | Should -Be 1
            $result[0].Status | Should -Be 'Unknown'
            $result[0].WithoutIssues | Should -Be 0
            $result[0].WithIssues | Should -Be 0
            $result[0].IssueFixed | Should -Be 0
            $result[0].IssueRecurred | Should -Be 0
            $result[0].TotalRemediated | Should -Be 0
        }

        It 'Should handle nested runSummary payload shape' {
            # Arrange
            $mockScriptId = 'b1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockScriptName = 'Nested payload remediation'

            $mockScriptsResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id          = $mockScriptId
                        displayName = $mockScriptName
                    }
                )
            }

            $mockSummaryResponse = [PSCustomObject]@{
                value = [PSCustomObject]@{
                    runSummary = [PSCustomObject]@{
                        noIssueDetectedDeviceCount           = 3
                        issueDetectedDeviceCount             = 2
                        issueRemediatedDeviceCount           = 1
                        issueReoccurredDeviceCount           = 1
                        issueRemediatedCumulativeDeviceCount = 7
                        lastScriptRunDateTime                = '2026-03-12T09:00:00Z'
                    }
                }
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match 'deviceHealthScripts\?\$select=id,displayName$') {
                    return $mockScriptsResponse
                }

                if ($Uri -match '/deviceHealthScripts/.+/runSummary$') {
                    return $mockSummaryResponse
                }

                throw "Unexpected URI: $Uri"
            }

            # Act
            $result = @(Get-IntuneRemediationSummary)

            # Assert
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be $mockScriptName
            $result[0].WithoutIssues | Should -Be 3
            $result[0].WithIssues | Should -Be 2
            $result[0].IssueFixed | Should -Be 1
            $result[0].IssueRecurred | Should -Be 1
            $result[0].TotalRemediated | Should -Be 7
        }

        It 'Should fall back to remediation history when runSummary has no counters' {
            # Arrange
            $mockScriptId = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockScriptName = 'History fallback remediation'

            $mockScriptsResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id          = $mockScriptId
                        displayName = $mockScriptName
                    }
                )
            }

            $mockSummaryResponse = [PSCustomObject]@{}

            $mockHistoryResponse = [PSCustomObject]@{
                value = [PSCustomObject]@{
                    lastModifiedDateTime = '2026-03-12T10:00:00Z'
                    historyData          = @(
                        [PSCustomObject]@{
                            date                    = '2026-03-12'
                            remediatedDeviceCount   = 6
                            noIssueDeviceCount      = 9
                            detectFailedDeviceCount = 2
                        }
                    )
                }
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match 'deviceHealthScripts\?\$select=id,displayName$') {
                    return $mockScriptsResponse
                }

                if ($Uri -match '/deviceHealthScripts/.+/runSummary$') {
                    return $mockSummaryResponse
                }

                if ($Uri -match '/deviceHealthScripts/.+/getRemediationHistory$') {
                    return $mockHistoryResponse
                }

                throw "Unexpected URI: $Uri"
            }

            # Act
            $result = @(Get-IntuneRemediationSummary)

            # Assert
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be $mockScriptName
            $result[0].Status | Should -Be 'Completed'
            $result[0].WithoutIssues | Should -Be 9
            $result[0].WithIssues | Should -Be 8
            $result[0].IssueFixed | Should -Be 6
            $result[0].IssueRecurred | Should -Be 0
            $result[0].TotalRemediated | Should -Be 6
        }

        It 'Should aggregate remediation history when latest entry is zero' {
            # Arrange
            $mockScriptId = 'd1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockScriptName = 'History aggregate remediation'

            $mockScriptsResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id          = $mockScriptId
                        displayName = $mockScriptName
                    }
                )
            }

            $mockSummaryResponse = [PSCustomObject]@{}

            $mockHistoryResponse = [PSCustomObject]@{
                value = [PSCustomObject]@{
                    lastModifiedDateTime = '2026-03-12T10:00:00Z'
                    historyData          = @(
                        [PSCustomObject]@{
                            date                    = '2026-03-12'
                            remediatedDeviceCount   = 0
                            noIssueDeviceCount      = 0
                            detectFailedDeviceCount = 0
                        },
                        [PSCustomObject]@{
                            date                    = '2026-03-11'
                            remediatedDeviceCount   = 4
                            noIssueDeviceCount      = 7
                            detectFailedDeviceCount = 1
                        }
                    )
                }
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match 'deviceHealthScripts\?\$select=id,displayName$') {
                    return $mockScriptsResponse
                }

                if ($Uri -match '/deviceHealthScripts/.+/runSummary$') {
                    return $mockSummaryResponse
                }

                if ($Uri -match '/deviceHealthScripts/.+/getRemediationHistory$') {
                    return $mockHistoryResponse
                }

                throw "Unexpected URI: $Uri"
            }

            # Act
            $result = @(Get-IntuneRemediationSummary)

            # Assert
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be $mockScriptName
            $result[0].Status | Should -Be 'Completed'
            $result[0].WithoutIssues | Should -Be 7
            $result[0].WithIssues | Should -Be 5
            $result[0].IssueFixed | Should -Be 4
            $result[0].IssueRecurred | Should -Be 0
            $result[0].TotalRemediated | Should -Be 4
        }

        It 'Should resolve counters from AdditionalProperties payloads' {
            # Arrange
            $mockScriptId = 'e1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockScriptName = 'AdditionalProperties remediation'

            $mockScriptsResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id          = $mockScriptId
                        displayName = $mockScriptName
                    }
                )
            }

            $mockSummaryResponse = [PSCustomObject]@{
                AdditionalProperties = @{
                    noIssueDetectedDeviceCount           = 11
                    issueDetectedDeviceCount             = 3
                    issueRemediatedDeviceCount           = 2
                    issueReoccurredDeviceCount           = 1
                    issueRemediatedCumulativeDeviceCount = 9
                    lastScriptRunDateTime                = '2026-03-12T11:00:00Z'
                }
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match 'deviceHealthScripts\?\$select=id,displayName$') {
                    return $mockScriptsResponse
                }

                if ($Uri -match '/deviceHealthScripts/.+/runSummary$') {
                    return $mockSummaryResponse
                }

                throw "Unexpected URI: $Uri"
            }

            # Act
            $result = @(Get-IntuneRemediationSummary)

            # Assert
            $result.Count | Should -Be 1
            $result[0].Name | Should -Be $mockScriptName
            $result[0].Status | Should -Be 'Completed'
            $result[0].WithoutIssues | Should -Be 11
            $result[0].WithIssues | Should -Be 3
            $result[0].IssueFixed | Should -Be 2
            $result[0].IssueRecurred | Should -Be 1
            $result[0].TotalRemediated | Should -Be 9
        }
    }

    Context 'When Graph request fails' {
        It 'Should throw with RemediationListFailed when the list request fails generically' {
            # Arrange
            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                throw 'Graph list failure'
            }

            # Act
            $err = $null
            try { Get-IntuneRemediationSummary -ErrorAction Stop } catch { $err = $_ }

            # Assert
            $err | Should -Not -BeNullOrEmpty
            $err.FullyQualifiedErrorId | Should -Match 'RemediationListFailed'
        }

        It 'Should throw with RemediationListAccessDenied when the list request returns 403 Forbidden' {
            # Arrange
            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                $Exception = [Exception]::new('Graph request failed: Forbidden access denied (403)')
                $ErrorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $Exception,
                    'GraphRequestFailed',
                    [System.Management.Automation.ErrorCategory]::PermissionDenied,
                    $null
                )
                throw $ErrorRecord
            }

            # Act
            $err = $null
            try { Get-IntuneRemediationSummary -ErrorAction Stop } catch { $err = $_ }

            # Assert
            $err | Should -Not -BeNullOrEmpty
            $err.FullyQualifiedErrorId | Should -Match 'RemediationListAccessDenied'
        }
    }
}
