BeforeAll {
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    $PublicFunctionPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\public\Remediation\Get-IntuneRemediationDeviceStatus.ps1'
    $PrivateFunctionsPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\private'

    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Invoke-GraphGet.ps1')
    . $PublicFunctionPath
}

Describe 'Get-IntuneRemediationDeviceStatus' {

    Context 'Parameter set ByName — matching name' {
        It 'Should return one row per device with mapped fields' {
            # Arrange
            $mockScriptId   = 'f1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockScriptName = 'BitLocker detection and remediation'

            $mockListResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{ id = $mockScriptId; displayName = $mockScriptName }
                )
            }

            $mockRunStatesResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id                                   = 'state-001'
                        detectionState                       = 'success'
                        remediationState                     = 'success'
                        lastStateUpdateDateTime              = '2026-03-12T08:00:00Z'
                        preRemediationDetectionScriptOutput  = 'BitLocker OFF'
                        postRemediationDetectionScriptOutput = 'BitLocker ON'
                        detectionScriptOutput                = $null
                        preRemediationDetectionScriptError   = $null
                        remediationScriptError               = $null
                        detectionScriptError                 = $null
                        managedDevice                        = [PSCustomObject]@{
                            id                = 'dev-001'
                            deviceName        = 'LAPTOP-001'
                            userPrincipalName = 'alice@contoso.com'
                        }
                    }
                )
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match 'deviceHealthScripts\?\$select=id,displayName$') {
                    return $mockListResponse
                }
                if ($Uri -match '/deviceHealthScripts/.+/deviceRunStates') {
                    return $mockRunStatesResponse
                }
                throw "Unexpected URI: $Uri"
            }

            # Act
            $result = @(Get-IntuneRemediationDeviceStatus -Name 'BitLocker*')

            # Assert
            $result.Count | Should -Be 1
            $result[0].RemediationName | Should -Be $mockScriptName
            $result[0].RemediationId | Should -Be $mockScriptId
            $result[0].DeviceId | Should -Be 'dev-001'
            $result[0].DeviceName | Should -Be 'LAPTOP-001'
            $result[0].UserPrincipalName | Should -Be 'alice@contoso.com'
            $result[0].DetectionState | Should -Be 'success'
            $result[0].RemediationState | Should -Be 'success'
            $result[0].PreRemediationOutput | Should -Be 'BitLocker OFF'
            $result[0].PostRemediationOutput | Should -Be 'BitLocker ON'
            $result[0].LastStateUpdate | Should -BeOfType [datetime]
        }

        It 'Should return multiple rows when multiple devices have run states' {
            # Arrange
            $mockScriptId   = 'a1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockScriptName = 'Windows Update remediation'

            $mockListResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{ id = $mockScriptId; displayName = $mockScriptName }
                )
            }

            $mockRunStatesResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id                                   = 'state-A'
                        detectionState                       = 'success'
                        remediationState                     = 'skipped'
                        lastStateUpdateDateTime              = '2026-03-12T07:00:00Z'
                        preRemediationDetectionScriptOutput  = 'WU enabled'
                        postRemediationDetectionScriptOutput = $null
                        detectionScriptOutput                = $null
                        preRemediationDetectionScriptError   = $null
                        remediationScriptError               = $null
                        detectionScriptError                 = $null
                        managedDevice                        = [PSCustomObject]@{
                            id                = 'dev-A'
                            deviceName        = 'PC-A'
                            userPrincipalName = 'bob@contoso.com'
                        }
                    },
                    [PSCustomObject]@{
                        id                                   = 'state-B'
                        detectionState                       = 'fail'
                        remediationState                     = 'remediationFailed'
                        lastStateUpdateDateTime              = '2026-03-11T20:00:00Z'
                        preRemediationDetectionScriptOutput  = 'WU disabled'
                        postRemediationDetectionScriptOutput = 'WU still disabled'
                        detectionScriptOutput                = $null
                        preRemediationDetectionScriptError   = $null
                        remediationScriptError               = 'Exit code 1'
                        detectionScriptError                 = $null
                        managedDevice                        = [PSCustomObject]@{
                            id                = 'dev-B'
                            deviceName        = 'PC-B'
                            userPrincipalName = 'carol@contoso.com'
                        }
                    }
                )
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match 'deviceHealthScripts\?\$select=id,displayName$') {
                    return $mockListResponse
                }
                if ($Uri -match '/deviceHealthScripts/.+/deviceRunStates') {
                    return $mockRunStatesResponse
                }
                throw "Unexpected URI: $Uri"
            }

            # Act
            $result = @(Get-IntuneRemediationDeviceStatus -Name $mockScriptName)

            # Assert
            $result.Count | Should -Be 2
            $result[0].DeviceName | Should -Be 'PC-A'
            $result[0].RemediationState | Should -Be 'skipped'
            $result[1].DeviceName | Should -Be 'PC-B'
            $result[1].RemediationError | Should -Be 'Exit code 1'
        }

        It 'Should write a non-terminating error and return nothing when no script matches the name' {
            # Arrange
            $mockListResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{ id = 'some-id'; displayName = 'Other remediation' }
                )
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match 'deviceHealthScripts\?\$select=id,displayName$') {
                    return $mockListResponse
                }
                throw "Unexpected URI: $Uri"
            }

            # Act
            $result = @(Get-IntuneRemediationDeviceStatus -Name 'NonExistent*' -ErrorAction SilentlyContinue -ErrorVariable notFoundError)

            # Assert
            $result.Count | Should -Be 0
            $notFoundError | Should -Not -BeNullOrEmpty
            $notFoundError[0].FullyQualifiedErrorId | Should -Match 'RemediationNotFound'
        }
    }

    Context 'Parameter set ById' {
        It 'Should query by ID and resolve the display name' {
            # Arrange
            $mockScriptId   = 'b1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockScriptName = 'Defender remediation'

            $mockDetailResponse = [PSCustomObject]@{
                id          = $mockScriptId
                displayName = $mockScriptName
            }

            $mockRunStatesResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id                                   = 'state-X'
                        detectionState                       = 'success'
                        remediationState                     = 'success'
                        lastStateUpdateDateTime              = '2026-03-12T09:00:00Z'
                        preRemediationDetectionScriptOutput  = 'Defender off'
                        postRemediationDetectionScriptOutput = 'Defender on'
                        detectionScriptOutput                = $null
                        preRemediationDetectionScriptError   = $null
                        remediationScriptError               = $null
                        detectionScriptError                 = $null
                        managedDevice                        = [PSCustomObject]@{
                            id                = 'dev-X'
                            deviceName        = 'WKSTN-001'
                            userPrincipalName = 'dave@contoso.com'
                        }
                    }
                )
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match "/deviceHealthScripts/$mockScriptId\?\`$select=id,displayName$") {
                    return $mockDetailResponse
                }
                if ($Uri -match '/deviceHealthScripts/.+/deviceRunStates') {
                    return $mockRunStatesResponse
                }
                throw "Unexpected URI: $Uri"
            }

            # Act
            $result = @(Get-IntuneRemediationDeviceStatus -Id $mockScriptId)

            # Assert
            $result.Count | Should -Be 1
            $result[0].RemediationName | Should -Be $mockScriptName
            $result[0].RemediationId | Should -Be $mockScriptId
            $result[0].DeviceName | Should -Be 'WKSTN-001'
            $result[0].PreRemediationOutput | Should -Be 'Defender off'
            $result[0].PostRemediationOutput | Should -Be 'Defender on'
        }

        It 'Should still return results if fetching display name fails' {
            # Arrange
            $mockScriptId = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'

            $mockRunStatesResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id                                   = 'state-Y'
                        detectionState                       = 'fail'
                        remediationState                     = 'noScriptContent'
                        lastStateUpdateDateTime              = '2026-03-10T12:00:00Z'
                        preRemediationDetectionScriptOutput  = $null
                        postRemediationDetectionScriptOutput = $null
                        detectionScriptOutput                = $null
                        preRemediationDetectionScriptError   = 'Script error'
                        remediationScriptError               = $null
                        detectionScriptError                 = $null
                        managedDevice                        = [PSCustomObject]@{
                            id                = 'dev-Y'
                            deviceName        = 'SRV-001'
                            userPrincipalName = $null
                        }
                    }
                )
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match "\?\`$select=id,displayName$") {
                    throw 'Name lookup failed'
                }
                if ($Uri -match '/deviceHealthScripts/.+/deviceRunStates') {
                    return $mockRunStatesResponse
                }
                throw "Unexpected URI: $Uri"
            }

            # Act / Assert — should not throw, falls back to ID as RemediationName
            $result = @(Get-IntuneRemediationDeviceStatus -Id $mockScriptId -WarningAction SilentlyContinue)

            $result.Count | Should -Be 1
            $result[0].RemediationId | Should -Be $mockScriptId
            $result[0].PreRemediationError | Should -Be 'Script error'
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
            try { Get-IntuneRemediationDeviceStatus -Name '*' -ErrorAction Stop } catch { $err = $_ }

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
            try { Get-IntuneRemediationDeviceStatus -Name '*' -ErrorAction Stop } catch { $err = $_ }

            # Assert
            $err | Should -Not -BeNullOrEmpty
            $err.FullyQualifiedErrorId | Should -Match 'RemediationListAccessDenied'
        }

        It 'Should emit a warning and skip if deviceRunStates fails, not throw' {
            # Arrange
            $mockScriptId = 'd1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'

            $mockListResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{ id = $mockScriptId; displayName = 'Failing remediation' }
                )
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match 'deviceHealthScripts\?\$select=id,displayName$') {
                    return $mockListResponse
                }
                if ($Uri -match '/deviceHealthScripts/.+/deviceRunStates') {
                    throw 'Run states error'
                }
                throw "Unexpected URI: $Uri"
            }

            # Act — should NOT throw
            $result = @(Get-IntuneRemediationDeviceStatus -Name '*' -WarningAction SilentlyContinue)

            # Assert
            $result.Count | Should -Be 0
        }
    }

    Context 'Pipeline input' {
        It 'Should accept Name via pipeline by property name' {
            # Arrange
            $mockScriptId   = 'e1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockScriptName = 'Pipeline input remediation'

            $mockListResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{ id = $mockScriptId; displayName = $mockScriptName }
                )
            }

            $mockRunStatesResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id                                   = 'state-P'
                        detectionState                       = 'success'
                        remediationState                     = 'success'
                        lastStateUpdateDateTime              = '2026-03-12T10:00:00Z'
                        preRemediationDetectionScriptOutput  = 'Before'
                        postRemediationDetectionScriptOutput = 'After'
                        detectionScriptOutput                = $null
                        preRemediationDetectionScriptError   = $null
                        remediationScriptError               = $null
                        detectionScriptError                 = $null
                        managedDevice                        = [PSCustomObject]@{
                            id                = 'dev-P'
                            deviceName        = 'PC-PIPE'
                            userPrincipalName = 'eve@contoso.com'
                        }
                    }
                )
            }

            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                param([string]$Uri)
                if ($Uri -match 'deviceHealthScripts\?\$select=id,displayName$') {
                    return $mockListResponse
                }
                if ($Uri -match '/deviceHealthScripts/.+/deviceRunStates') {
                    return $mockRunStatesResponse
                }
                throw "Unexpected URI: $Uri"
            }

            # Act — pipe an object whose .Name property matches the -Name parameter
            $pipeInput = [PSCustomObject]@{ Name = $mockScriptName }
            $result    = @($pipeInput | Get-IntuneRemediationDeviceStatus)

            # Assert
            $result.Count | Should -Be 1
            $result[0].DeviceName | Should -Be 'PC-PIPE'
            $result[0].PreRemediationOutput | Should -Be 'Before'
            $result[0].PostRemediationOutput | Should -Be 'After'
        }
    }
}
