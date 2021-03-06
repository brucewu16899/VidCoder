[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
  [string]$versionShort,
  [switch]$debugBuild = $false
)

. ./build_common.ps1

function ReplaceTokens($inputFile, $outputFile, $replacements) {
    $fileContent = Get-Content $inputFile

    foreach($key in $($replacements.keys)){
        $fileContent = $fileContent -replace ("%" + $key + "%"), $replacements[$key]
    }

    Set-Content $outputFile $fileContent
}

function CreateIssFile($version, $beta, $debugBuild) {
    $tokens = @{}

    if ($beta) {
        $appId = "VidCoder-Beta-x64"
    } else {
        $appId = "VidCoder-x64"
    }

    $tokens["version"] = $version
    $tokens["appId"] = $appId
    if ($beta) {
        $tokens["appName"] = "VidCoder Beta"
        $tokens["appNameNoSpace"] = "VidCoderBeta"
        $tokens["folderName"] = "VidCoder-Beta"
        $tokens["outputBaseFileName"] = "VidCoder-" + $version + "-Beta"
        $tokens["appVerName"] = "VidCoder " + $version + " Beta (x64)"
    } else {
        $tokens["appName"] = "VidCoder"
        $tokens["appNameNoSpace"] = "VidCoder"
        $tokens["folderName"] = "VidCoder"
        $tokens["outputBaseFileName"] = "VidCoder-" + $version
        $tokens["appVerName"] = "VidCoder " + $version + " (x64)"
    }

    if ($debugBuild) {
        $tokens["outputDirectory"] = "BuiltInstallers\Test"
    } else {
        $tokens["outputDirectory"] = "BuiltInstallers"
    }

    ReplaceTokens "Installer\VidCoder.iss.txt" ("Installer\VidCoder-gen.iss") $tokens
}

function UpdateAssemblyInfo($fileName, $version) {
    $newVersionText = 'AssemblyVersion("' + $version + '")';
    $newFileVersionText = 'AssemblyFileVersion("' + $version + '")';

    $tmpFile = $fileName + ".tmp"

    Get-Content $fileName | 
    %{$_ -replace 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)', $newVersionText } |
    %{$_ -replace 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)', $newFileVersionText } > $tmpFile

    Move-Item $tmpFile $fileName -force
}

function CopyFromOutput($fileName, $buildFlavor) {
    $dest = ".\Installer\Files\"

    $source = ".\VidCoder\bin\$buildFlavor\"

    copy ($source + $fileName) ($dest + $fileName); ExitIfFailed
}

function CopyGeneral($fileName) {
    $dest = ".\Installer\Files"

    copy $fileName $dest; ExitIfFailed
}

function CopyLanguage($language, $buildFlavor) {
    $dest = ".\Installer\Files\"

    $source = ".\VidCoder\bin\$buildFlavor\"

    copy ($source + $language) ($dest + $language) -recurse; ExitIfFailed
}

# Master switch for if this branch is beta
$beta = $false

if ($debugBuild) {
    $buildFlavor = "Debug"
} else {
    $buildFlavor = "Release"
}

if ($beta) {
    $configuration = $buildFlavor + "-Beta"
} else {
    $configuration = $buildFlavor
}

# Get master version number
$versionLong = $versionShort + ".0"

# Put version numbers into AssemblyInfo.cs files
UpdateAssemblyInfo "VidCoder\Properties\AssemblyInfo.cs" $versionLong
UpdateAssemblyInfo "VidCoderWorker\Properties\AssemblyInfo.cs" $versionLong

# Build VidCoder.sln
& $DevEnvExe VidCoder.sln /Rebuild ($configuration + "|x64"); ExitIfFailed

# Run sgen to create *.XmlSerializers.dll
& ($NetToolsFolder + "\x64\sgen.exe") /f /a:"VidCoder\bin\$buildFlavor\VidCoderCommon.dll"; ExitIfFailed


# Copy install files to staging folder
$dest = ".\Installer\Files"

ClearFolder $dest; ExitIfFailed

$source = ".\VidCoder\bin\$buildFlavor\"

