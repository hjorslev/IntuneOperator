BeforeAll {
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    $PublicFunctionPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\public\Device\Get-IntuneDevice.ps1'
    $PrivateFunctionsPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\private'

    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Resolve-IntuneDeviceByName.ps1')
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Resolve-IntuneDeviceByUser.ps1')
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Invoke-GraphGet.ps1')
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'ConvertTo-IntuneDeviceSummary.ps1')

    . $PublicFunctionPath
}

Describe 'Get-IntuneDevice' {
    Context 'When called with DeviceId parameter set' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testDeviceId = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testDeviceName = 'DEVICE-001'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testPrimaryUser = 'primary.user@contoso.com'

            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $mockDevice = [PSCustomObject]@{
                id                = $testDeviceId
                deviceName        = $testDeviceName
                userPrincipalName = $testPrimaryUser
                manufacturer      = 'Dell'
                model             = 'Latitude 7440'
                operatingSystem   = 'Windows'
                serialNumber      = 'ABC123XYZ'
                complianceState   = 'compliant'
                lastSyncDateTime  = '2026-03-18T08:30:00Z'
            }
        }

        It 'Should return a PSCustomObject with expected properties' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $mockDevice }

            $result = Get-IntuneDevice -DeviceId $testDeviceId

            $result | Should -Not -BeNullOrEmpty
            $result.DeviceName | Should -Be $testDeviceName
            $result.PrimaryUser | Should -Be $testPrimaryUser
            $result.DeviceManufacturer | Should -Be 'Dell'
            $result.DeviceModel | Should -Be 'Latitude 7440'
            $result.OperatingSystem | Should -Be 'Windows'
            $result.SerialNumber | Should -Be 'ABC123XYZ'
            $result.Compliance | Should -Be 'compliant'
            $result.LastSyncDateTime | Should -BeOfType [datetime]
        }

        It 'Should return nothing and write not found error when device does not exist' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $null }

            $result = Get-IntuneDevice -DeviceId $testDeviceId -ErrorAction SilentlyContinue -ErrorVariable deviceNotFoundError

            $result | Should -BeNullOrEmpty
            $deviceNotFoundError | Should -Not -BeNullOrEmpty
            $deviceNotFoundError[0].FullyQualifiedErrorId | Should -Match 'DeviceNotFound'
        }

        It 'Should reject invalid GUID format' {
            { Get-IntuneDevice -DeviceId 'not-a-guid' } | Should -Throw
        }
    }

    Context 'When called with DeviceName parameter set' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testDeviceId = 'f7e6d5c4-b3a2-1f0e-9d8c-7b6a5f4e3d2c'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testDeviceName = 'DEVICE-002'

            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $mockSummary = [PSCustomObject]@{
                id                = $testDeviceId
                deviceName        = $testDeviceName
                userPrincipalName = 'another.user@contoso.com'
                manufacturer      = 'Lenovo'
                model             = 'ThinkPad T14'
                operatingSystem   = 'Windows'
                serialNumber      = 'SER987654'
                complianceState   = 'noncompliant'
                lastSyncDateTime  = '2026-03-18T10:00:00Z'
            }
        }

        It 'Should resolve device by name and return mapped properties' {
            Mock -CommandName 'Resolve-IntuneDeviceByName' -MockWith { return @($mockSummary) }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { throw 'Should not be called for DeviceName lookups' }

            $result = Get-IntuneDevice -DeviceName $testDeviceName

            $result | Should -Not -BeNullOrEmpty
            $result.DeviceName | Should -Be $testDeviceName
            $result.DeviceManufacturer | Should -Be 'Lenovo'
            $result.Compliance | Should -Be 'noncompliant'
            Assert-MockCalled -CommandName 'Resolve-IntuneDeviceByName' -Times 1 -Exactly
            Assert-MockCalled -CommandName 'Invoke-GraphGet' -Times 0 -Exactly
        }

        It 'Should accept multiple DeviceName values and resolve each name' {
            $secondSummary = [PSCustomObject]@{
                id                = 'a1111111-b222-c333-d444-e55555555555'
                deviceName        = 'DEVICE-099'
                userPrincipalName = 'another.user@contoso.com'
                manufacturer      = 'HP'
                model             = 'EliteBook 840'
                operatingSystem   = 'Windows'
                serialNumber      = 'HP123456'
                complianceState   = 'compliant'
                lastSyncDateTime  = '2026-03-18T12:00:00Z'
            }

            Mock -CommandName 'Resolve-IntuneDeviceByName' -MockWith {
                param($Name)
                if ($Name -eq $testDeviceName) {
                    return @($mockSummary)
                }

                if ($Name -eq 'DEVICE-099') {
                    return @($secondSummary)
                }

                return @()
            }

            $result = Get-IntuneDevice -DeviceName @($testDeviceName, 'DEVICE-099')

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0].DeviceName | Should -Be $testDeviceName
            $result[1].DeviceName | Should -Be 'DEVICE-099'
            Assert-MockCalled -CommandName 'Resolve-IntuneDeviceByName' -Times 2 -Exactly
        }

        It 'Should return nothing and write not found error when name has no matches' {
            Mock -CommandName 'Resolve-IntuneDeviceByName' -MockWith { return @() }

            $result = Get-IntuneDevice -DeviceName $testDeviceName -ErrorAction SilentlyContinue -ErrorVariable deviceNameNotFoundError

            $result | Should -BeNullOrEmpty
            $deviceNameNotFoundError | Should -Not -BeNullOrEmpty
            $deviceNameNotFoundError[0].FullyQualifiedErrorId | Should -Match 'DeviceNameNotFound'
        }
    }

    Context 'When called with UserPrincipalName parameter set' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testUpn = 'jane.doe@contoso.com'

            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $mockUserDevice = [PSCustomObject]@{
                id                = 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a'
                deviceName        = 'DEVICE-003'
                userPrincipalName = $testUpn
                manufacturer      = 'Microsoft'
                model             = 'Surface Pro 9'
                operatingSystem   = 'Windows'
                serialNumber      = 'SRF789GHI'
                complianceState   = 'compliant'
                lastSyncDateTime  = '2026-03-18T11:00:00Z'
            }
        }

        It 'Should resolve devices by UPN and return mapped properties' {
            Mock -CommandName 'Resolve-IntuneDeviceByUser' -MockWith { return @($mockUserDevice) }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { throw 'Should not be called for UserPrincipalName lookups' }

            $result = Get-IntuneDevice -UserPrincipalName $testUpn

            $result | Should -Not -BeNullOrEmpty
            $result.DeviceName | Should -Be 'DEVICE-003'
            $result.PrimaryUser | Should -Be $testUpn
            $result.DeviceManufacturer | Should -Be 'Microsoft'
            $result.DeviceModel | Should -Be 'Surface Pro 9'
            $result.Compliance | Should -Be 'compliant'
            Assert-MockCalled -CommandName 'Resolve-IntuneDeviceByUser' -Times 1 -Exactly
            Assert-MockCalled -CommandName 'Invoke-GraphGet' -Times 0 -Exactly
        }

        It 'Should return all devices when user has multiple enrolled devices' {
            $secondDevice = [PSCustomObject]@{
                id                = 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b'
                deviceName        = 'DEVICE-004'
                userPrincipalName = $testUpn
                manufacturer      = 'Dell'
                model             = 'XPS 15'
                operatingSystem   = 'Windows'
                serialNumber      = 'DEL321JKL'
                complianceState   = 'noncompliant'
                lastSyncDateTime  = '2026-03-17T14:00:00Z'
            }
            Mock -CommandName 'Resolve-IntuneDeviceByUser' -MockWith { return @($mockUserDevice, $secondDevice) }

            $result = Get-IntuneDevice -UserPrincipalName $testUpn

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }

        It 'Should accept UserPrincipalName from pipeline by property name' {
            $pipelineObject = [PSCustomObject]@{ UserPrincipalName = $testUpn }
            Mock -CommandName 'Resolve-IntuneDeviceByUser' -MockWith { return @($mockUserDevice) }

            $result = $pipelineObject | Get-IntuneDevice

            $result | Should -Not -BeNullOrEmpty
            $result.PrimaryUser | Should -Be $testUpn
        }

        It 'Should return nothing and write not found error when user has no devices' {
            Mock -CommandName 'Resolve-IntuneDeviceByUser' -MockWith { return @() }

            $result = Get-IntuneDevice -UserPrincipalName $testUpn -ErrorAction SilentlyContinue -ErrorVariable userNotFoundError

            $result | Should -BeNullOrEmpty
            $userNotFoundError | Should -Not -BeNullOrEmpty
            $userNotFoundError[0].FullyQualifiedErrorId | Should -Match 'DeviceUserNotFound'
        }

        It 'Should write a terminating error when the Graph call fails unexpectedly' {
            Mock -CommandName 'Resolve-IntuneDeviceByUser' -MockWith { throw 'ServiceUnavailable: 503' }

            { Get-IntuneDevice -UserPrincipalName $testUpn -ErrorAction Stop } | Should -Throw
        }
    }
}
