<#        
    .SYNOPSIS
     Create Azure Web App Service.

    .DESCRIPTION
1)	Set initial variables; app name, resource group, location, custom domain name, and subscription
2)	Prerequisites; Check the PowerShell version and make sure the Azure module is installed.
3)	One thing to consider in connecting to azure, for a manual/automated process you can just use the standard "Connect-AzAccount" which will prompt you to go to a webpage and enter a code provided which will then authenticate you and the script will continue. For a fully automated script it is best to use a Service Principal account in Azure which are designed for automation. However, either way works.
4)	Set the subscription that the app service will be created under.
5)	Create the Standard tier app service plan
6)	Create the App Service Web App, here we specify the app name, service plan name, location, resource group, and tier
7)	Create the additional slots, we don't have to create the production slot as that always exists.
8)	Next we will verify that all the slots were created correctly
9)	Create a custom domain name


    .NOTES
    ========================================================================
         Windows PowerShell Source File 
                  
         NAME: 
         
         AUTHOR: The Code Asylum , 
         DATE  : 5/16/2019
         
         COMMENT: 
         
    ==========================================================================
#>
# Edit These Variables
$appname = "LIBRARY"
$resgroup = "WEB-RG"
$loc = "West Europe"
$fqdn = "custom_domain_name"
$subscription = "####-####-####-############"

# Service Plan Name
$appsrvplan = $appname + "-ASP"

# Requires PowerShell 5.1 and Azure AZ module
$major = $PSVersionTable.PSVersion.Major
$minor = $PSVersionTable.PSVersion.Minor
If ($major -ge "5")
{
	if ($minor -ge "1")
	{
		$major = $PSVersionTable.PSVersion.Major
		$minor = $PSVersionTable.PSVersion.Minor
		write-output "PowerShell version is $major.$minor proceeding.."
	}
}
else
{
	write-output "PowerShell version needs updating $major.$minor"
	throw 'Exiting Script because PowerShell version is too low'
}

# Check and uninstall Azure RM
If (Get-Module -ListAvailable -Name AzureRM)
{
	write-output "Uninstalling Azure RM"
	Uninstall-AzureRm
}
else
{
	write-output "Azure RM module not detected, proceeding.."
}

# Check if Azure AZ module is installed
If (Get-Module -ListAvailable -Name Az)
{
	write-output "Azure AZ module installed, proceeding"
	Enable-AzureRmAlias -Scope CurrentUser
}
else
{
	write-output "Azure AZ module not detected, installing before proceeding"
	# Install PowerShell Azure Module
	Install-Module -Name Az -AllowClobber
	Import-Module AzureRM
}

# Login to Azure
Connect-AzAccount

# Set Subscription where you want to create the Azure App Service Web App
Get-AzSubscription
Set-AzContext -SubscriptionId $subscription

# Create the Standard Tier App Service Plan
New-AzAppServicePlan -Name $appsrvplan -Location $loc -ResourceGroupName $resgroup -Tier Standard

# Create the Azure App Service Web App
New-AzWebApp -Name $appname -AppServicePlan $appsrvplan -ResourceGroupName $resgroup -Location $loc

# Create the additional slots, "production" always exists.
Set-AzWebAppSlot -ResourceGroupName $resgroup -Name $appname -Slot "dev"
Set-AzWebAppSlot -ResourceGroupName $resgroup -Name $appname -Slot "preview"
Set-AzWebAppSlot -ResourceGroupName $resgroup -Name $appname -Slot "staging"

# Check newly created slots
Get-AzWebAppSlot -ResourceGroupName $resgroup -Name $appname

# Create a custom domain name
Write-output "Configuring a CNAME record that maps $fqdn to $appname.azurewebsites.net"
Set-AzWebApp -Name $appname -ResourceGroupName $resgroup -HostNames @($fqdn, "$appname.azurewebsites.net")

# Configure GitHub deployment to the staging slot from your GitHub repo and deploy once.
$PropertiesObject = @{
    repoUrl = "$gitrepos";
    branch = "master";
}
$gitrepo="https://github.com/Azure-Samples/app-service-web-dotnet-get-started.git"
Set-AzResource -PropertyObject $PropertiesObject -ResourceGroupName myResourceGroup -ResourceType Microsoft.Web/sites/slots/sourcecontrols -ResourceName $appname/staging/web -ApiVersion 2015-08-01 -Force

# Finished
Write-Output "Finished creating and configuring $appname"
