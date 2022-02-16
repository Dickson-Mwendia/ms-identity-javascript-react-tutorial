---
page_type: sample
name: Handling Conditional Access challenges in an Azure AD protected Node.js web API calling another protected Node.js web API on behalf of a user
services: active-directory
platforms: dotnet
urlFragment: ms-identity-javascript-react-tutorial
description: 
---

# Handling Conditional Access challenges in an Azure AD protected Node.js web API calling another protected Node.js web API on behalf of a user

[![Build status](https://identitydivision.visualstudio.com/IDDP/_apis/build/status/AAD%20Samples/.NET%20client%20samples/ASP.NET%20Core%20Web%20App%20tutorial)](https://identitydivision.visualstudio.com/IDDP/_build/latest?definitionId=819)

Table Of Contents

* [Scenario](#Scenario)
* [Prerequisites](#Prerequisites)
* [Setup the sample](#Setup-the-sample)
* [Troubleshooting](#Troubleshooting)
* [Using the sample](#Using-the-sample)
* [About the code](#About-the-code)
* [How to deploy this sample to Azure](#How-to-deploy-this-sample-to-Azure)
* [Next Steps](#Next-Steps)
* [Contributing](#Contributing)
* [Learn More](#Learn-More)

## Scenario

Scenario text in markdown format + scenario diagram


![Scenario Image](./ReadmeFiles/sign-in.png)

 Some additional notes, will be displayed right after image

## Prerequisites

if this text is empty, the default text will be used from PreRequirementsChapterGenerator.t4


## Setup the sample

### Step 1: Clone or download this repository

From your shell or command line:

```console
    git clone https://github.com/Azure-Samples/ms-identity-javascript-react-tutorial.git
```

or download and extract the repository .zip file.

>:warning: To avoid path length limitations on Windows, we recommend cloning into a directory near the root of your drive.

### Step 2: Install project dependencies


```console
    cd 6-AdvancedScenarios\1-call-api-obo
    npm install
```

```console
    cd 6-AdvancedScenarios\1-call-api-obo
    npm install
```

```console
    cd 6-AdvancedScenarios\1-call-api-obo
    npm install
```

### Step 3: Application Registration

There are three projects in this sample. Each needs to be separately registered in your Azure AD tenant. To register these projects:

You can use [manual steps](#Manual-steps)

**OR**

### Run automation scripts

* use PowerShell scripts that:
  * **automatically** creates the Azure AD applications and related objects (passwords, permissions, dependencies) for you.
  * modify the projects' configuration files.

  <details>
   <summary>Expand this section if you want to use this automation:</summary>

      :warning: If you have never used **Azure AD Powershell** before, we recommend you go through the [App Creation Scripts](./AppCreationScripts/AppCreationScripts.md) once to ensure that your environment is prepared correctly for this step.

    1. On Windows, run PowerShell as **Administrator** and navigate to the root of the cloned directory
    1. If you have never used Azure AD Powershell before, we recommend you go through the [App Creation Scripts](./AppCreationScripts/AppCreationScripts.md) once to ensure that your environment is prepared correctly for this step.
    1. In PowerShell run:

       ```PowerShell
       Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
       ```

    1. Run the script to create your Azure AD application and configure the code of the sample application accordingly.
    1. For interactive process - in PowerShell run:

       ```PowerShell
       cd .\AppCreationScripts\
       .\Configure.ps1 -TenantId "[Optional] - your tenant id" -Environment "[Optional] - Azure environment, defaults to 'Global'"
       ```

       > Other ways of running the scripts are described in [App Creation Scripts](./AppCreationScripts/AppCreationScripts.md)
       > The scripts also provide a guide to automated application registration, configuration and removal which can help in your CI/CD scenarios.

  </details>

### Manual Steps

 > Note: skip this part if you've just used Automation steps

* follow the steps below for manually register your apps
  1. Sign in to the [Azure portal](https://portal.azure.com).
  1. If your account is present in more than one Azure AD tenant, select your profile at the top right corner in the menu on top of the page, and then **switch directory** to change your portal session to the desired Azure AD tenant.
                      
#### Register the DownstreamAPI app (msal-react-downstream)

  **For more information, visit** [Register Application AAD](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)

  1. Navigate to the [Azure portal](https://portal.azure.com) and select the **Azure AD** service.
  1. Select the **App Registrations** blade on the left, then select **New registration**.
  1. In the **Register an application page** that appears, enter your application's registration information:
     * In the **Name** section, enter a meaningful application name that will be displayed to users of the app, for example `msal-react-downstream`.
  1. Under **Supported account types**, select **Accounts in this organizational directory only**
  1. Click **Register** to create the application.
  1. In the app's registration screen, find and note the **Application (client) ID**. You use this value in your app's configuration file(s) later in your code.

  1. Click **Save** to save your changes.
      
  1. In the app's registration screen, select the **Expose an API** blade to the left to open the page where you can declare the parameters to expose this app as an API for which client applications can obtain [access tokens](https://docs.microsoft.com/azure/active-directory/develop/access-tokens) for. The first thing that we need to do is to declare the unique [resource](https://docs.microsoft.com/azure/active-directory/develop/v2-oauth2-auth-code-flow) URI that the clients will be using to obtain access tokens for this API. To declare an resource URI, follow the following steps:
      * Select `Set` next to the **Application ID URI** to generate a URI that is unique for this app.
      * For this sample, accept the proposed Application ID URI (`api://{clientId}`) by selecting **Save**.
  1. All APIs have to publish a minimum of one [scope](https://docs.microsoft.com/azure/active-directory/develop/v2-oauth2-auth-code-flow#request-an-authorization-code) for the client's to obtain an access token successfully. To publish a scope, follow these steps:
        * Select **Add a scope** button open the **Add a scope** screen and Enter the values as indicated below:
          * For **Scope name**, use `access_as_user`.
          * Select **Admins and users** options for **Who can consent?**.
          * For **Admin consent display name** type `Access msal-react-downstream`.
          * For **Admin consent description** type `Allows the app to access msal-react-downstream as the signed-in user.`
          * For **User consent display name** type `Access msal-react-downstream`.
          * For **User consent description** type `Allow the application to access msal-react-downstream on your behalf.`
          * Keep **State** as **Enabled**.
          * Select the **Add scope** button on the bottom to save this scope.
     1. Select the `Manifest` blade on the left.
     * Set `accessTokenAcceptedVersion` property to **2**.
     * Click on **Save**.
   
##### Configure the DownstreamAPI app (msal-react-downstream) to use your app registration

  Open the project in your IDE (like Visual Studio or Visual Studio Code) to configure the code.

   > In the steps below, "ClientID" is the same as "Application ID" or "AppId".
   
  1. Open the `DownstreamAPI\config.json` file.
       1. Find the key `clientID` and replace the existing value with the application ID (clientId) of `msal-react-downstream` app copied from the Azure portal.
       1. Find the key `tenantID` and replace the existing value with your Azure AD tenant ID.
          
#### Register the MiddletierAPI app (msal-react-middletier)

  **For more information, visit** [Register Application AAD](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)

  1. Navigate to the [Azure portal](https://portal.azure.com) and select the **Azure AD** service.
  1. Select the **App Registrations** blade on the left, then select **New registration**.
  1. In the **Register an application page** that appears, enter your application's registration information:
     * In the **Name** section, enter a meaningful application name that will be displayed to users of the app, for example `msal-react-middletier`.
  1. Under **Supported account types**, select **Accounts in this organizational directory only**
  1. Click **Register** to create the application.
  1. In the app's registration screen, find and note the **Application (client) ID**. You use this value in your app's configuration file(s) later in your code.

  1. Click **Save** to save your changes.
   
  1. In the app's registration screen, select the **Certificates & secrets** blade in the left to open the page where you can generate secrets and upload certificates.
  1. In the **Client secrets** section, select **New client secret**:
     * Type a key description (for instance `app secret`).
     * Select one of the available key durations (**6 months**, **12 months** or **Custom**) as per your security posture.
     * The generated key value will be displayed when you select the **Add** button. Copy and save the generated value for use in later steps.
     * You'll need this key later in your code's configuration files. This key value will not be displayed again, and is not retrievable by any other means, so make sure to note it from the Azure portal before navigating to any other screen or blade.

   1. In the app's registration screen, select the **API permissions** blade in the left to open the page where we add access to the APIs that your application needs.
      * Select the **Add a permission** button and then,
      * Ensure that the **My APIs** tab is selected.
      * In the list of APIs, select the API `msal-react-downstream`.
      * In the **Delegated permissions** section, select the **access_downstream_as_user** in the list. Use the search box if necessary.
      * Select the **Add permissions** button at the bottom.
   
  1. In the app's registration screen, select the **Expose an API** blade to the left to open the page where you can declare the parameters to expose this app as an API for which client applications can obtain [access tokens](https://docs.microsoft.com/azure/active-directory/develop/access-tokens) for. The first thing that we need to do is to declare the unique [resource](https://docs.microsoft.com/azure/active-directory/develop/v2-oauth2-auth-code-flow) URI that the clients will be using to obtain access tokens for this API. To declare an resource URI, follow the following steps:
      * Select `Set` next to the **Application ID URI** to generate a URI that is unique for this app.
      * For this sample, accept the proposed Application ID URI (`api://{clientId}`) by selecting **Save**.
  1. All APIs have to publish a minimum of one [scope](https://docs.microsoft.com/azure/active-directory/develop/v2-oauth2-auth-code-flow#request-an-authorization-code) for the client's to obtain an access token successfully. To publish a scope, follow these steps:
        * Select **Add a scope** button open the **Add a scope** screen and Enter the values as indicated below:
          * For **Scope name**, use `access_as_user`.
          * Select **Admins and users** options for **Who can consent?**.
          * For **Admin consent display name** type `Access msal-react-middletier`.
          * For **Admin consent description** type `Allows the app to access msal-react-middletier as the signed-in user.`
          * For **User consent display name** type `Access msal-react-middletier`.
          * For **User consent description** type `Allow the application to access msal-react-middletier on your behalf.`
          * Keep **State** as **Enabled**.
          * Select the **Add scope** button on the bottom to save this scope.
     1. Select the `Manifest` blade on the left.
     * Set `accessTokenAcceptedVersion` property to **2**.
     * Click on **Save**.
   
##### Configure the MiddletierAPI app (msal-react-middletier) to use your app registration

  Open the project in your IDE (like Visual Studio or Visual Studio Code) to configure the code.

   > In the steps below, "ClientID" is the same as "Application ID" or "AppId".
   
  1. Open the `MiddletierAPI\config.json` file.
       1. Find the key `Enter_the_Web_Api_Scope_Here` and replace the existing value with Scope.
          
#### Register the spa app (msal-react-spa)

  **For more information, visit** [Register Application AAD](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)

  1. Navigate to the [Azure portal](https://portal.azure.com) and select the **Azure AD** service.
  1. Select the **App Registrations** blade on the left, then select **New registration**.
  1. In the **Register an application page** that appears, enter your application's registration information:
     * In the **Name** section, enter a meaningful application name that will be displayed to users of the app, for example `msal-react-spa`.
  1. Under **Supported account types**, select **Accounts in this organizational directory only**
  1. Click **Register** to create the application.
  1. In the app's registration screen, find and note the **Application (client) ID**. You use this value in your app's configuration file(s) later in your code.

  1. Click **Save** to save your changes.
   1. In the app's registration screen, select the **API permissions** blade in the left to open the page where we add access to the APIs that your application needs.
      * Select the **Add a permission** button and then,
      * Ensure that the **My APIs** tab is selected.
      * In the list of APIs, select the API `msal-react-middletier`.
      * In the **Delegated permissions** section, select the **access_middletier_as_user** in the list. Use the search box if necessary.
      * Select the **Add permissions** button at the bottom.
   
##### Configure the spa app (msal-react-spa) to use your app registration

  Open the project in your IDE (like Visual Studio or Visual Studio Code) to configure the code.

   > In the steps below, "ClientID" is the same as "Application ID" or "AppId".
   
  1. Open the `SPA\src\authConfig.js` file.
       1. Find the key `Enter_the_Application_Id_Here` and replace the existing value with the application ID (clientId) of `msal-react-spa` app copied from the Azure portal.
       1. Find the key `Enter_the_Tenant_Info_Here` and replace the existing value with your Azure AD tenant ID.
       1. Find the key `Enter_the_Web_Api_Scope_Here` and replace the existing value with Scope.
   
#### Configure Known Client Applications for MiddletierAPI (msal-react-middletier)

   For a middle-tier web API (`msal-react-middletier`) to be able to call a downstream web API, the middle tier app needs to be granted the required permissions as well. However, since the middle-tier cannot interact with the signed-in user, it needs to be explicitly bound to the client app in its **Azure AD** registration. This binding merges the permissions required by both the client and the middle-tier web API and presents it to the end user in a single consent dialog. The user then consent to this combined set of permissions.

   To achieve this, you need to add the **Application Id** of the client app to the `knownClientApplications` property in the **manifest** of the web API. Here's how:

   1. In the [Azure portal](https://portal.azure.com), navigate to your `msal-react-middletier` app registration, and select the **Manifest** blade.
   1. In the manifest editor, change the `"knownClientApplications": []` line so that the array contains the Client ID of the client application (`msal-react-spa`) as an element of the array.
   
   For instance:

   ```json
       "knownClientApplications": ["ca8dca8d-f828-4f08-82f5-325e1a1c6428"],
   ```

   1. **Save** the changes to the manifest.
         
### Step 4: Running the sample




## Troubleshooting
<details>
 <summary>Expand for troubleshooting info</summary>
 
 If this field is empty, it will use the default part of TroubleshootingChapterGenerator.t4
</details>

## Using the sample

<details>
 <summary>Expand to see how to use the sample</summary>
 This field must be filled, no default exists
</details>


## About the code

<details>
 <summary>Expand the section</summary>
 if this field is empty, then default from Legacy/LegacyAboutTheCodeChapterGenerator.t4 will be used
</details>


## How to deploy this sample to Azure

<details>
 <summary>Expand the section</summary>
 This field must be filled with deployment steps, no default exists
</details>

## Next Steps

If this field is empty, then default will be used from NextStepsChapterGenerator.t4
 
## Contributing

If this field is empty, the default will be used from ContributingChapterGenerator.t4
 
## Learn More

If this field is empty, then default will be taken from LearnMoreChapterGenerator.t4
