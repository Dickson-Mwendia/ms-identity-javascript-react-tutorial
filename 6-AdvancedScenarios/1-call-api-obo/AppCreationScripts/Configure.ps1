
[CmdletBinding()]
param(
    [Parameter(Mandatory=$False, HelpMessage='Tenant ID (This is a GUID which represents the "Directory ID" of the AzureAD tenant into which you want to create the apps')]
    [string] $tenantId,
    [Parameter(Mandatory=$False, HelpMessage='Azure environment to use while running the script. Default = Global')]
    [string] $azureEnvironmentName
)

<#
 This script creates the Azure AD applications needed for this sample and updates the configuration files
 for the visual Studio projects from the data in the Azure AD applications.

 In case you don't have Microsoft.Graph.Applications already installed, the script will automatically install it for the current user
 
 There are four ways to run this script. For more information, read the AppCreationScripts.md file in the same folder as this script.
#>

# Create an application key
# See https://www.sabin.io/blog/adding-an-azure-active-directory-application-and-key-using-powershell/
Function CreateAppKey([DateTime] $fromDate, [double] $durationInMonths)
{
    $key = New-Object Microsoft.Graph.PowerShell.Models.MicrosoftGraphPasswordCredential

    $key.StartDateTime = $fromDate
    $key.EndDateTime = $fromDate.AddMonths($durationInMonths)
    $key.KeyId = (New-Guid).ToString()
    $key.DisplayName = "app secret"

    return $key
}

