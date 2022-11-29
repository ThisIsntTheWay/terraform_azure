# Runner VM module

Creates an Ubuntu (20.04 LTS) runner VM:  
![](https://github.com/ThisIsntTheWay/terraform_azure/raw/main/images/runnerVmAzureOverview.png)

The runner contains a public IP with SSH allowed from `*`:  
![](https://raw.githubusercontent.com/ThisIsntTheWay/terraform_azure/main/images/runnerVmAzureNic.png)

SSH is authenticated using `publickey`.  
Assumes the public key to be located at `~/.ssh/azure.pub`.
