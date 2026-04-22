BeforeAll {
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $PrivateFunctionsPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\private'

    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Invoke-GraphGet.ps1')
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Resolve-IntuneDeviceByName.ps1')
}

Describe 'Resolve-IntuneDeviceByName' {
    Context 'When the filtered query succeeds and a match is found' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testDeviceName = 'PC-001'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $mockDevice = [PSCustomObject]@{
                id                = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                deviceName        = $testDeviceName
                userPrincipalName = 'primary.user@contoso.com'
                manufacturer      = 'Dell'
                model             = 'Latitude 7440'
                operatingSystem   = 'Windows'
                serialNumber      = 'ABC123XYZ'
                enrolledByUserId  = 'd1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                complianceState   = 'compliant'
                lastSyncDateTime  = '2026-03-18T08:30:00Z'
            }
        }

        It 'Should return a mapped PSCustomObject for the matching device' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($mockDevice) } }

            $result = Resolve-IntuneDeviceByName -Name $testDeviceName

            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be $mockDevice.id
            $result.deviceName | Should -Be $testDeviceName
            $result.userPrincipalName | Should -Be $mockDevice.userPrincipalName
            $result.manufacturer | Should -Be $mockDevice.manufacturer
            $result.model | Should -Be $mockDevice.model
            $result.operatingSystem | Should -Be $mockDevice.operatingSystem
            $result.serialNumber | Should -Be $mockDevice.serialNumber
            $result.complianceState | Should -Be $mockDevice.complianceState
            $result.lastSyncDateTime | Should -Be $mockDevice.lastSyncDateTime
        }

        It 'Should call Invoke-GraphGet with the filtered and select URI first' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($mockDevice) } }

            Resolve-IntuneDeviceByName -Name $testDeviceName | Out-Null

            Assert-MockCalled -CommandName 'Invoke-GraphGet' -Times 1 -Exactly -Scope It
            Assert-MockCalled -CommandName 'Invoke-GraphGet' -ParameterFilter {
                $Uri -match [regex]::Escape('$filter=') -and $Uri -match [regex]::Escape('$select=')
            } -Times 1 -Exactly -Scope It
        }

        It 'Should accept Name from the pipeline' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($mockDevice) } }

            $result = $testDeviceName | Resolve-IntuneDeviceByName

            $result | Should -Not -BeNullOrEmpty
            $result.deviceName | Should -Be $testDeviceName
        }

        It 'Should accept Name from pipeline by property name' {
            $pipelineObject = [PSCustomObject]@{ Name = $testDeviceName }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($mockDevice) } }

            $result = $pipelineObject | Resolve-IntuneDeviceByName

            $result | Should -Not -BeNullOrEmpty
            $result.deviceName | Should -Be $testDeviceName
        }

        It 'Should handle a response where the device is returned directly (no value wrapper)' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $mockDevice }

            $result = Resolve-IntuneDeviceByName -Name $testDeviceName

            $result | Should -Not -BeNullOrEmpty
            $result.deviceName | Should -Be $testDeviceName
        }

        It 'Should match device name case-insensitively' {
            $upperNameDevice = $mockDevice.PSObject.Copy()
            $upperNameDevice.deviceName = $testDeviceName.ToUpper()
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($upperNameDevice) } }

            $result = Resolve-IntuneDeviceByName -Name $testDeviceName.ToLower()

            $result | Should -Not -BeNullOrEmpty
            $result.deviceName | Should -Be $testDeviceName.ToUpper()
        }

        It 'Should return multiple devices when more than one match exists' {
            $secondDevice = [PSCustomObject]@{
                id                = 'a2b3c4d5-e6f7-4a8b-9c0d-1e2f3a4b5c6d'
                deviceName        = $testDeviceName
                userPrincipalName = 'second.user@contoso.com'
                manufacturer      = 'HP'
                model             = 'EliteBook 840'
                operatingSystem   = 'Windows'
                serialNumber      = 'XYZ987ABC'
                enrolledByUserId  = ''
                complianceState   = 'noncompliant'
                lastSyncDateTime  = '2026-03-17T12:00:00Z'
            }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($mockDevice, $secondDevice) } }

            $result = Resolve-IntuneDeviceByName -Name $testDeviceName

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }
    }

    Context 'When the filtered query returns BadRequest (fallback behaviour)' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testDeviceName = 'PC-002'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $mockDevice = [PSCustomObject]@{
                id                = 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e'
                deviceName        = $testDeviceName
                userPrincipalName = 'fallback.user@contoso.com'
                manufacturer      = 'Lenovo'
                model             = 'ThinkPad T14'
                operatingSystem   = 'Windows'
                serialNumber      = 'SER456DEF'
                enrolledByUserId  = ''
                complianceState   = 'compliant'
                lastSyncDateTime  = '2026-03-18T09:00:00Z'
            }
        }

        It 'Should fall back to the next candidate URI and return the matched device' {
            $script:fallbackCallCount = 0
            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                $script:fallbackCallCount++
                if ($script:fallbackCallCount -eq 1) { throw 'BadRequest: 400' }
                return [PSCustomObject]@{ value = @($mockDevice) }
            }

            $result = Resolve-IntuneDeviceByName -Name $testDeviceName

            $result | Should -Not -BeNullOrEmpty
            $result.deviceName | Should -Be $testDeviceName
        }

        It 'Should throw when all candidate URIs return BadRequest' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { throw 'BadRequest: 400' }

            { Resolve-IntuneDeviceByName -Name $testDeviceName } | Should -Throw
        }
    }

    Context 'When no matching device is found' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testDeviceName = 'UNKNOWN-DEVICE'
        }

        It 'Should return an empty array when no devices match the name' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @() } }

            $result = Resolve-IntuneDeviceByName -Name $testDeviceName

            $result | Should -BeNullOrEmpty
        }

        It 'Should return an empty array when response value contains only differently-named devices' {
            $otherDevice = [PSCustomObject]@{
                id                = 'ffffffff-0000-1111-2222-333333333333'
                deviceName        = 'OTHER-DEVICE'
                userPrincipalName = ''
                manufacturer      = 'HP'
                model             = 'ProBook 450'
                operatingSystem   = 'Windows'
                serialNumber      = 'OTHER123'
                enrolledByUserId  = ''
                complianceState   = 'unknown'
                lastSyncDateTime  = $null
            }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($otherDevice) } }

            $result = Resolve-IntuneDeviceByName -Name $testDeviceName

            $result | Should -BeNullOrEmpty
        }

        It 'Should return an empty array when Graph response is null' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $null }

            $result = Resolve-IntuneDeviceByName -Name $testDeviceName

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When device name contains single quotes' {
        It 'Should escape single quotes in the OData filter' {
            $nameWithQuote = "O'Brien-PC"
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @() } }

            Resolve-IntuneDeviceByName -Name $nameWithQuote | Out-Null

            Assert-MockCalled -CommandName 'Invoke-GraphGet' -ParameterFilter {
                $Uri -match [regex]::Escape("O''Brien-PC")
            } -Times 1 -Exactly -Scope It
        }
    }

    Context 'When a non-BadRequest error occurs' {
        It 'Should re-throw the error immediately without falling back' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { throw 'Unauthorized: 401' }

            { Resolve-IntuneDeviceByName -Name 'PC-003' } | Should -Throw 'Unauthorized: 401'

            Assert-MockCalled -CommandName 'Invoke-GraphGet' -Times 1 -Exactly -Scope It
        }
    }
}
