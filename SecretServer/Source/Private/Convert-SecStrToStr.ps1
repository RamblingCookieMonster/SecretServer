#Pass in a secure string.  For example, $Credential.Password
function Convert-SecStrToStr
{
    [cmdletbinding()]
    param($secstr)
    Try
    {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secstr)
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    Catch
    {
        Write-Error "Failed to convert secure string to string: $_"
    }
}