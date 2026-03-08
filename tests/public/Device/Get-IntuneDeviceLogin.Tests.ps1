BeforeAll {
    # Import the module functions
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    $PublicFunctionPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\public\Device\Get-IntuneDeviceLogin.ps1'
    $PrivateFunctionsPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\private'

    # Dot-source the private functions that Get-IntuneDeviceLogin depends on
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Get-UsersLoggedOnForDevice.ps1')
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Resolve-EntraUserById.ps1')
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Resolve-IntuneDeviceByName.ps1')
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Invoke-GraphGet.ps1')

    # Dot-source the function we're testing
    . $PublicFunctionPath
}

Describe 'Get-IntuneDeviceLogin' {
    Context 'When called with DeviceId parameter set' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testDeviceId = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testDeviceName = 'DEVICE-001'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testUserId = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testUserPrincipalName = 'user@contoso.com'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testLastLogonDateTime = '2024-03-05T10:30:00Z'
        }

        It 'Should return a PSCustomObject with logged-on user information' {
            # Arrange
            $mockDevice = [PSCustomObject]@{
                id            = $testDeviceId
                deviceName    = $testDeviceName
                usersLoggedOn = @(
                    [PSCustomObject]@{
                        userId            = $testUserId
                        lastLogOnDateTime = $testLastLogonDateTime
                    }
                )
            }

            $mockUser = [PSCustomObject]@{
                id                = $testUserId
                userPrincipalName = $testUserPrincipalName
            }

            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $mockDevice }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith { return $mockUser }

            # Act
            $result = Get-IntuneDeviceLogin -DeviceId $testDeviceId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.DeviceId | Should -Be $testDeviceId
            $result.DeviceName | Should -Be $testDeviceName
            $result.UserId | Should -Be $testUserId
            $result.UserPrincipalName | Should -Be $testUserPrincipalName
            $result.LastLogonDateTime | Should -BeOfType [datetime]
        }

        It 'Should handle multiple logged-on users for a single device' {
            # Arrange
            $userId1 = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $userId2 = 'u2e2a2d7-2d2b-4d8c-9f0a-0d2a3d1e2f3b'
            $upn1 = 'user1@contoso.com'
            $upn2 = 'user2@contoso.com'

            $mockDevice = [PSCustomObject]@{
                id            = $testDeviceId
                deviceName    = $testDeviceName
                usersLoggedOn = @(
                    [PSCustomObject]@{
                        userId            = $userId1
                        lastLogOnDateTime = '2024-03-05T10:30:00Z'
                    },
                    [PSCustomObject]@{
                        userId            = $userId2
                        lastLogOnDateTime = '2024-03-04T09:15:00Z'
                    }
                )
            }

            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $mockDevice }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith {
                param([string]$UserId)
                if ($UserId -eq $userId1) {
                    return [PSCustomObject]@{
                        id                = $userId1
                        userPrincipalName = $upn1
                    }
                } else {
                    return [PSCustomObject]@{
                        id                = $userId2
                        userPrincipalName = $upn2
                    }
                }
            }

            # Act
            $results = @(Get-IntuneDeviceLogin -DeviceId $testDeviceId)

            # Assert
            $results.Count | Should -Be 2
            $results[0].UserPrincipalName | Should -Be $upn1
            $results[1].UserPrincipalName | Should -Be $upn2
        }

        It 'Should return nothing if no users are logged on' {
            # Arrange
            $mockDevice = [PSCustomObject]@{
                id            = $testDeviceId
                deviceName    = $testDeviceName
                usersLoggedOn = @()
            }

            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $mockDevice }

            # Act
            $result = Get-IntuneDeviceLogin -DeviceId $testDeviceId

            # Assert
            $result | Should -BeNullOrEmpty
            Assert-MockCalled -CommandName 'Get-UsersLoggedOnForDevice' -Times 1
        }

        It 'Should return nothing if device is not found' {
            # Arrange
            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $null }

            # Act
            $result = Get-IntuneDeviceLogin -DeviceId $testDeviceId

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It 'Should work with DeviceId alias "Id"' {
            # Arrange
            $mockDevice = [PSCustomObject]@{
                id            = $testDeviceId
                deviceName    = $testDeviceName
                usersLoggedOn = @(
                    [PSCustomObject]@{
                        userId            = $testUserId
                        lastLogOnDateTime = $testLastLogonDateTime
                    }
                )
            }

            $mockUser = [PSCustomObject]@{
                id                = $testUserId
                userPrincipalName = $testUserPrincipalName
            }

            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $mockDevice }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith { return $mockUser }

            # Act
            $result = Get-IntuneDeviceLogin -Id $testDeviceId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.DeviceId | Should -Be $testDeviceId
        }

        It 'Should work with DeviceId alias "ManagedDeviceId"' {
            # Arrange
            $mockDevice = [PSCustomObject]@{
                id            = $testDeviceId
                deviceName    = $testDeviceName
                usersLoggedOn = @(
                    [PSCustomObject]@{
                        userId            = $testUserId
                        lastLogOnDateTime = $testLastLogonDateTime
                    }
                )
            }

            $mockUser = [PSCustomObject]@{
                id                = $testUserId
                userPrincipalName = $testUserPrincipalName
            }

            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $mockDevice }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith { return $mockUser }

            # Act
            $result = Get-IntuneDeviceLogin -ManagedDeviceId $testDeviceId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.DeviceId | Should -Be $testDeviceId
        }

        It 'Should reject invalid GUID format' {
            # Act & Assert
            { Get-IntuneDeviceLogin -DeviceId 'not-a-guid' } | Should -Throw
        }
    }

    Context 'When called with DeviceName parameter set' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testDeviceId = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testDeviceName = 'DEVICE-001'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testUserId = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testUserPrincipalName = 'user@contoso.com'
        }

        It 'Should resolve device by name and return logged-on users' {
            # Arrange
            $mockDeviceSummary = [PSCustomObject]@{
                Id         = $testDeviceId
                DeviceName = $testDeviceName
            }

            $mockDevice = [PSCustomObject]@{
                id            = $testDeviceId
                deviceName    = $testDeviceName
                usersLoggedOn = @(
                    [PSCustomObject]@{
                        userId            = $testUserId
                        lastLogOnDateTime = '2024-03-05T10:30:00Z'
                    }
                )
            }

            $mockUser = [PSCustomObject]@{
                id                = $testUserId
                userPrincipalName = $testUserPrincipalName
            }

            Mock -CommandName 'Resolve-IntuneDeviceByName' -MockWith { return @($mockDeviceSummary) }
            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $mockDevice }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith { return $mockUser }

            # Act
            $result = Get-IntuneDeviceLogin -DeviceName $testDeviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.DeviceName | Should -Be $testDeviceName
            $result.UserPrincipalName | Should -Be $testUserPrincipalName
            Assert-MockCalled -CommandName 'Resolve-IntuneDeviceByName' -Times 1 -Exactly
            Assert-MockCalled -CommandName 'Get-UsersLoggedOnForDevice' -Times 1 -Exactly
        }

        It 'Should handle multiple devices with the same name' {
            # Arrange
            $deviceId1 = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $deviceId2 = 'c2f6d2d8-2d2c-4d8d-9f0b-0d2b3d1e2f3b'
            $userId1 = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $userId2 = 'u2e2a2d7-2d2b-4d8c-9f0a-0d2a3d1e2f3b'

            $mockDeviceSummaries = @(
                [PSCustomObject]@{
                    Id         = $deviceId1
                    DeviceName = $testDeviceName
                },
                [PSCustomObject]@{
                    Id         = $deviceId2
                    DeviceName = $testDeviceName
                }
            )

            $mockDevices = @(
                [PSCustomObject]@{
                    id            = $deviceId1
                    deviceName    = $testDeviceName
                    usersLoggedOn = @([PSCustomObject]@{
                            userId            = $userId1
                            lastLogOnDateTime = '2024-03-05T10:30:00Z'
                        })
                },
                [PSCustomObject]@{
                    id            = $deviceId2
                    deviceName    = $testDeviceName
                    usersLoggedOn = @([PSCustomObject]@{
                            userId            = $userId2
                            lastLogOnDateTime = '2024-03-05T11:00:00Z'
                        })
                }
            )

            Mock -CommandName 'Resolve-IntuneDeviceByName' -MockWith { return $mockDeviceSummaries }
            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith {
                param([string]$Id)
                if ($Id -eq $deviceId1) { return $mockDevices[0] }
                else { return $mockDevices[1] }
            }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith {
                param([string]$UserId)
                if ($UserId -eq $userId1) {
                    return [PSCustomObject]@{
                        id                = $userId1
                        userPrincipalName = 'user1@contoso.com'
                    }
                } else {
                    return [PSCustomObject]@{
                        id                = $userId2
                        userPrincipalName = 'user2@contoso.com'
                    }
                }
            }

            # Act
            $results = @(Get-IntuneDeviceLogin -DeviceName $testDeviceName)

            # Assert
            $results.Count | Should -Be 2
            $results[0].DeviceId | Should -Be $deviceId1
            $results[1].DeviceId | Should -Be $deviceId2
        }

        It 'Should work with DeviceName alias "Name"' {
            # Arrange
            $mockDeviceSummary = [PSCustomObject]@{
                Id         = $testDeviceId
                DeviceName = $testDeviceName
            }

            $mockDevice = [PSCustomObject]@{
                id            = $testDeviceId
                deviceName    = $testDeviceName
                usersLoggedOn = @(
                    [PSCustomObject]@{
                        userId            = $testUserId
                        lastLogOnDateTime = '2024-03-05T10:30:00Z'
                    }
                )
            }

            $mockUser = [PSCustomObject]@{
                id                = $testUserId
                userPrincipalName = $testUserPrincipalName
            }

            Mock -CommandName 'Resolve-IntuneDeviceByName' -MockWith { return @($mockDeviceSummary) }
            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $mockDevice }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith { return $mockUser }

            # Act
            $result = Get-IntuneDeviceLogin -Name $testDeviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should work with DeviceName alias "ComputerName"' {
            # Arrange
            $mockDeviceSummary = [PSCustomObject]@{
                Id         = $testDeviceId
                DeviceName = $testDeviceName
            }

            $mockDevice = [PSCustomObject]@{
                id            = $testDeviceId
                deviceName    = $testDeviceName
                usersLoggedOn = @(
                    [PSCustomObject]@{
                        userId            = $testUserId
                        lastLogOnDateTime = '2024-03-05T10:30:00Z'
                    }
                )
            }

            $mockUser = [PSCustomObject]@{
                id                = $testUserId
                userPrincipalName = $testUserPrincipalName
            }

            Mock -CommandName 'Resolve-IntuneDeviceByName' -MockWith { return @($mockDeviceSummary) }
            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $mockDevice }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith { return $mockUser }

            # Act
            $result = Get-IntuneDeviceLogin -ComputerName $testDeviceName

            # Assert
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return nothing if device name is not found' {
            # Arrange
            Mock -CommandName 'Resolve-IntuneDeviceByName' -MockWith { return @() }

            # Act
            $result = Get-IntuneDeviceLogin -DeviceName 'NonExistent'

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It 'Should skip devices with no logged-on users' {
            # Arrange
            $deviceId1 = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $deviceId2 = 'c2f6d2d8-2d2c-4d8d-9f0b-0d2b3d1e2f3b'

            $mockDeviceSummaries = @(
                [PSCustomObject]@{
                    Id         = $deviceId1
                    DeviceName = 'DEVICE-001'
                },
                [PSCustomObject]@{
                    Id         = $deviceId2
                    DeviceName = 'DEVICE-001'
                }
            )

            $mockDevices = @(
                [PSCustomObject]@{
                    id            = $deviceId1
                    deviceName    = 'DEVICE-001'
                    usersLoggedOn = @()
                },
                [PSCustomObject]@{
                    id            = $deviceId2
                    deviceName    = 'DEVICE-001'
                    usersLoggedOn = @([PSCustomObject]@{
                            userId            = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                            lastLogOnDateTime = '2024-03-05T11:00:00Z'
                        })
                }
            )

            Mock -CommandName 'Resolve-IntuneDeviceByName' -MockWith { return $mockDeviceSummaries }
            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith {
                param([string]$Id)
                if ($Id -eq $deviceId1) { return $mockDevices[0] }
                else { return $mockDevices[1] }
            }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith {
                return [PSCustomObject]@{
                    id                = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                    userPrincipalName = 'user1@contoso.com'
                }
            }

            # Act
            $results = @(Get-IntuneDeviceLogin -DeviceName 'DEVICE-001')

            # Assert
            $results.Count | Should -Be 1
            $results.DeviceId | Should -Be $deviceId2
        }

        It 'Should reject empty DeviceName' {
            # Act & Assert
            { Get-IntuneDeviceLogin -DeviceName '' } | Should -Throw
        }

        It 'Should reject null DeviceName' {
            # Act & Assert
            { Get-IntuneDeviceLogin -DeviceName $null } | Should -Throw
        }
    }

    Context 'Pipeline and property binding' {
        It 'Should accept DeviceId from pipeline' {
            # Arrange
            $testDeviceId = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $pipelineObject = [PSCustomObject]@{ Id = $testDeviceId }

            $mockDevice = [PSCustomObject]@{
                id            = $testDeviceId
                deviceName    = 'TEST-DEVICE'
                usersLoggedOn = @([PSCustomObject]@{
                        userId            = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                        lastLogOnDateTime = '2024-03-05T10:30:00Z'
                    })
            }

            $mockUser = [PSCustomObject]@{
                id                = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                userPrincipalName = 'user@contoso.com'
            }

            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $mockDevice }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith { return $mockUser }

            # Act
            $result = $pipelineObject | Get-IntuneDeviceLogin

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-MockCalled -CommandName 'Get-UsersLoggedOnForDevice' -Times 1
        }

        It 'Should accept DeviceName from pipeline' {
            # Arrange
            $testDeviceName = 'TEST-DEVICE'

            $mockDeviceSummary = [PSCustomObject]@{
                Id         = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                DeviceName = $testDeviceName
            }

            $mockDevice = [PSCustomObject]@{
                id            = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                deviceName    = $testDeviceName
                usersLoggedOn = @([PSCustomObject]@{
                        userId            = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                        lastLogOnDateTime = '2024-03-05T10:30:00Z'
                    })
            }

            $mockUser = [PSCustomObject]@{
                id                = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                userPrincipalName = 'user@contoso.com'
            }

            Mock -CommandName 'Resolve-IntuneDeviceByName' -MockWith { return @($mockDeviceSummary) }
            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $mockDevice }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith { return $mockUser }

            # Act
            $result = $testDeviceName | Get-IntuneDeviceLogin

            # Assert
            $result | Should -Not -BeNullOrEmpty
            Assert-MockCalled -CommandName 'Resolve-IntuneDeviceByName' -Times 1
        }

        It 'Should accept DeviceId from pipeline by property name' {
            # Arrange
            $testDeviceId = 'c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $pipelineObject = [PSCustomObject]@{
                Id = $testDeviceId
            }

            $mockDevice = [PSCustomObject]@{
                id            = $testDeviceId
                deviceName    = 'TEST-DEVICE'
                usersLoggedOn = @([PSCustomObject]@{
                        userId            = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                        lastLogOnDateTime = '2024-03-05T10:30:00Z'
                    })
            }

            $mockUser = [PSCustomObject]@{
                id                = 'u1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
                userPrincipalName = 'user@contoso.com'
            }

            Mock -CommandName 'Get-UsersLoggedOnForDevice' -MockWith { return $mockDevice }
            Mock -CommandName 'Resolve-EntraUserById' -MockWith { return $mockUser }

            # Act
            $result = $pipelineObject | Get-IntuneDeviceLogin

            # Assert
            $result | Should -Not -BeNullOrEmpty
        }
    }

}
