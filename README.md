Secret Server PowerShell Module
=============

This is a PowerShell module for working with Thycotic Secret Server's web services.  If you use this module, check in every so often, there will be regular updates.

This is a quick and dirty implementation based on my environment's configuration.  Contributions to improve this would be more than welcome!

Some caveats:

 * We do not go out of the way to cover a variety of templates or customizations to templates.  Contributions welcome.  This is on my list but low priority.
 * A number of shortcuts have been taken given that this is a fast publish.  Addressing these is on my list.
   * Limited testing, limited validation of edge case scenarios
   * Limited error handling
   * Limited comment based help and examples (some may be outdated)
   * Limited explanation for configuring your environment to use functions that rely on T-SQL.

#UPDATES 03/24/2016 by Ryan Bushe

  * NEW: Connect-SecretServer Prompts you for credentials and includes support for connecting with RADIUS
  * NEW: Copy-SSPassword Using Get-Secret as the backend will prompt the user to select a specific secret and copy the password to the users clip board
  * UPDATE: Added use of Token when supplied or in the SecretServerConfig for all functions using Secret Server's web services
  * UPDATE: Restructured the layout of the functions and used [ConvertTo-Module](https://github.com/martin9700/ConvertTo-Module) to build the module file for faster loading
  * UPDATE: Made settings final include the current user name for use by multiple users
  * UPDATE: Moved file initialization into Get-SecretServerConfig
  * UPDATE: Moved proxy initialization into Connect-SecretServer

#Functionality

Search for secrets without triggering an audit:
  * ![Search for secrets without triggering an audit](/Media/Get-Secret.png)

Extract Secure String password and PSCredential credential object from secrets:
  * ![Extract Secure String password and PSCredential credential object from secrets](/Media/Get-SecretCred.png)

Find folders:
  * ![List out folders](/Media/Get-Folder.png)

Find templates:
  * ![Find templates](/Media/Get-Template.png)

Create new secrets:
  * ![Create new secrets](/Media/New-Secret.png)

Change existing secrets:
  * ![Change existing secrets](/Media/Set-Secret.png)

Find permissions for a secret:
  * ![Find permissions for a secret](/Media/Get-SecretPermission.png)

List secret audit activity:
  * ![List secret audit activity](/Media/Get-SecretAudit.png)

Get Secret Activity directly from the database:
  * ![Get Secret Activity directly from the database](/Media/Get-SecretActivity.png)

Get connected:
  * ![Get connected](/Media/GetConnected.png)

#Prerequisites

 * You must be using Windows PowerShell 3 or later on the system running this module
 * You must enable Secret Server Web Services ahead of time.  See [product documentation](http://thycotic.com/products/secret-server/support-2/) for instructions.
 * You must enable Integrated Windows Authentication for Secret Server.  This may change.  See [product documentation](http://support.thycotic.com/kb/a90/setting-up-integrated-windows-authentication.aspx) for instructions.
 * We serialize a default Uri and proxy to SecretServerConfig.xml in the module path - you must have access to that path for this functionality
 * The account running these functions must have appropriate access to Secret Server
 * For the T-SQL commands, I assume you can delegate privileges and create a secure way to invoke these.  Consider running these from a constrained, delegated endpoint to avoid unnecessary privileges in the Secret Server database.
 * Module folder downloaded, unblocked, extracted, available to import

#Instructions

    #One time setup:
        #Download the repository
        #Unblock the zip file
        #Extract SecretServer folder to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)

    #Each PowerShell session
        Import-Module SecretServer  #Alternatively, Import-Module "\\Path\To\SecretServer"

    #List commands in the module
        Get-Command -Module SecretServer

    #Get help for a command
        Get-Help New-SSConnection -Full

    #Optional one time step: Set default Uri, create default proxy
        Set-SecretServerConfig -Uri https://FQDN.TO.SECRETSERVER/winauthwebservices/sswinauthwebservice.asmx
        New-SSConnection #Uses Uri we just set by default

    #Get help for Get-Secret
        Get-Help Get-Secret -Full

    #List a summary of all secrets
        Get-Secret

    #Convert stored secret to a credential object you can use in a variety of scenarios
        $Credential = (Get-Secret -SearchTerm SVC-WebCommander -as Credential ).Credential
        $Credential

        <#
            UserName : My.Domain\SVC-WebCommander
            Password : System.Security.SecureString
        #>

    #List commands that directly hit the SQL database
        Get-Command -Module SecretServer -ParameterName ServerInstance |
            Where {$_.Name -notlike "*SecretServerConfig"}

#Aside

On an aside, if you don't have a password management solution in place, definitely take a look at [Secret Server](http://thycotic.com/products/secret-server/compare-installed-editions/).

I've been impressed with the product, documentation, and support.  It's one of those products that just works, and works well.  If you're a non-profit, you'll save a bit...

Project Status, 1/17/2016: I no longer work with or have access to Secret Server. Feel free to fork this or use it as needed, but there will likely be no further development, barring external contributions.
