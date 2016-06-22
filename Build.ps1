#requires -Module Configuration
[CmdletBinding()]
param(
    [Alias("PSPath")]
    [string]$Path = $PSScriptRoot,
    [string]$ModuleName = $(Split-Path $Path -Leaf),
    # The target framework for .net (for packages), with fallback versions
    # The default supports PS3:  "net40","net35","net20","net45"
    # To only support PS4, use:  "net45","net40","net35","net20"
    # To support PS2, you use:   "net35","net20"
    [string[]]$TargetFramework = @("net40","net35","net20","net45"),
    [switch]$Monitor,
    [Nullable[int]]$RevisionNumber = ${Env:APPVEYOR_BUILD_NUMBER}
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Write-Host "BUILDING: $ModuleName from $Path"

# The output path is just a temporary build location
$OutputPath = Join-Path $Path output
$null = mkdir $OutputPath -Force

# We expect the source for the module in a subdirectory called one of three things:
$SourcePath = "src", "source", ${ModuleName} | ForEach { Join-Path $Path $_ -Resolve -ErrorAction SilentlyContinue } | Select -First 1
if(!$SourcePath) {
    Write-Warning "This Build script expects a 'Source' or '$ModuleName' folder to be alongside it."
    throw "Can't find module source folder." 
}
$ManifestPath = Join-Path $SourcePath "${ModuleName}.psd1" -Resolve -ErrorAction SilentlyContinue
if(!$ManifestPath) {
    Write-Warning "This Build script expects a '${ModuleName}.psd1' in the '$SourcePath' folder."
    throw "Can't find module source files" 
}

# Figure out the new build version
    [Version]$Version = Get-Metadata $ManifestPath -PropertyName ModuleVersion

    # If the RevisionNumber is specified as ZERO, this is a release build ... 
    # If the RevisionNumber is not specified, this is a dev box build
    # If the RevisionNumber is specified, we assume this is a CI build
    if($RevisionNumber -ge 0) {
        # For CI builds we don't increment the build number
        $Build = if($Version.Build -le 0) { 0 } else { $Version.Build }
    } else {
        # For dev builds, assume we're working on the NEXT release
        $Build = if($Version.Build -le 0) { 1 } else { $Version.Build + 1}
    }

    if([string]::IsNullOrEmpty($RevisionNumber)) {
        $Version = New-Object Version $Version.Major, $Version.Minor, $Build
    } else {
        $Version = New-Object Version $Version.Major, $Version.Minor, $Build, $RevisionNumber
    }

# The release path is where the final module goes
$ReleasePath = Join-Path $Path $Version

Write-Verbose "OUTPUT Release Path: $ReleasePath"
if(Test-Path $ReleasePath) {
    Write-Verbose "       Clean up old build"
    Write-Verbose "DELETE $ReleasePath\"
    Remove-Item $ReleasePath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Verbose "DELETE $OutputPath\build.log"
    Remove-Item $OutputPath\build.log -Recurse -Force -ErrorAction SilentlyContinue
}

## Find dependency Package Files
$PackagesConfig = (Join-Path $Path packages.config)
if(Test-Path $PackagesConfig) {
    Write-Verbose "       Copying Packages"
    foreach($Package in ([xml](Get-Content $PackagesConfig)).packages.package) {
        $LibPath = "$ReleasePath\lib"
        $folder = Join-Path $Path "packages\$($Package.id)*"

        # The git NativeBinaries are special -- we need to copy all the "windows" binaries:
        if($Package.id -eq "LibGit2Sharp.NativeBinaries") {
            $targets = Join-Path $folder 'libgit2\windows'
            $LibPath = Join-Path $LibPath "NativeBinaries"
        } else {
            # Check for each TargetFramework, in order of preference, fall back to using the lib folder
            $targets = ($TargetFramework -replace '^','lib\') + 'lib' | ForEach-Object { Join-Path $folder $_ }
        }

        $PackageSource = Get-Item $targets -ErrorAction SilentlyContinue | Select -First 1 -Expand FullName
        if(!$PackageSource) {
            throw "Could not find a lib folder for $($Package.id) from package. You may need to run Setup.ps1"
        }

        Write-Verbose "robocopy $PackageSource $LibPath /E /NP /LOG+:'$OutputPath\build.log' /R:2 /W:15"
        $null = robocopy $PackageSource $LibPath /E /NP /LOG+:"$OutputPath\build.log" /R:2 /W:15
        if($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 1 -and $LASTEXITCODE -ne 3) {
            throw "Failed to copy Package $($Package.id) (${LASTEXITCODE}), see build.log for details"
        }
    }
}


## Copy PowerShell source Files
$ReleaseManifest = Join-Path $ReleasePath "${ModuleName}.psd1"


# if the Source folder has "Public" and optionally "Private" in it, then the psm1 must be assembled:
if(Test-Path (Join-Path $SourcePath Public) -Type Container){
    Write-Verbose "       Collating Module Source"
    $RootModule = Get-Metadata -Path $ManifestPath -PropertyName RootModule -ErrorAction SilentlyContinue
    if(!$RootModule) {
        $RootModule = Get-Metadata -Path $ManifestPath -PropertyName ModuleToProcess -ErrorAction SilentlyContinue
        if(!$RootModule) {
            $RootModule = "${ModuleName}.psm1"
        }
    }
    $null = mkdir $ReleasePath -Force
    $ReleaseModule = Join-Path $ReleasePath ${RootModule}
    Write-Verbose "       Setting content for $ReleaseModule"

    $FunctionsToExport = Join-Path $SourcePath Public\*.ps1 -Resolve | % { [System.IO.Path]::GetFileNameWithoutExtension($_) }
    Set-Content $ReleaseModule ((
        (Get-Content (Join-Path $SourcePath Private\*.ps1) -Raw) + 
        (Get-Content (Join-Path $SourcePath Public\*.ps1) -Raw)) -join "`r`n`r`n`r`n") -Encoding UTF8

    # If there are any folders that aren't Public, Private, Tests, or Specs ...
    $OtherFolders = Get-ChildItem $SourcePath -Directory -Exclude Public, Private, Tests, Specs
    # Then we need to copy everything in them
    Copy-Item $OtherFolders -Recurse -Destination $ReleasePath

    # Finally, we need to copy any files in the Source directory
    Get-ChildItem $SourcePath -File | 
        Where Name -ne $RootModule | 
        Copy-Item -Destination $ReleasePath
    

    Update-Manifest $ReleaseManifest -Property FunctionsToExport -Value $FunctionsToExport
} else {
    # Legacy modules just have "stuff" in the source folder and we need to copy all of it
    Write-Verbose "       Copying Module Source"
    Write-Verbose "COPY   $SourcePath\"
    $null = robocopy $SourcePath\  $ReleasePath /E /NP /LOG+:"$OutputPath\build.log" /R:2 /W:15
    if($LASTEXITCODE -ne 3) {
        throw "Failed to copy Module (${LASTEXITCODE}), see build.log for details"
    }
}

## Touch the PSD1 Version:
Write-Verbose "       Update Module Version"

Update-Metadata -Path $ReleaseManifest -PropertyName 'ModuleVersion' -Value $Version