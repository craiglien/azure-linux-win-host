# Azure provision Linux and Windows hosts

This repository contains Terraform HCL to build a Linux and Windows host on Azure.

The output is the ssh command to access the Linux host and the RDP command to access the Windows host.

To initiate the authentication requied to plan and apply this, use the [Azure command line](https://docs.microsoft.com/en-us/cli/azure/). Install the command line tool and authenticate.  Next, log into the [Azure portal](https://portal.azure.com). You can use the command line tool like this `az login --use-device-code` to authenticate and follow the instructions from that command.

Now use terraform to do the rest of the work.

* ```terraform init``` to install the provider dependencies.
* ```terraform plan``` to review the configuration.
* ```terraform apply``` to build the hosts.

Once the apply is complete the hosts are up.  The linux host reboots at the end of provisioning so it may take a minute to become available. The command ```ssh -Y -i keyfile -l azureuser [IPaddress]``` should work to get onto the linux host. Then ```xfreerdp /u:adminuser /v:10.0.1.4``` to RDP to the windows host.

Finally to destroy the infrastructure use ```terraform destroy```.


