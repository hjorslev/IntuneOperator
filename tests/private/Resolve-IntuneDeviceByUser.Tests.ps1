BeforeAll {
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $PrivateFunctionsPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\private'

    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Invoke-GraphGet.ps1')
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Resolve-IntuneDeviceByUser.ps1')
}

Describe 'Resolve-IntuneDeviceByUser' {
    Context 'When the filtered query succeeds and a match is found' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testUpn = 'jane.doe@contoso.com'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $mockDevice = [PSCustomObject]@{
                id                = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                deviceName        = 'PC-001'
                userPrincipalName = $testUpn
                manufacturer      = 'Dell'
                model             = 'Latitude 7440'
                operatingSystem   = 'Windows'
                serialNumber      = 'ABC123XYZ'
                complianceState   = 'compliant'
                lastSyncDateTime  = '2026-03-18T08:30:00Z'
            }
        }

        It 'Should return a mapped PSCustomObject for the matching device' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($mockDevice) } }

            $result = Resolve-IntuneDeviceByUser -UserPrincipalName $testUpn

            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be $mockDevice.id
            $result.deviceName | Should -Be $mockDevice.deviceName
            $result.userPrincipalName | Should -Be $testUpn
            $result.manufacturer | Should -Be $mockDevice.manufacturer
            $result.model | Should -Be $mockDevice.model
            $result.operatingSystem | Should -Be $mockDevice.operatingSystem
            $result.serialNumber | Should -Be $mockDevice.serialNumber
            $result.complianceState | Should -Be $mockDevice.complianceState
            $result.lastSyncDateTime | Should -Be $mockDevice.lastSyncDateTime
        }

        It 'Should call Invoke-GraphGet with the filtered and select URI first' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($mockDevice) } }

            Resolve-IntuneDeviceByUser -UserPrincipalName $testUpn | Out-Null

            Assert-MockCalled -CommandName 'Invoke-GraphGet' -Times 1 -Exactly -Scope It
            Assert-MockCalled -CommandName 'Invoke-GraphGet' -ParameterFilter {
                $Uri -match [regex]::Escape('$filter=') -and $Uri -match [regex]::Escape('$select=')
            } -Times 1 -Exactly -Scope It
        }

        It 'Should accept UserPrincipalName from the pipeline' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($mockDevice) } }

            $result = $testUpn | Resolve-IntuneDeviceByUser

            $result | Should -Not -BeNullOrEmpty
            $result.userPrincipalName | Should -Be $testUpn
        }

        It 'Should accept UserPrincipalName from pipeline by property name' {
            $pipelineObject = [PSCustomObject]@{ UserPrincipalName = $testUpn }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($mockDevice) } }

            $result = $pipelineObject | Resolve-IntuneDeviceByUser

            $result | Should -Not -BeNullOrEmpty
            $result.userPrincipalName | Should -Be $testUpn
        }

        It 'Should handle a response where the device is returned directly (no value wrapper)' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $mockDevice }

            $result = Resolve-IntuneDeviceByUser -UserPrincipalName $testUpn

            $result | Should -Not -BeNullOrEmpty
            $result.userPrincipalName | Should -Be $testUpn
        }

        It 'Should match UPN case-insensitively' {
            $upperUpnDevice = $mockDevice.PSObject.Copy()
            $upperUpnDevice.userPrincipalName = $testUpn.ToUpper()
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($upperUpnDevice) } }

            $result = Resolve-IntuneDeviceByUser -UserPrincipalName $testUpn.ToLower()

            $result | Should -Not -BeNullOrEmpty
            $result.userPrincipalName | Should -Be $testUpn.ToUpper()
        }

        It 'Should return multiple devices when the user has more than one enrolled device' {
            $secondDevice = [PSCustomObject]@{
                id                = 'a2b3c4d5-e6f7-4a8b-9c0d-1e2f3a4b5c6d'
                deviceName        = 'PC-002'
                userPrincipalName = $testUpn
                manufacturer      = 'HP'
                model             = 'EliteBook 840'
                operatingSystem   = 'Windows'
                serialNumber      = 'XYZ987ABC'
                complianceState   = 'noncompliant'
                lastSyncDateTime  = '2026-03-17T12:00:00Z'
            }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($mockDevice, $secondDevice) } }

            $result = Resolve-IntuneDeviceByUser -UserPrincipalName $testUpn

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
        }
    }

    Context 'When the filtered query returns BadRequest (fallback behaviour)' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testUpn = 'fallback.user@contoso.com'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $mockDevice = [PSCustomObject]@{
                id                = 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e'
                deviceName        = 'PC-003'
                userPrincipalName = $testUpn
                manufacturer      = 'Lenovo'
                model             = 'ThinkPad T14'
                operatingSystem   = 'Windows'
                serialNumber      = 'SER456DEF'
                complianceState   = 'compliant'
                lastSyncDateTime  = '2026-03-18T09:00:00Z'
            }
        }

        It 'Should fall back to the next candidate URI and return the matched device' {
            $script:userFallbackCallCount = 0
            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                $script:userFallbackCallCount++
                if ($script:userFallbackCallCount -eq 1) { throw 'BadRequest: 400' }
                return [PSCustomObject]@{ value = @($mockDevice) }
            }

            $result = Resolve-IntuneDeviceByUser -UserPrincipalName $testUpn

            $result | Should -Not -BeNullOrEmpty
            $result.userPrincipalName | Should -Be $testUpn
        }

        It 'Should throw when all candidate URIs return BadRequest' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { throw 'BadRequest: 400' }

            { Resolve-IntuneDeviceByUser -UserPrincipalName $testUpn } | Should -Throw
        }
    }

    Context 'When no matching device is found' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testUpn = 'nobody@contoso.com'
        }

        It 'Should return an empty array when no devices match the UPN' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @() } }

            $result = Resolve-IntuneDeviceByUser -UserPrincipalName $testUpn

            $result | Should -BeNullOrEmpty
        }

        It 'Should return an empty array when response contains only differently-assigned devices' {
            $otherDevice = [PSCustomObject]@{
                id                = 'ffffffff-0000-1111-2222-333333333333'
                deviceName        = 'OTHER-PC'
                userPrincipalName = 'other.user@contoso.com'
                manufacturer      = 'HP'
                model             = 'ProBook 450'
                operatingSystem   = 'Windows'
                serialNumber      = 'OTHER123'
                complianceState   = 'unknown'
                lastSyncDateTime  = $null
            }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @($otherDevice) } }

            $result = Resolve-IntuneDeviceByUser -UserPrincipalName $testUpn

            $result | Should -BeNullOrEmpty
        }

        It 'Should return an empty array when Graph response is null' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $null }

            $result = Resolve-IntuneDeviceByUser -UserPrincipalName $testUpn

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'When UPN contains single quotes' {
        It 'Should escape single quotes in the OData filter' {
            $upnWithQuote = "o'brien@contoso.com"
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return [PSCustomObject]@{ value = @() } }

            Resolve-IntuneDeviceByUser -UserPrincipalName $upnWithQuote | Out-Null

            Assert-MockCalled -CommandName 'Invoke-GraphGet' -ParameterFilter {
                $Uri -match [regex]::Escape("o''brien@contoso.com")
            } -Times 1 -Exactly -Scope It
        }
    }

    Context 'When a non-BadRequest error occurs' {
        It 'Should re-throw the error immediately without falling back' {
            Mock -CommandName 'Invoke-GraphGet' -MockWith { throw 'Unauthorized: 401' }

            { Resolve-IntuneDeviceByUser -UserPrincipalName 'user@contoso.com' } | Should -Throw 'Unauthorized: 401'

            Assert-MockCalled -CommandName 'Invoke-GraphGet' -Times 1 -Exactly -Scope It
        }
    }
}
