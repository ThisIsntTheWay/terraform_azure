### Import-Infrastructure.ps1
Creates `.tf.json` files based on existing Azure infrastructure.  
(Not all ressource types yet implemented)

Also offers the option to automatically import said infrastructure.

Requires an active AzureCLI session.
```PowerShell
Import-Infrastructure.ps1 [-UseExplicitIdentifiers] [-AdminPassword <String>]
```
### Manage-VMs.ps1
Small script to quickly start or shut down all VMs.
```PowerShell
Manage-VMs.ps1 (start|stop)
```