# Files from the main output directory
$outputDirectoryFiles = @(
    "VidCoder.exe",
    "VidCoder.pdb",
    "VidCoder.exe.config",
    "VidCoderCommon.dll",
    "VidCoderCommon.pdb",
    "VidCoderCommon.XmlSerializers.dll",
    "VidCoderWorker.exe",
    "VidCoderWorker.exe.config",
    "VidCoderWorker.pdb",
    "Omu.ValueInjecter.dll",
    "VidCoderCLI.exe",
    "VidCoderCLI.pdb",
    "VidCoderWindowlessCLI.exe",
    "VidCoderWindowlessCLI.pdb",
    "Microsoft.Practices.ServiceLocation.dll",
    "Hardcodet.Wpf.TaskbarNotification.dll",
    "Newtonsoft.Json.dll",
    "FastMember.dll",
    "Microsoft.Practices.Unity.dll",
    "ReactiveUI.dll",
    "Splat.dll",
    "System.Reactive.Core.dll",
    "System.Reactive.Interfaces.dll",
    "System.Reactive.Linq.dll",
    "System.Reactive.PlatformServices.dll",
    "System.Reactive.Windows.Threading.dll",
    "Ude.dll",
    "Xceed.Wpf.Toolkit.dll")

foreach ($outputDirectoryFile in $outputDirectoryFiles) {
    CopyFromOutput $outputDirectoryFile $buildFlavor
}

# General files
$generalFiles = @(
    ".\Lib\hb.dll",
    ".\Lib\System.Data.SQLite.dll",
    ".\Lib\HandBrake.ApplicationServices.dll",
    ".\Lib\HandBrake.ApplicationServices.pdb",
    ".\Lib\Ookii.Dialogs.Wpf.dll",
    ".\Lib\Ookii.Dialogs.Wpf.pdb",
    ".\VidCoder\BuiltInPresets.json",
    ".\VidCoder\Encode_Complete.wav",
    ".\VidCoder\Icons\File\VidCoderPreset.ico",
    ".\VidCoder\Icons\File\VidCoderQueue.ico",
    ".\License.txt")

foreach ($generalFile in $generalFiles) {
    CopyGeneral $generalFile
}

# Languages
$languages = @(
    "hu",
    "es",
    "eu",
    "pt",
    "pt-BR",
    "fr",
    "de",
    "zh",
    "zh-Hant",
    "it",
    "cs",
    "ja",
    "pl",
    "ru",
    "nl",
    "ka",
    "tr",
    "ko")

foreach ($language in $languages) {
    CopyLanguage $language $buildFlavor
}

# fonts folder for subtitles
copy ".\Lib\fonts" ".\Installer\Files" -Recurse


# Create portable installer

if ($beta) {
    $betaNameSection = "-Beta"
} else {
    $betaNameSection = ""
}

if ($debugBuild) {
    $builtInstallerFolder = "Installer\BuiltInstallers\Test"
} else {
    $builtInstallerFolder = "Installer\BuiltInstallers"
}

New-Item -ItemType Directory -Force -Path ".\$builtInstallerFolder"

$portableExeWithoutExtension = ".\$builtInstallerFolder\VidCoder-$versionShort$betaNameSection-Portable"

DeleteFileIfExists ($portableExeWithoutExtension + ".exe")

$winRarExe = "c:\Program Files\WinRar\WinRAR.exe"

& $winRarExe a -sfx -z".\Installer\VidCoderRar.conf" -iicon".\VidCoder\VidCoder_icon.ico" -r -ep1 $portableExeWithoutExtension .\Installer\Files\** | Out-Null
ExitIfFailed

# Update latest.xml files with version
if ($beta)
{
    $versionTag = "v$versionShort-beta"
    $installerFile = "VidCoder-$versionShort-Beta.exe"

    if ($debugBuild) {
        $latestFile = "Installer\Test\latest-beta.json"
    } else {
        $latestFile = "Installer\latest-beta.json"
    }
}
else
{
    $versionTag = "v$versionShort"
    $installerFile = "VidCoder-$versionShort.exe"

    if ($debugBuild) {
        $latestFile = "Installer\Test\latest.json"
    } else {
        $latestFile = "Installer\latest.xml"
    }
}

$latestJsonObject = Get-Content -Raw -Path $latestFile | ConvertFrom-Json

$latestJsonObject.LatestVersion = $versionShort
$latestJsonObject.DownloadUrl = "https://github.com/RandomEngy/VidCoder/releases/download/$versionTag/$installerFile"
$latestJsonObject.ChangelogUrl = "https://github.com/RandomEngy/VidCoder/releases/tag/$versionTag"

$latestJsonObject | ConvertTo-Json | Out-File $latestFile

# Create .iss file in the correct configuration
CreateIssFile $versionShort $beta $debugBuild

# Build the installers
& $InnoSetupExe Installer\VidCoder-gen.iss; ExitIfFailed


WriteSuccess

Write-Host
