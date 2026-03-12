# IntuneOperator

| GH Actions                                                                                                                                                                                                                             | PS Gallery                                                                                                                                                                |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/hjorslev/IntuneOperator/Process-PSModule.yml?logo=GitHub&label=CI%2FCD)](https://github.com/hjorslev/IntuneOperator/actions/workflows/CI.yml) | [![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/IntuneOperator?style=flat&logo=PowerShell)](https://www.powershellgallery.com/packages/IntuneOperator) |

## Introduction

[IntuneOperator](https://www.powershellgallery.com/packages/IntuneOperator/) is a PowerShell module for Intune that helps Endpoint Specialists manage
their Intune environment with small, practical tools for daily tasks.

## Installation

To install the module from the PowerShell Gallery, you can use the following command:

```powershell
Install-PSResource -Name IntuneOperator
Import-Module -Name IntuneOperator
```

## Usage

Here is a list of example that are typical use cases for the module.

### Example 1: Get-IntuneDeviceLogin

As for March 2026 there is one cmdlet: `Get-IntuneDeviceLogin`.

```powershell
Get-IntuneDeviceLogin -DeviceName PC-001
```

```text
DeviceName        : PC-001
UserPrincipalName : john.doe@contoso.com
DeviceId          : c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a
UserId            : a5b6c7d8-e9f0-1a2b-3c4d-5e6f7a8b9c0d
LastLogonDateTime : 3/9/2026 8:14:00 AM

DeviceName        : PC-001
UserPrincipalName : jane.smith@contoso.com
DeviceId          : c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a
UserId            : b1c2d3e4-f5a6-7b8c-9d0e-1f2a3b4c5d6e
LastLogonDateTime : 3/7/2026 2:45:00 PM
```

```powershell
Get-IntuneDeviceLogin -UserPrincipalName john.doe@contoso.com
```

```text
DeviceName        : PC-001
UserPrincipalName : john.doe@contoso.com
DeviceId          : c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a
UserId            : a5b6c7d8-e9f0-1a2b-3c4d-5e6f7a8b9c0d
LastLogonDateTime : 3/9/2026 8:14:00 AM

DeviceName        : PC-042
UserPrincipalName : john.doe@contoso.com
DeviceId          : f7e6d5c4-b3a2-1f0e-9d8c-7b6a5f4e3d2c
UserId            : a5b6c7d8-e9f0-1a2b-3c4d-5e6f7a8b9c0d
LastLogonDateTime : 3/5/2026 9:33:00 AM
```

## Acknowledgements

- [Process-Module](https://github.com/PSModule/Process-PSModule) by [Marius Storhaug](https://github.com/MariusStorhaug). Contains the entire build pipeline. This is greatly beneficial and helps me just concentrating on building the cmdlets.