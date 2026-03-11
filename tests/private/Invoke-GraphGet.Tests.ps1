BeforeAll {
    # Import the module functions
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $PrivateFunctionsPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\private'

    # Dot-source the function we're testing
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Invoke-GraphGet.ps1')
}

Describe 'Invoke-GraphGet' {
    Context 'When making a simple GET request without pagination' {
        It 'Should return the response as-is when no pagination exists' {
            # Arrange
            $testUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices/12345'
            $mockResponse = [PSCustomObject]@{
                id         = '12345'
                deviceName = 'TEST-DEVICE'
                osVersion  = '10.0.19045'
            }

            Mock -CommandName 'Invoke-MgGraphRequest' -MockWith { return $mockResponse }

            # Act
            $result = Invoke-GraphGet -Uri $testUri

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be '12345'
            $result.deviceName | Should -Be 'TEST-DEVICE'
            Assert-MockCalled -CommandName 'Invoke-MgGraphRequest' -Times 1 -Exactly
        }

        It 'Should return collection response without pagination' {
            # Arrange
            $testUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'
            $mockResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id         = 'device1'
                        deviceName = 'DEVICE-001'
                    },
                    [PSCustomObject]@{
                        id         = 'device2'
                        deviceName = 'DEVICE-002'
                    }
                )
            }

            Mock -CommandName 'Invoke-MgGraphRequest' -MockWith { return $mockResponse }

            # Act
            $result = Invoke-GraphGet -Uri $testUri

            # Assert
            $result.value | Should -Not -BeNullOrEmpty
            $result.value.Count | Should -Be 2
            $result.value[0].id | Should -Be 'device1'
            $result.value[1].id | Should -Be 'device2'
            Assert-MockCalled -CommandName 'Invoke-MgGraphRequest' -Times 1 -Exactly
        }
    }

    Context 'When response contains pagination' {
        It 'Should follow pagination links and aggregate all results' {
            # Arrange
            $testUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'

            $page1 = [PSCustomObject]@{
                value             = @(
                    [PSCustomObject]@{ id = 'device1'; deviceName = 'DEVICE-001' },
                    [PSCustomObject]@{ id = 'device2'; deviceName = 'DEVICE-002' }
                )
                '@odata.nextLink' = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$skiptoken=page2'
            }

            $page2 = [PSCustomObject]@{
                value             = @(
                    [PSCustomObject]@{ id = 'device3'; deviceName = 'DEVICE-003' },
                    [PSCustomObject]@{ id = 'device4'; deviceName = 'DEVICE-004' }
                )
                '@odata.nextLink' = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$skiptoken=page3'
            }

            $page3 = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{ id = 'device5'; deviceName = 'DEVICE-005' }
                )
            }

            Mock -CommandName 'Invoke-MgGraphRequest' -MockWith {
                param($Uri)
                if ($Uri -match 'skiptoken=page2') {
                    return $page2
                } elseif ($Uri -match 'skiptoken=page3') {
                    return $page3
                } else {
                    return $page1
                }
            }

            # Act
            $result = Invoke-GraphGet -Uri $testUri

            # Assert
            $result.value | Should -Not -BeNullOrEmpty
            $result.value.Count | Should -Be 5
            $result.value[0].id | Should -Be 'device1'
            $result.value[2].id | Should -Be 'device3'
            $result.value[4].id | Should -Be 'device5'

            # Verify nextLink was removed
            $result.'@odata.nextLink' | Should -BeNullOrEmpty

            # Verify all pages were requested
            Assert-MockCalled -CommandName 'Invoke-MgGraphRequest' -Times 3 -Exactly
        }

        It 'Should handle pagination with only two pages' {
            # Arrange
            $testUri = 'https://graph.microsoft.com/beta/users'

            $page1 = [PSCustomObject]@{
                value             = @(
                    [PSCustomObject]@{ id = 'user1'; userPrincipalName = 'user1@contoso.com' }
                )
                '@odata.nextLink' = 'https://graph.microsoft.com/beta/users?$skiptoken=page2'
            }

            $page2 = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{ id = 'user2'; userPrincipalName = 'user2@contoso.com' }
                )
            }

            Mock -CommandName 'Invoke-MgGraphRequest' -MockWith {
                param($Uri)
                if ($Uri -match 'skiptoken=page2') {
                    return $page2
                } else {
                    return $page1
                }
            }

            # Act
            $result = Invoke-GraphGet -Uri $testUri

            # Assert
            $result.value.Count | Should -Be 2
            $result.value[0].id | Should -Be 'user1'
            $result.value[1].id | Should -Be 'user2'
            $result.'@odata.nextLink' | Should -BeNullOrEmpty
            Assert-MockCalled -CommandName 'Invoke-MgGraphRequest' -Times 2 -Exactly
        }

        It 'Should handle empty pages in pagination' {
            # Arrange
            $testUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'

            $page1 = [PSCustomObject]@{
                value             = @(
                    [PSCustomObject]@{ id = 'device1'; deviceName = 'DEVICE-001' }
                )
                '@odata.nextLink' = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$skiptoken=page2'
            }

            $page2 = [PSCustomObject]@{
                value             = @()
                '@odata.nextLink' = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$skiptoken=page3'
            }

            $page3 = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{ id = 'device2'; deviceName = 'DEVICE-002' }
                )
            }

            Mock -CommandName 'Invoke-MgGraphRequest' -MockWith {
                param($Uri)
                if ($Uri -match 'skiptoken=page2') {
                    return $page2
                } elseif ($Uri -match 'skiptoken=page3') {
                    return $page3
                } else {
                    return $page1
                }
            }

            # Act
            $result = Invoke-GraphGet -Uri $testUri

            # Assert
            $result.value.Count | Should -Be 2
            $result.value[0].id | Should -Be 'device1'
            $result.value[1].id | Should -Be 'device2'
            Assert-MockCalled -CommandName 'Invoke-MgGraphRequest' -Times 3 -Exactly
        }

        It 'Should write verbose messages during pagination' {
            # Arrange
            $testUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'

            $page1 = [PSCustomObject]@{
                value             = @([PSCustomObject]@{ id = 'device1' })
                '@odata.nextLink' = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$skiptoken=page2'
            }

            $page2 = [PSCustomObject]@{
                value = @([PSCustomObject]@{ id = 'device2' })
            }

            Mock -CommandName 'Invoke-MgGraphRequest' -MockWith {
                param($Uri)
                if ($Uri -match 'skiptoken=page2') { return $page2 }
                else { return $page1 }
            }

            # Act
            $verboseOutput = Invoke-GraphGet -Uri $testUri -Verbose 4>&1

            # Assert
            $verboseOutput | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object -FilterScript { $_ -match 'Response contains pagination' } | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object -FilterScript { $_ -match 'Following pagination link' } | Should -Not -BeNullOrEmpty
            $verboseOutput | Where-Object -FilterScript { $_ -match 'Pagination complete' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'When handling errors' {
        It 'Should throw an error when Invoke-MgGraphRequest fails' {
            # Arrange
            $testUri = 'https://graph.microsoft.com/beta/nonexistent'
            Mock -CommandName 'Invoke-MgGraphRequest' -MockWith {
                throw [System.Exception]::new('Resource not found')
            }

            # Act & Assert
            { Invoke-GraphGet -Uri $testUri } | Should -Throw -ExpectedMessage "*Resource not found*"
        }

        It 'Should provide clear error message with URI' {
            # Arrange
            $testUri = 'https://graph.microsoft.com/beta/test'
            Mock -CommandName 'Invoke-MgGraphRequest' -MockWith {
                throw [System.Exception]::new('Unauthorized')
            }

            # Act & Assert
            { Invoke-GraphGet -Uri $testUri } | Should -Throw -ExpectedMessage "*Graph request failed for '$testUri'*"
        }
    }

    Context 'When handling edge cases' {
        It 'Should handle response with null value property' {
            # Arrange
            $testUri = 'https://graph.microsoft.com/beta/test'
            $mockResponse = [PSCustomObject]@{
                value = $null
            }

            Mock -CommandName 'Invoke-MgGraphRequest' -MockWith { return $mockResponse }

            # Act
            $result = Invoke-GraphGet -Uri $testUri

            # Assert
            $result.value | Should -BeNullOrEmpty
        }

        It 'Should not treat response without value property as paginated' {
            # Arrange
            $testUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices/12345'
            $mockResponse = [PSCustomObject]@{
                id                = '12345'
                deviceName        = 'TEST-DEVICE'
                '@odata.nextLink' = 'https://somelink.com'  # This shouldn't trigger pagination without 'value'
            }

            Mock -CommandName 'Invoke-MgGraphRequest' -MockWith { return $mockResponse }

            # Act
            $result = Invoke-GraphGet -Uri $testUri

            # Assert
            $result.id | Should -Be '12345'
            $result.'@odata.nextLink' | Should -Be 'https://somelink.com'
            Assert-MockCalled -CommandName 'Invoke-MgGraphRequest' -Times 1 -Exactly
        }

        It 'Should handle multiple pages with many items' {
            # Arrange
            $testUri = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices'

            $page1 = [PSCustomObject]@{
                value             = @(
                    [PSCustomObject]@{ id = 'device1'; deviceName = 'DEVICE-001' },
                    [PSCustomObject]@{ id = 'device2'; deviceName = 'DEVICE-002' },
                    [PSCustomObject]@{ id = 'device3'; deviceName = 'DEVICE-003' }
                )
                '@odata.nextLink' = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$skiptoken=page2'
            }

            $page2 = [PSCustomObject]@{
                value             = @(
                    [PSCustomObject]@{ id = 'device4'; deviceName = 'DEVICE-004' },
                    [PSCustomObject]@{ id = 'device5'; deviceName = 'DEVICE-005' }
                )
                '@odata.nextLink' = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$skiptoken=page3'
            }

            $page3 = [PSCustomObject]@{
                value             = @(
                    [PSCustomObject]@{ id = 'device6'; deviceName = 'DEVICE-006' },
                    [PSCustomObject]@{ id = 'device7'; deviceName = 'DEVICE-007' }
                )
                '@odata.nextLink' = 'https://graph.microsoft.com/beta/deviceManagement/managedDevices?$skiptoken=page4'
            }

            $page4 = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{ id = 'device8'; deviceName = 'DEVICE-008' }
                )
            }

            Mock -CommandName 'Invoke-MgGraphRequest' -MockWith {
                param($Uri)
                if ($Uri -match 'skiptoken=page4') {
                    return $page4
                } elseif ($Uri -match 'skiptoken=page3') {
                    return $page3
                } elseif ($Uri -match 'skiptoken=page2') {
                    return $page2
                } else {
                    return $page1
                }
            }

            # Act
            $result = Invoke-GraphGet -Uri $testUri

            # Assert
            $result.value.Count | Should -Be 8
            $result.value[0].id | Should -Be 'device1'
            $result.value[3].id | Should -Be 'device4'
            $result.value[7].id | Should -Be 'device8'
            $result.'@odata.nextLink' | Should -BeNullOrEmpty
            Assert-MockCalled -CommandName 'Invoke-MgGraphRequest' -Times 4 -Exactly
        }
    }
}
