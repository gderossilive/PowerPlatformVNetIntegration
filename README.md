# Power Platform Virtual Network Support Test

## Purpose
This document describes the steps and scripts used to test the procedure for setting up virtual network support for Microsoft Power Platform, following the official Microsoft documentation:

[Set up virtual network support for Power Platform](https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-setup-configure?tabs=new#set-up-virtual-network-support)

## Test Steps

1. **Identify Required Scripts**
   - Downloaded all scripts referenced in the Microsoft Learn article from the official GitHub repository.
   - Located the scripts in the `orig-scripts` directory and its subfolders.

2. **Copy Scripts for Testing**
   - Copied all scripts needed for the procedure into the `scripts` directory for easier access and execution.

3. **Scripts Used**
   - `1-SetupSubscriptionForPowerPlatform.ps1`
   - Any additional scripts referenced by the main procedure (e.g., scripts in `Common/` or `Cmk/` as required).

4. **Execution**
   - Followed the steps in the Microsoft documentation, running the scripts in the recommended order.
   - Used the `scripts` directory as the working location for all test executions.

5. **Notes and Observations**
   - Document any issues, required parameters, or environment prerequisites encountered during testing here.

## References
- [Microsoft Learn: Set up virtual network support for Power Platform](https://learn.microsoft.com/en-us/power-platform/admin/vnet-support-setup-configure?tabs=new#set-up-virtual-network-support)
- [GitHub: Power Platform Admin Scripts](https://github.com/microsoft/PowerApps-Samples/tree/main/power-platform/administration/virtual-network-support)

---

*Update this file with your test results, issues, and any additional notes as you proceed with the setup and testing.*
