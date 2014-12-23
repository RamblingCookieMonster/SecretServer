Function Get-SSFolder
{
    <#
    .SYNOPSIS
        Get details on folders from secret server

    .DESCRIPTION
        Get details on folders from secret server

    .PARAMETER Name
        Name to search for.  Accepts wildcards as '*'.

    .PARAMETER Id
        Id to search for.  Accepts wildcards as '*'.

    .PARAMETER FolderPath
        Full folder path to search for.  Accepts wildcards as '*'

    .PARAMETER Uri
        uri for your win auth web service.

    .PARAMETER WebServiceProxy
        Existing web service proxy from SecretServerConfig variable

    .EXAMPLE
        Get-SSFolder -FolderPath "*Systems*Service Accounts"

    .EXAMPLE
        Get-SSFolder -Id 55

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [string]$Name = '*',
        [string]$Id = '*',
        [string]$FolderPath = '*',
        [string]$Uri = $SecretServerConfig.Uri,
        [System.Web.Services.Protocols.SoapHttpClientProtocol]$WebServiceProxy = $SecretServerConfig.Proxy
    )
    
    if(-not $WebServiceProxy.whoami)
    {
        Write-Warning "Your SecretServerConfig proxy does not appear connected.  Creating new connection to $uri"
        try
        {
            $WebServiceProxy = New-WebServiceProxy -uri $Uri -UseDefaultCredential -ErrorAction stop
        }
        catch
        {
            Throw "Error creating proxy for $Uri`: $_"
        }
    }
    
    #Find all folders, filter on name.  We need all to build the folderpath tree
        $Folders = @( $WebServiceProxy.SearchFolders($null).Folders )

    #Loop through folders.  Get the full folder path
        foreach($Folder in $Folders)
        {
            $FolderName = $Folder.Name
            $FolderId = $Folder.Id
            $ParentId = $Folder.ParentFolderId
            $FullPath = "$FolderName"
            While($ParentID -notlike -1)
            {
                $WorkingFolder = $Folders | Where-Object {$_.Id -like $ParentId}
                $WorkingFolderName = $WorkingFolder.Name
                
                $FullPath = $WorkingFolderName, $FullPath -join "\"

                $ParentID = $WorkingFolder.ParentFolderId
            }
            $Folder | Add-Member -MemberType NoteProperty -Name "FolderPath" -Value $FullPath -force
        }
        
    #Filter on the specified parameters
        $Folders = $Folders | Where-Object {$_.FolderPath -like $FolderPath -and $_.Name -like $Name -and $_.Id -like $Id}

    $Folders

}