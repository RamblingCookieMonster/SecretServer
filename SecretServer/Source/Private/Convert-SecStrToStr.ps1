#Pass in a secure string.  For example, $Credential.Password
function Convert-SecStrToStr {
    [CmdletBinding()]
    param($secstr)
    try {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secstr)
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    catch {
        Write-Error "Failed to convert secure string to string: $_"
    }
}