# Adds the requiredAccesses (expressed as a pipe separated string) to the requiredAccess structure
# The exposed permissions are in the $exposedPermissions collection, and the type of permission (Scope | Role) is 
# described in $permissionType
Function AddResourcePermission($requiredAccess, `
                               $exposedPermissions, [string]$requiredAccesses, [string]$permissionType)
{
    foreach($permission in $requiredAccesses.Trim().Split("|"))
    {
        foreach($exposedPermission in $exposedPermissions)
        {
            if ($exposedPermission.Value -eq $permission)
                {
                $resourceAccess = New-Object Microsoft.Graph.PowerShell.Models.MicrosoftGraphResourceAccess
                $resourceAccess.Type = $permissionType # Scope = Delegated permissions | Role = Application permissions
                $resourceAccess.Id = $exposedPermission.Id # Read directory data
                $requiredAccess.ResourceAccess += $resourceAccess
                }
        }
    }
}

#
# Example: GetRequiredPermissions "Microsoft Graph"  "Graph.Read|User.Read"
# See also: http://stackoverflow.com/questions/42164581/how-to-configure-a-new-azure-ad-application-through-powershell
Function GetRequiredPermissions([string] $applicationDisplayName, [string] $requiredDelegatedPermissions, [string]$requiredApplicationPermissions, $servicePrincipal)
{
    # If we are passed the service principal we use it directly, otherwise we find it from the display name (which might not be unique)
    if ($servicePrincipal)
    {
        $sp = $servicePrincipal
    }
    else
    {
        $sp = Get-MgServicePrincipal -Filter "DisplayName eq '$applicationDisplayName'"
    }
    $appid = $sp.AppId
    $requiredAccess = New-Object Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess
    $requiredAccess.ResourceAppId = $appid 
    $requiredAccess.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Graph.PowerShell.Models.MicrosoftGraphResourceAccess]

    # $sp.Oauth2Permissions | Select Id,AdminConsentDisplayName,Value: To see the list of all the Delegated permissions for the application:
    if ($requiredDelegatedPermissions)
    {
        AddResourcePermission $requiredAccess -exposedPermissions $sp.Oauth2PermissionScopes -requiredAccesses $requiredDelegatedPermissions -permissionType "Scope"
    }
    
    # $sp.AppRoles | Select Id,AdminConsentDisplayName,Value: To see the list of all the Application permissions for the application
    if ($requiredApplicationPermissions)
    {
        AddResourcePermission $requiredAccess -exposedPermissions $sp.AppRoles -requiredAccesses $requiredApplicationPermissions -permissionType "Role"
    }
    return $requiredAccess
}


Function UpdateLine([string] $line, [string] $value)
{
    $index = $line.IndexOf(':')
    $lineEnd = ''

    if($line[$line.Length - 1] -eq ','){   $lineEnd = ',' }
    
    if ($index -ige 0)
    {
        $line = $line.Substring(0, $index+1) + " " + '"' + $value+ '"' + $lineEnd
    }
    return $line
}

Function UpdateTextFile([string] $configFilePath, [System.Collections.HashTable] $dictionary)
{
    $lines = Get-Content $configFilePath
    $index = 0
    while($index -lt $lines.Length)
    {
        $line = $lines[$index]
        foreach($key in $dictionary.Keys)
        {
            if ($line.Contains($key))
            {
                $lines[$index] = UpdateLine $line $dictionary[$key]
            }
        }
        $index++
    }

    Set-Content -Path $configFilePath -Value $lines -Force
}

Function ReplaceInLine([string] $line, [string] $key, [string] $value)
{
    $index = $line.IndexOf($key)
    if ($index -ige 0)
    {
        $index2 = $index+$key.Length
        $line = $line.Substring(0, $index) + $value + $line.Substring($index2)
    }
    return $line
}

Function ReplaceInTextFile([string] $configFilePath, [System.Collections.HashTable] $dictionary)
{
    $lines = Get-Content $configFilePath
    $index = 0
    while($index -lt $lines.Length)
    {
        $line = $lines[$index]
        foreach($key in $dictionary.Keys)
        {
            if ($line.Contains($key))
            {
                $lines[$index] = ReplaceInLine $line $key $dictionary[$key]
            }
        }
        $index++
    }

    Set-Content -Path $configFilePath -Value $lines -Force
}
<#.Description
   This function creates a new Azure AD scope (OAuth2Permission) with default and provided values
#>  
Function CreateScope( [string] $value, [string] $userConsentDisplayName, [string] $userConsentDescription, [string] $adminConsentDisplayName, [string] $adminConsentDescription)
{
    $scope = New-Object Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope
    $scope.Id = New-Guid
    $scope.Value = $value
    $scope.UserConsentDisplayName = $userConsentDisplayName
    $scope.UserConsentDescription = $userConsentDescription
    $scope.AdminConsentDisplayName = $adminConsentDisplayName
    $scope.AdminConsentDescription = $adminConsentDescription
    $scope.IsEnabled = $true
    $scope.Type = "User"
    return $scope
}

<#.Description
   This function creates a new Azure AD AppRole with default and provided values
#>  
Function CreateAppRole([string] $types, [string] $name, [string] $description)
{
    $appRole = New-Object Microsoft.Graph.PowerShell.Models.MicrosoftGraphAppRole
    $appRole.AllowedMemberTypes = New-Object System.Collections.Generic.List[string]
    $typesArr = $types.Split(',')
    foreach($type in $typesArr)
    {
        $appRole.AllowedMemberTypes += $type;
    }
    $appRole.DisplayName = $name
    $appRole.Id = New-Guid
    $appRole.IsEnabled = $true
    $appRole.Description = $description
    $appRole.Value = $name;
    return $appRole
}

Function ConfigureApplications
{
    <#.Description
       This function creates the Azure AD applications for the sample in the provided Azure AD tenant and updates the
       configuration files in the client and service project  of the visual studio solution (App.Config and Web.Config)
       so that they are consistent with the Applications parameters
    #> 
    
    if (!$azureEnvironmentName)
    {
        $azureEnvironmentName = "Global"
    }

    # Connect to the Microsoft Graph API, non-interactive is not supported for the moment (Oct 2021)
    Write-Host "Connecting Microsoft Graph"
    if ($tenantId -eq "") {
        Connect-MgGraph -Scopes "Application.ReadWrite.All" -Environment $azureEnvironmentName
        $tenantId = (Get-MgContext).TenantId
    }
    else {
        Connect-MgGraph -TenantId $tenantId -Scopes "Application.ReadWrite.All" -Environment $azureEnvironmentName
    }
    

   # Create the DownstreamAPI AAD application
   Write-Host "Creating the AAD application (msal-react-downstream)"
   
   # create the application 
   $DownstreamAPIAadApplication = New-MgApplication -DisplayName "msal-react-downstream" `
                                                             -Web `
                                                             @{ `
                                                                 HomePageUrl = "http://localhost:7000/api"; `
                                                               } `
                                                              -SignInAudience AzureADMyOrg `
                                                             #end of command
    $DownstreamAPIIdentifierUri = 'api://'+$DownstreamAPIAadApplication.AppId
    Update-MgApplication -ApplicationId $DownstreamAPIAadApplication.Id -IdentifierUris @($DownstreamAPIIdentifierUri)
    
    # create the service principal of the newly created application 
    $currentAppId = $DownstreamAPIAadApplication.AppId
    $DownstreamAPIServicePrincipal = New-MgServicePrincipal -AppId $currentAppId -Tags {WindowsAzureActiveDirectoryIntegratedApp}

    # add the user running the script as an app owner if needed
    $owner = Get-MgApplicationOwner -ApplicationId $DownstreamAPIAadApplication.Id
    if ($owner -eq $null)
    { 
        New-MgApplicationOwnerByRef -ApplicationId $DownstreamAPIAadApplication.Id  -BodyParameter = @{"@odata.id" = "htps://graph.microsoft.com/v1.0/directoryObjects/$user.ObjectId"}
        Write-Host "'$($user.UserPrincipalName)' added as an application owner to app '$($DownstreamAPIServicePrincipal.DisplayName)'"
    }
    
    # rename the user_impersonation scope if it exists to match the readme steps or add a new scope
       
    # delete default scope i.e. User_impersonation
    # Alex: the scope deletion doesn't work - see open issue - https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/1054
    $scopes = New-Object System.Collections.Generic.List[Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope]
    $scope = $DownstreamAPIAadApplication.Api.Oauth2PermissionScopes | Where-Object { $_.Value -eq "User_impersonation" }
    
    if($scope -ne $null)
    {    
        # disable the scope
        $scope.IsEnabled = $false
        $scopes.Add($scope)
        Update-MgApplication -ApplicationId $DownstreamAPIAadApplication.Id -Api @{Oauth2PermissionScopes = @($scopes)}

        # clear the scope
        Update-MgApplication -ApplicationId $DownstreamAPIAadApplication.Id -Api @{Oauth2PermissionScopes = @()}
    }

    $scopes = New-Object System.Collections.Generic.List[Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope]
    $scope = CreateScope -value access_downstream_as_user  `
    -userConsentDisplayName "Access msal-react-downstream"  `
    -userConsentDescription "Allow the application to access msal-react-downstream on your behalf."  `
    -adminConsentDisplayName "Access msal-react-downstream"  `
    -adminConsentDescription "Allows the app to have the same access to information in the directory on behalf of the signed-in user."
            
    $scopes.Add($scope)
    
    # add/update scopes
    Update-MgApplication -ApplicationId $DownstreamAPIAadApplication.Id -Api @{Oauth2PermissionScopes = @($scopes)}
    Write-Host "Done creating the DownstreamAPI application (msal-react-downstream)"

    # URL of the AAD application in the Azure portal
    # Future? $DownstreamAPIPortalUrl = "https://portal.azure.com/#@"+$tenantName+"/blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Overview/appId/"+$DownstreamAPIAadApplication.AppId+"/objectId/"+$DownstreamAPIAadApplication.ObjectId+"/isMSAApp/"
    $DownstreamAPIPortalUrl = "https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/CallAnAPI/appId/"+$DownstreamAPIAadApplication.AppId+"/objectId/"+$DownstreamAPIAadApplication.ObjectId+"/isMSAApp/"
    Add-Content -Value "<tr><td>DownstreamAPI</td><td>$currentAppId</td><td><a href='$DownstreamAPIPortalUrl'>msal-react-downstream</a></td></tr>" -Path createdApps.html

   # Create the MiddletierAPI AAD application
   Write-Host "Creating the AAD application (msal-react-middletier)"
   # Get a 6 months application key for the MiddletierAPI Application
   $fromDate = [DateTime]::Now;
   $key = CreateAppKey -fromDate $fromDate -durationInMonths 6
   
   
   # create the application 
   $MiddletierAPIAadApplication = New-MgApplication -DisplayName "msal-react-middletier" `
                                                             -Web `
                                                             @{ `
                                                                 HomePageUrl = "http://localhost:5000/api"; `
                                                               } `
                                                              -SignInAudience AzureADMyOrg `
                                                             #end of command
    #add password to the application
    $pwdCredential = Add-MgApplicationPassword -ApplicationId $MiddletierAPIAadApplication.Id -PasswordCredential $key
    $MiddletierAPIAppKey = $pwdCredential.SecretText
    $MiddletierAPIIdentifierUri = 'api://'+$MiddletierAPIAadApplication.AppId
    Update-MgApplication -ApplicationId $MiddletierAPIAadApplication.Id -IdentifierUris @($MiddletierAPIIdentifierUri)
    
    # create the service principal of the newly created application 
    $currentAppId = $MiddletierAPIAadApplication.AppId
    $MiddletierAPIServicePrincipal = New-MgServicePrincipal -AppId $currentAppId -Tags {WindowsAzureActiveDirectoryIntegratedApp}

    # add the user running the script as an app owner if needed
    $owner = Get-MgApplicationOwner -ApplicationId $MiddletierAPIAadApplication.Id
    if ($owner -eq $null)
    { 
        New-MgApplicationOwnerByRef -ApplicationId $MiddletierAPIAadApplication.Id  -BodyParameter = @{"@odata.id" = "htps://graph.microsoft.com/v1.0/directoryObjects/$user.ObjectId"}
        Write-Host "'$($user.UserPrincipalName)' added as an application owner to app '$($MiddletierAPIServicePrincipal.DisplayName)'"
    }
    
    # rename the user_impersonation scope if it exists to match the readme steps or add a new scope
       
    # delete default scope i.e. User_impersonation
    # Alex: the scope deletion doesn't work - see open issue - https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/1054
    $scopes = New-Object System.Collections.Generic.List[Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope]
    $scope = $MiddletierAPIAadApplication.Api.Oauth2PermissionScopes | Where-Object { $_.Value -eq "User_impersonation" }
    
    if($scope -ne $null)
    {    
        # disable the scope
        $scope.IsEnabled = $false
        $scopes.Add($scope)
        Update-MgApplication -ApplicationId $MiddletierAPIAadApplication.Id -Api @{Oauth2PermissionScopes = @($scopes)}

        # clear the scope
        Update-MgApplication -ApplicationId $MiddletierAPIAadApplication.Id -Api @{Oauth2PermissionScopes = @()}
    }

    $scopes = New-Object System.Collections.Generic.List[Microsoft.Graph.PowerShell.Models.MicrosoftGraphPermissionScope]
    $scope = CreateScope -value access_middletier_as_user  `
    -userConsentDisplayName "Access msal-react-middletier"  `
    -userConsentDescription "Allow the application to access msal-react-middletier on your behalf."  `
    -adminConsentDisplayName "Access msal-react-middletier"  `
    -adminConsentDescription "Allows the app to have the same access to information in the directory on behalf of the signed-in user."
            
    $scopes.Add($scope)
    
    # add/update scopes
    Update-MgApplication -ApplicationId $MiddletierAPIAadApplication.Id -Api @{Oauth2PermissionScopes = @($scopes)}
    Write-Host "Done creating the MiddletierAPI application (msal-react-middletier)"

    # URL of the AAD application in the Azure portal
    # Future? $MiddletierAPIPortalUrl = "https://portal.azure.com/#@"+$tenantName+"/blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Overview/appId/"+$MiddletierAPIAadApplication.AppId+"/objectId/"+$MiddletierAPIAadApplication.ObjectId+"/isMSAApp/"
    $MiddletierAPIPortalUrl = "https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/CallAnAPI/appId/"+$MiddletierAPIAadApplication.AppId+"/objectId/"+$MiddletierAPIAadApplication.ObjectId+"/isMSAApp/"
    Add-Content -Value "<tr><td>MiddletierAPI</td><td>$currentAppId</td><td><a href='$MiddletierAPIPortalUrl'>msal-react-middletier</a></td></tr>" -Path createdApps.html
    $requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess]

    
    # Add Required Resources Access (from 'MiddletierAPI' to 'DownstreamAPI')
    Write-Host "Getting access from 'MiddletierAPI' to 'DownstreamAPI'"
    $requiredPermissions = GetRequiredPermissions -applicationDisplayName "msal-react-downstream" `
        -requiredDelegatedPermissions "access_downstream_as_user" `
    

    $requiredResourcesAccess.Add($requiredPermissions)
    Update-MgApplication -ApplicationId $MiddletierAPIAadApplication.Id -RequiredResourceAccess $requiredResourcesAccess
    Write-Host "Granted permissions."

   # Create the spa AAD application
   Write-Host "Creating the AAD application (msal-react-spa)"
   
   # create the application 
   $spaAadApplication = New-MgApplication -DisplayName "msal-react-spa" `
                                                   -Spa `
                                                   @{ `
                                                       RedirectUris = "http://localhost:3000/"; `
                                                     } `
                                                    -SignInAudience AzureADMyOrg `
                                                   #end of command
    $tenantName = (Get-MgApplication -ApplicationId $spaAadApplication.Id).PublisherDomain
    Update-MgApplication -ApplicationId $spaAadApplication.Id -IdentifierUris @("https://$tenantName/msal-react-spa")
    
    # create the service principal of the newly created application 
    $currentAppId = $spaAadApplication.AppId
    $spaServicePrincipal = New-MgServicePrincipal -AppId $currentAppId -Tags {WindowsAzureActiveDirectoryIntegratedApp}

    # add the user running the script as an app owner if needed
    $owner = Get-MgApplicationOwner -ApplicationId $spaAadApplication.Id
    if ($owner -eq $null)
    { 
        New-MgApplicationOwnerByRef -ApplicationId $spaAadApplication.Id  -BodyParameter = @{"@odata.id" = "htps://graph.microsoft.com/v1.0/directoryObjects/$user.ObjectId"}
        Write-Host "'$($user.UserPrincipalName)' added as an application owner to app '$($spaServicePrincipal.DisplayName)'"
    }
    Write-Host "Done creating the spa application (msal-react-spa)"

    # URL of the AAD application in the Azure portal
    # Future? $spaPortalUrl = "https://portal.azure.com/#@"+$tenantName+"/blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/Overview/appId/"+$spaAadApplication.AppId+"/objectId/"+$spaAadApplication.ObjectId+"/isMSAApp/"
    $spaPortalUrl = "https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/CallAnAPI/appId/"+$spaAadApplication.AppId+"/objectId/"+$spaAadApplication.ObjectId+"/isMSAApp/"
    Add-Content -Value "<tr><td>spa</td><td>$currentAppId</td><td><a href='$spaPortalUrl'>msal-react-spa</a></td></tr>" -Path createdApps.html
    $requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Graph.PowerShell.Models.MicrosoftGraphRequiredResourceAccess]

    
    # Add Required Resources Access (from 'spa' to 'MiddletierAPI')
    Write-Host "Getting access from 'spa' to 'MiddletierAPI'"
    $requiredPermissions = GetRequiredPermissions -applicationDisplayName "msal-react-middletier" `
        -requiredDelegatedPermissions "access_middletier_as_user" `
    

    $requiredResourcesAccess.Add($requiredPermissions)
    Update-MgApplication -ApplicationId $spaAadApplication.Id -RequiredResourceAccess $requiredResourcesAccess
    Write-Host "Granted permissions."

    # Configure known client applications for MiddletierAPI 
    Write-Host "Configure known client applications for the 'MiddletierAPI'"
    $knowApplications = New-Object System.Collections.Generic.List[System.String]
    $knowApplications.Add($spaAadApplication.AppId)
    Update-MgApplication -ApplicationId $MiddletierAPIAadApplication.Id -Api @{KnownClientApplications = $knowApplications}
    Write-Host "Configured."
    
    # Update config file for 'DownstreamAPI'
    $configFile = $pwd.Path + "\..\DownstreamAPI\config.json"
    $dictionary = @{ "clientID" = $DownstreamAPIAadApplication.AppId;"tenantID" = $tenantId };

    Write-Host "Updating the sample code ($configFile)"

    UpdateTextFile -configFilePath $configFile -dictionary $dictionary
    
    # Update config file for 'middletierAPI'
    $configFile = $pwd.Path + "\..\MiddletierAPI\config.json"
    $dictionary = @{ "clientID" = $middletierAPIAadApplication.AppId;"tenantID" = $tenantId;"clientSecret" = $middletierAPIAppKey };

    Write-Host "Updating the sample code ($configFile)"

    UpdateTextFile -configFilePath $configFile -dictionary $dictionary
    
    # Update config file for 'MiddletierAPI'
    $configFile = $pwd.Path + "\..\MiddletierAPI\config.json"
    $dictionary = @{ "Enter_the_Web_Api_Scope_Here" = ("api://"+$DownstreamAPIAadApplication.AppId+"/access_as_user") };

    Write-Host "Updating the sample code ($configFile)"

    ReplaceInTextFile -configFilePath $configFile -dictionary $dictionary
    
    # Update config file for 'spa'
    $configFile = $pwd.Path + "\..\SPA\src\authConfig.js"
    $dictionary = @{ "Enter_the_Application_Id_Here" = $spaAadApplication.AppId;"Enter_the_Tenant_Info_Here" = $tenantId;"Enter_the_Web_Api_Scope_Here" = ("api://"+$MiddletierAPIAadApplication.AppId+"/access_as_user") };

    Write-Host "Updating the sample code ($configFile)"

    ReplaceInTextFile -configFilePath $configFile -dictionary $dictionary
    Write-Host -ForegroundColor Green "------------------------------------------------------------------------------------------------" 
    Write-Host "IMPORTANT: Please follow the instructions below to complete a few manual step(s) in the Azure portal":
    Write-Host "- For DownstreamAPI"
    Write-Host "  - Navigate to $DownstreamAPIPortalUrl"
    Write-Host "  - Navigate to the Manifest and set 'accessTokenAcceptedVersion' to '2' instead of 'null'" -ForegroundColor Red 
    Write-Host "  - Create a new conditional access policy as described in the sample's README" -ForegroundColor Red 
    Write-Host "- For MiddletierAPI"
    Write-Host "  - Navigate to $MiddletierAPIPortalUrl"
    Write-Host "  - Navigate to the Manifest and set 'accessTokenAcceptedVersion' to '2' instead of 'null'" -ForegroundColor Red 
    Write-Host "- For spa"
    Write-Host "  - Navigate to $spaPortalUrl"
    Write-Host "  - Navigate to the Manifest page, find the 'replyUrlsWithType' section and change the type of redirect URI to 'Spa'" -ForegroundColor Red 
    Write-Host -ForegroundColor Green "------------------------------------------------------------------------------------------------" 
       if($isOpenSSL -eq 'Y')
    {
        Write-Host -ForegroundColor Green "------------------------------------------------------------------------------------------------" 
        Write-Host "You have generated certificate using OpenSSL so follow below steps: "
        Write-Host "Install the certificate on your system from current folder."
        Write-Host -ForegroundColor Green "------------------------------------------------------------------------------------------------" 
    }
    Add-Content -Value "</tbody></table></body></html>" -Path createdApps.html  
}

# Pre-requisites
if ($null -eq (Get-Module -ListAvailable -Name "Microsoft.Graph.Applications")) {
    Install-Module "Microsoft.Graph.Applications" -Scope CurrentUser 
}

Import-Module Microsoft.Graph.Applications

Set-Content -Value "<html><body><table>" -Path createdApps.html
Add-Content -Value "<thead><tr><th>Application</th><th>AppId</th><th>Url in the Azure portal</th></tr></thead><tbody>" -Path createdApps.html

$ErrorActionPreference = "Stop"

# Run interactively (will ask you for the tenant ID)
ConfigureApplications -tenantId $tenantId -environment $azureEnvironmentName

Write-Host "Disconnecting from tenant"
Disconnect-MgGraph