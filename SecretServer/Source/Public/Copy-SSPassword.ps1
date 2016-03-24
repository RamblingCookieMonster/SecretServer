function Copy-SSPassword {
    <#
    .SYNOPSIS
        Copy password to clipboard from secret server.

    .DESCRIPTION
        Copy password to clipboard from secret server.
        
    .PARAMETER SearchTerm
        String to search for.  Accepts wildcards as '*'.

    .PARAMETER SecretId
        SecretId to search for.

    .FUNCTIONALITY
        Secret Server
    #>
    [cmdletbinding()]
    param(
        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    Position=0)]
        [string]$SearchTerm = $null,

        [Parameter( Mandatory=$false,
                    ValueFromPipelineByPropertyName=$true,
                    ValueFromRemainingArguments=$false,
                    Position=1)]
        [int]$SecretId = $null
    )
    function Clippy{
        param(
            [Parameter(ValueFromPipeline=$true)]
            [string]$Clip
        )
        Process{
            [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
            [Windows.Forms.Clipboard]::SetDataObject($Clip, $true)
        }
    }

    if($SearchTerm){
        $Secret = Get-Secret -SearchTerm $SearchTerm | Out-GridView -OutputMode Single
        (Get-Secret -SecretId $Secret.SecretId -As Credential).Credential.GetnetworkCredential().Password | Clippy
        Write-Verbose "Password now on clipboard for:" -Verbose
        $Secret
    }
    elseif($SecretId){
        $Secret = Get-Secret -SecretId $SecretId -As Credential
        $Secret.Credential.GetnetworkCredential().Password | Clippy
        Write-Verbose "Password now on clipboard for:" -Verbose
        $Secret
    }
}

#publish
New-Alias -Name Copy-SecertServerPassword -Value Copy-SSPassword -Force
New-Alias -Name Copy-SecertServerPass -Value Copy-SSPassword -Force
#endpublish