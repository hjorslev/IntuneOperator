BeforeAll {
    # Import the module functions
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    $PrivateFunctionsPath = Join-Path -Path $ModuleRoot -ChildPath 'src\functions\private'

    # Dot-source the private functions
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Invoke-GraphGet.ps1')
    . (Join-Path -Path $PrivateFunctionsPath -ChildPath 'Resolve-EntraUserById.ps1')
}

Describe 'Resolve-EntraUserById' {
    Context 'When user exists in Entra ID' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testUserId = 'd1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testUserPrincipalName = 'testuser@contoso.com'
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $mockUser = [PSCustomObject]@{
                id                = $testUserId
                userPrincipalName = $testUserPrincipalName
                displayName       = 'Test User'
            }
        }

        It 'Should return user object with userPrincipalName' {
            # Arrange
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $mockUser }

            # Act
            $result = Resolve-EntraUserById -UserId $testUserId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be $testUserId
            $result.userPrincipalName | Should -Be $testUserPrincipalName
        }

        It 'Should call Invoke-GraphGet with correct URI' {
            # Arrange
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $mockUser }

            # Act
            Resolve-EntraUserById -UserId $testUserId | Out-Null

            # Assert
            Assert-MockCalled -CommandName 'Invoke-GraphGet' -Times 1 -Exactly -Scope It
            Assert-MockCalled -CommandName 'Invoke-GraphGet' -ParameterFilter {
                $Uri -eq "https://graph.microsoft.com/v1.0/users/$testUserId"
            }
        }

        It 'Should accept UserId from pipeline' {
            # Arrange
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $mockUser }

            # Act
            $result = $testUserId | Resolve-EntraUserById

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be $testUserId
            Assert-MockCalled -CommandName 'Invoke-GraphGet' -Times 1 -Exactly
        }

        It 'Should accept UserId from pipeline by property name' {
            # Arrange
            $pipelineObject = [PSCustomObject]@{ UserId = $testUserId }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $mockUser }

            # Act
            $result = $pipelineObject | Resolve-EntraUserById

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be $testUserId
            Assert-MockCalled -CommandName 'Invoke-GraphGet' -Times 1 -Exactly
        }
    }

    Context 'When user does not exist in Entra ID' {
        BeforeEach {
            [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
            $testUserId = 'd1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
        }

        It 'Should return placeholder object when user is not found' {
            # Arrange
            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                throw "User not found"
            }

            # Act
            $result = Resolve-EntraUserById -UserId $testUserId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be $testUserId
            $result.userPrincipalName | Should -Be "Unknown (ID: $testUserId)"
        }

        It 'Should write verbose message when user is not found' {
            # Arrange
            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                throw "User not found"
            }

            # Act
            $result = Resolve-EntraUserById -UserId $testUserId -Verbose 4>&1

            # Assert
            $verboseMessages = $result | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verboseMessages | Should -Not -BeNullOrEmpty
            $verboseMessages[0].Message | Should -BeLike "*Could not resolve user ID*"
        }

        It 'Should handle Graph API errors gracefully' {
            # Arrange
            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                throw "Graph request failed: Authentication needed"
            }

            # Act & Assert - Should not throw
            { Resolve-EntraUserById -UserId $testUserId } | Should -Not -Throw
        }
    }

    Context 'Parameter validation' {
        It 'Should reject null or empty UserId' {
            # Act & Assert
            { Resolve-EntraUserById -UserId $null } | Should -Throw
            { Resolve-EntraUserById -UserId '' } | Should -Throw
        }

        It 'Should accept valid GUID format' {
            # Arrange
            $validUserId = 'd1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockUser = [PSCustomObject]@{
                id                = $validUserId
                userPrincipalName = 'test@contoso.com'
            }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $mockUser }

            # Act & Assert - Should not throw
            { Resolve-EntraUserById -UserId $validUserId } | Should -Not -Throw
        }

        It 'Should accept non-GUID string format' {
            # Arrange
            # Note: The function doesn't validate GUID format, so any string is accepted
            $nonGuidUserId = 'not-a-guid-123'
            $mockUser = [PSCustomObject]@{
                id                = $nonGuidUserId
                userPrincipalName = 'test@contoso.com'
            }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $mockUser }

            # Act & Assert - Should not throw
            { Resolve-EntraUserById -UserId $nonGuidUserId } | Should -Not -Throw
        }
    }

    Context 'Output validation' {
        It 'Should return PSObject type' {
            # Arrange
            $testUserId = 'd1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockUser = [PSCustomObject]@{
                id                = $testUserId
                userPrincipalName = 'test@contoso.com'
                displayName       = 'Test User'
            }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $mockUser }

            # Act
            $result = Resolve-EntraUserById -UserId $testUserId

            # Assert
            $result | Should -BeOfType [PSCustomObject]
        }

        It 'Should preserve all properties from Graph API response' {
            # Arrange
            $testUserId = 'd1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            $mockUser = [PSCustomObject]@{
                id                = $testUserId
                userPrincipalName = 'test@contoso.com'
                displayName       = 'Test User'
                mail              = 'test@contoso.com'
                jobTitle          = 'Developer'
            }
            Mock -CommandName 'Invoke-GraphGet' -MockWith { return $mockUser }

            # Act
            $result = Resolve-EntraUserById -UserId $testUserId

            # Assert
            $result.id | Should -Be $testUserId
            $result.userPrincipalName | Should -Be 'test@contoso.com'
            $result.displayName | Should -Be 'Test User'
            $result.mail | Should -Be 'test@contoso.com'
            $result.jobTitle | Should -Be 'Developer'
        }
    }

    Context 'Error handling' {
        It 'Should handle authentication errors' {
            # Arrange
            $testUserId = 'd1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                throw "Authentication needed. Please call Connect-MgGraph."
            }

            # Act
            $result = Resolve-EntraUserById -UserId $testUserId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be $testUserId
            $result.userPrincipalName | Should -Be "Unknown (ID: $testUserId)"
        }

        It 'Should handle permission errors' {
            # Arrange
            $testUserId = 'd1e1a1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a'
            Mock -CommandName 'Invoke-GraphGet' -MockWith {
                throw "Insufficient privileges to complete the operation"
            }

            # Act
            $result = Resolve-EntraUserById -UserId $testUserId

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.id | Should -Be $testUserId
            $result.userPrincipalName | Should -Be "Unknown (ID: $testUserId)"
        }
    }
}
