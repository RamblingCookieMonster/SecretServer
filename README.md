Secret Server PowerShell Module
=============

This is a PowerShell module for working with Thycotic Secret Server's web services.

This is a fast publish, there will be a number of changes.  Some caveats:

 * We do not go out of the way to cover a variety of templates or customizations to templates.  Contributions welcome.  This is on my list but low priority.
 * A number of shortcuts have been taken given that this is a fast publish.  Addressing these is on my list.
   * Limited testing, limited validation of edge case scenarios
   * Limited error handling
   * Limited comment based help and examples (some may be outdated)

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

Get connected:
  * ![Get connected](/Media/GetConnected.png)

#Prerequisites
    
 * You must be using Windows PowerShell 3 or later on the system running this module
 * You must enable Secret Server Web Services ahead of time.  See [product documentation](http://thycotic.com/products/secret-server/support-2/) for instructions.
 * You must enable Integrated Windows Authentication for Secret Server.  This may change.  See [product documentation](http://support.thycotic.com/kb/a90/setting-up-integrated-windows-authentication.aspx) for instructions.
 * We serialize a default Uri and proxy to SecretServerConfig.xml in the module path - you must have access to that path for this functionality
 * The account running these functions must have appropriate access to Secret Server
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
        Get-Help Get-Secret -Full
        
    #Optional one time step: Set default Uri, create default proxy
        Set-SecretServerConfig -Uri https://FQDN.TO.SECRETSERVER/winauthwebservices/sswinauthwebservice.asmx
        New-SSConnection #Uses Uri we just set by default
        
    #List a summary of all secrets
        Get-Secret 
        
    #Convert stored secret to a credential object you can use in a variety of scenarios
        $Credential = (Get-Secret -SearchTerm SVC-WebCommander -as Credential ).Credential
        $Credential
        
        <#
            UserName : My.Domain\SVC-WebCommander
            Password : System.Security.SecureString
        #>
        
#Aside

On an aside, if you don't have a password management solution in place, definitely take a look at [Secret Server](http://thycotic.com/products/secret-server/compare-installed-editions/).

I've been impressed with the product, documentation, and support.  It's one of those products that just works, and works well.  If you're a non-profit, you'll save a bit...