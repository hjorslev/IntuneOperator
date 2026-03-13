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

As for March 2026 the module has three cmdlets: `Get-IntuneDeviceLogin`, `Get-IntuneRemediationSummary` and `Get-IntuneRemediationDeviceStatus`.

```powershell
Get-IntuneDeviceLogin -DeviceName PC-001
```

```text
DeviceName        : PC-001
OperatingSystem   : Windows
UserPrincipalName : john.doe@contoso.com
DeviceId          : c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a
UserId            : a5b6c7d8-e9f0-1a2b-3c4d-5e6f7a8b9c0d
LastLogonDateTime : 3/9/2026 8:14:00 AM
```

```powershell
Get-IntuneDeviceLogin -UserPrincipalName john.doe@contoso.com
```

```text
DeviceName        : PC-001
OperatingSystem   : Windows
UserPrincipalName : john.doe@contoso.com
DeviceId          : c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a
UserId            : a5b6c7d8-e9f0-1a2b-3c4d-5e6f7a8b9c0d
LastLogonDateTime : 3/9/2026 8:14:00 AM

DeviceName        : PC-042
OperatingSystem   : Windows
UserPrincipalName : john.doe@contoso.com
DeviceId          : f7e6d5c4-b3a2-1f0e-9d8c-7b6a5f4e3d2c
UserId            : a5b6c7d8-e9f0-1a2b-3c4d-5e6f7a8b9c0d
LastLogonDateTime : 3/5/2026 9:33:00 AM
```

### Example 2: Get-IntuneRemediationSummary

```powershell
Get-IntuneRemediationSummary
```

```text
Name            : Fix BitLocker
Status          : Completed
WithoutIssues   : 214
WithIssues      : 3
IssueFixed      : 47
IssueRecurred   : 1
TotalRemediated : 47

Name            : Disable NetBIOS
Status          : Completed
WithoutIssues   : 217
WithIssues      : 0
IssueFixed      : 0
IssueRecurred   : 0
TotalRemediated : 0
```

### Example 3: Get-IntuneRemediationDeviceStatus

```powershell
Get-IntuneRemediationDeviceStatus -Name 'BitLocker detection and remediation'
```

```text
RemediationName       : BitLocker detection and remediation
RemediationId         : b2bf3efa-b16d-4936-866c-560592e4d35a
DeviceId              : c1f5d1d7-2d2b-4d8c-9f0a-0d2a3d1e2f3a
DeviceName            : PC-001
UserPrincipalName     : john.doe@contoso.com
LastStateUpdate       : 3/11/2026 6:00:00 AM
DetectionState        : success
RemediationState      : success
PreRemediationOutput  : BitLocker status: Off
PostRemediationOutput : BitLocker status: On
DetectionOutput       :
PreRemediationError   :
RemediationError      :
DetectionError        :

RemediationName       : BitLocker detection and remediation
RemediationId         : b2bf3efa-b16d-4936-866c-560592e4d35a
DeviceId              : f7e6d5c4-b3a2-1f0e-9d8c-7b6a5f4e3d2c
DeviceName            : PC-042
UserPrincipalName     : jane.smith@contoso.com
LastStateUpdate       : 3/11/2026 6:05:00 AM
DetectionState        : fail
RemediationState      : remediationFailed
PreRemediationOutput  : BitLocker status: Off
PostRemediationOutput : BitLocker status: Off
DetectionOutput       :
PreRemediationError   :
RemediationError      : Exit code: 1 - Access denied
DetectionError        :
```

You can also pipe from `Get-IntuneRemediationSummary` to only inspect remediations that have devices with issues:

```powershell
Get-IntuneRemediationSummary | Where-Object WithIssues -gt 0 | Get-IntuneRemediationDeviceStatus
```

## Acknowledgements

- [Process-Module](https://github.com/PSModule/Process-PSModule) by [Marius Storhaug](https://github.com/MariusStorhaug). Contains the entire build pipeline. This is greatly beneficial and helps me just concentrating on building the cmdlets.