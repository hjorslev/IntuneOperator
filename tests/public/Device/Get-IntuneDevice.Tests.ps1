BeforeAll {
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    $PublicFunctionPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\public\Device\Get-IntuneDevice.ps1'
    $PrivateFunctionsPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\private'

    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Resolve-IntuneDeviceByName.ps1')
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

        It 'Should return nothing and write not found error when name has no matches' {
            Mock -CommandName 'Resolve-IntuneDeviceByName' -MockWith { return @() }

            $result = Get-IntuneDevice -DeviceName $testDeviceName -ErrorAction SilentlyContinue -ErrorVariable deviceNameNotFoundError

            $result | Should -BeNullOrEmpty
            $deviceNameNotFoundError | Should -Not -BeNullOrEmpty
            $deviceNameNotFoundError[0].FullyQualifiedErrorId | Should -Match 'DeviceNameNotFound'
        }
    }
}
