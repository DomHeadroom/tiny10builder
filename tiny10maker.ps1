if ((Get-ExecutionPolicy) -eq 'Restricted') {
    Write-Host "Your current PowerShell Execution Policy is set to Restricted, which prevents scripts from running. Do you want to change it to RemoteSigned? (si/no)"
    $response = Read-Host
    if ($response -eq 'si') {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm:$false
    } else {
        Write-Host "The script cannot be run without changing the execution policy. Exiting..."
        exit
    }
}
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
if ($myWindowsPrincipal.IsInRole($adminRole))
{
    $Host.UI.RawUI.WindowTitle = "creatore tiny10"
    Clear-Host
}
else
{
    $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
    $newProcess.Arguments = $myInvocation.MyCommand.Definition;
    $newProcess.Verb = "runas";
    [System.Diagnostics.Process]::Start($newProcess);
    exit
}
Write-Host "Benvenuto nel creatore d'immagini tiny10!"
Start-Sleep -Seconds 3
Clear-Host
$mainOSDrive = $env:SystemDrive

$DriveLetter = Read-Host "Inserisci la lettera del dispositivo per l'immagine di Windows 10"
$DriveLetter = $DriveLetter + ":"

if ((Test-Path "$DriveLetter\sources\boot.wim") -eq $false -or (Test-Path "$DriveLetter\sources\install.wim") -eq $false) {
    Write-Host "Can't find Windows OS Installation files in the specified Drive Letter.."
    Write-Host "Please enter the correct DVD Drive Letter.."
    exit
}

New-Item -ItemType Directory -Force -Path "$mainOSDrive\tiny10"
Write-Host "Copiando immagine di Windows..."
Copy-Item -Path "$DriveLetter\*" -Destination "$mainOSDrive\tiny10" -Recurse -Force
Write-Host "Copy complete!"
Start-Sleep -Seconds 2
Clear-Host
Write-Host "Getting image information:"
&  'dism' "/Get-WimInfo" "/wimfile:$mainOSDrive\tiny10\sources\install.wim"
$index = Read-Host "Please enter the image index"
Write-Host "Mounting Windows image. This may take a while."
$wimFilePath = "$($env:SystemDrive)\tiny10\sources\install.wim"
& takeown "/F" $wimFilePath
& icacls $wimFilePath "/grant" "Administrators:(F)"
Set-ItemProperty -Path $wimFilePath -Name IsReadOnly -Value $false
New-Item -ItemType Directory -Force -Path "$mainOSDrive\scratchdir"
& dism "/mount-image" "/imagefile:$($env:SystemDrive)\tiny10\sources\install.wim" "/index:$index" "/mountdir:$($env:SystemDrive)\scratchdir"

$imageIntl = & dism /Get-Intl "/Image:$($env:SystemDrive)\scratchdir"
$languageLine = $imageIntl -split '\n' | Where-Object { $_ -match "Lingua predefinita dell'interfaccia utente del sistema : ([a-zA-Z]{2}-[a-zA-Z]{2})" }

if ($languageLine) {
    $languageCode = $Matches[1]
    Write-Host "Lingua predefinita di sistema: $languageCode"
} else {
    Write-Host "Lingua predefinita del sistema non trovata."
}

$imageInfo = & 'dism' '/Get-WimInfo' "/wimFile:$($env:SystemDrive)\tiny10\sources\install.wim" "/index:$index"
$lines = $imageInfo -split '\r?\n'

foreach ($line in $lines) {
    if ($line -like '*Architettura : *') {
        $architecture = $line -replace 'Architettura : ',''
        # If the architecture is x64, replace it with amd64
        if ($architecture -eq 'x64') {
            $architecture = 'amd64'
        }
        Write-Host "Architettura: $architecture"
        break
    }
}

if (-not $architecture) {
    Write-Host "Informazioni sull'architettura non trovate."
}


Write-Host "Mounting complete! Performing removal of applications..."

$packages = & 'dism' "/image:$($env:SystemDrive)\scratchdir" '/Get-ProvisionedAppxPackages' |
    ForEach-Object {
        if ($_ -match 'PackageName: (.*)') {
            $matches[1]
        }
    }
$packagePrefixes = 'Microsoft.ScreenSketch_', 'Microsoft.MSPaint_', 'Microsoft.Wallet_', 'Microsoft.WindowsCamera_', 'Microsoft.SkypeApp_', 'Microsoft.Office.OneNote_', 'Microsoft.MixedReality.Portal_', 'Microsoft.MicrosoftStickyNotes_', 'Microsoft.Microsoft3DViewer_', 'Microsoft.BingWeather_', 'Microsoft.GetHelp_', 'Microsoft.Getstarted_', 'Microsoft.MicrosoftOfficeHub_', 'Microsoft.MicrosoftSolitaireCollection_', 'Microsoft.People_', 'Microsoft.WindowsAlarms_', 'microsoft.windowscommunicationsapps_', 'Microsoft.WindowsFeedbackHub_', 'Microsoft.WindowsMaps_', 'Microsoft.WindowsSoundRecorder_', 'Microsoft.Xbox.TCUI_', 'Microsoft.XboxGamingOverlay_', 'Microsoft.XboxGameOverlay_', 'Microsoft.XboxSpeechToTextOverlay_', 'Microsoft.YourPhone_', 'Microsoft.ZuneMusic_', 'Microsoft.ZuneVideo_', 'Microsoft.549981C3F5F10_'

$packagesToRemove = $packages | Where-Object {
    $packageName = $_
    $packagePrefixes -contains ($packagePrefixes | Where-Object { $packageName -like "$_*" })
}
foreach ($package in $packagesToRemove) {
    & 'dism' "/image:$($env:SystemDrive)\scratchdir" '/Remove-ProvisionedAppxPackage' "/PackageName:$package"
}


Write-Host "Rimuovendo Edge:"
Remove-Item -Path "$mainOSDrive\scratchdir\Program Files (x86)\Microsoft\Edge" -Recurse -Force
Remove-Item -Path "$mainOSDrive\scratchdir\Program Files (x86)\Microsoft\EdgeUpdate" -Recurse -Force
Remove-Item -Path "$mainOSDrive\scratchdir\Program Files (x86)\Microsoft\EdgeCore" -Recurse -Force
if ($architecture -eq 'amd64') {
    $folderPath = Get-ChildItem -Path "$mainOSDrive\scratchdir\Windows\WinSxS" -Filter "amd64_microsoft-edge-webview_31bf3856ad364e35*" -Directory | Select-Object -ExpandProperty FullName

    if ($folderPath) {
        & 'takeown' '/f' $folderPath '/r'
        & 'icacls' $folderPath '/grant' 'Administrators:F' '/T' '/C'
        Remove-Item -Path $folderPath -Recurse -Force
    } else {
        Write-Host "Folder not found."
    }
} elseif ($architecture -eq 'arm64') {
    $folderPath = Get-ChildItem -Path "$mainOSDrive\scratchdir\Windows\WinSxS" -Filter "arm64_microsoft-edge-webview_31bf3856ad364e35*" -Directory | Select-Object -ExpandProperty FullName

    if ($folderPath) {
        & 'takeown' '/f' $folderPath '/r'
        & 'icacls' $folderPath '/grant' 'Administrators:F' '/T' '/C'
        Remove-Item -Path $folderPath -Recurse -Force
    } else {
        Write-Host "Folder not found."
    }
} else {
    Write-Host "Unknown architecture: $architecture"
}
& 'takeown' '/f' "$mainOSDrive\scratchdir\Windows\System32\Microsoft-Edge-Webview" '/r'
& 'icacls' "$mainOSDrive\scratchdir\Windows\System32\Microsoft-Edge-Webview" '/grant' 'Administrators:F' '/T' '/C'
Remove-Item -Path "$mainOSDrive\scratchdir\Windows\System32\Microsoft-Edge-Webview" -Recurse -Force
Remove-Item -Path "$mainOSDrive\scratchdir\Windows\System32\OneDriveSetup.exe" -Force
Write-Host "Removal complete!"
Start-Sleep -Seconds 2
Clear-Host
Write-Host "Loading registry..."
reg load HKLM\zCOMPONENTS $mainOSDrive\scratchdir\Windows\System32\config\COMPONENTS
reg load HKLM\zDEFAULT $mainOSDrive\scratchdir\Windows\System32\config\default
reg load HKLM\zNTUSER $mainOSDrive\scratchdir\Users\Default\ntuser.dat
reg load HKLM\zSOFTWARE $mainOSDrive\scratchdir\Windows\System32\config\SOFTWARE
reg load HKLM\zSYSTEM $mainOSDrive\scratchdir\Windows\System32\config\SYSTEM
Write-Host "Disabling Sponsored Apps:"
& 'reg' 'add' 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'OemPreInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'PreInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SilentInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' '/v' 'DisableWindowsConsumerFeatures' '/t' 'REG_DWORD' '/d' '1' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'ContentDeliveryAllowed' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zSOFTWARE\Microsoft\PolicyManager\current\device\Start' '/v' 'ConfigureStartPins' '/t' 'REG_SZ' '/d' '{"pinnedList": [{}]}' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'ContentDeliveryAllowed' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'ContentDeliveryAllowed' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'FeatureManagementEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'OemPreInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'PreInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'PreInstalledAppsEverEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SilentInstalledAppsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SoftLandingEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContentEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-310093Enabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-338388Enabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-338389Enabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-338393Enabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-353694Enabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContent-353696Enabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SubscribedContentEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' '/v' 'SystemPaneSuggestionsEnabled' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zSoftware\Policies\Microsoft\PushToInstall' '/v' 'DisablePushToInstall' '/t' 'REG_DWORD' '/d' '1' '/f'
& 'reg' 'add' 'HKLM\zSoftware\Policies\Microsoft\MRT' '/v' 'DontOfferThroughWUAU' '/t' 'REG_DWORD' '/d' '1' '/f'
& 'reg' 'delete' 'HKLM\zNTUSER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions' '/f'
& 'reg' 'add' 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' '/v' 'DisableConsumerAccountStateContent' '/t' 'REG_DWORD' '/d' '1' '/f'
& 'reg' 'add' 'HKLM\zSOFTWARE\Policies\Microsoft\Windows\CloudContent' '/v' 'DisableCloudOptimizedContent' '/t' 'REG_DWORD' '/d' '1' '/f'
Write-Host "Enabling Local Accounts on OOBE:"
& 'reg' 'add' 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\OOBE' '/v' 'BypassNRO' '/t' 'REG_DWORD' '/d' '1' '/f'
Copy-Item -Path "$PSScriptRoot\autounattend.xml" -Destination "$mainOSDrive\scratchdir\Windows\System32\Sysprep\autounattend.xml" -Force
Write-Host "Disabling Reserved Storage:"
& 'reg' 'add' 'HKLM\zSOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager' '/v' 'ShippedWithReserves' '/t' 'REG_DWORD' '/d' '0' '/f'
Write-Host "Disabling Meet Now:"
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' '/v' 'HideSCAMeetNow' '/t' 'REG_DWORD' '/d' '1' '/f'
Write-Host "Disabling News and Interests:"
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\default\NewsAndInterests\AllowNewsAndInterests' '/v' 'value' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' '/v' 'EnableFeeds' '/t' 'REG_DWORD' '/d' '0' '/f'
Write-Host "Disabling Search Highlights:"
& 'reg' 'add' 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search' '/v' 'EnableDynamicContentInWSB' '/t' 'REG_DWORD' '/d' '0' '/f'
Write-Host "Removing OneDrive:"
& 'reg' 'delete' 'HKEY_LOCAL_MACHINE\Offline\Software\Microsoft\Windows\CurrentVersion\Run\OneDriveSetup' '/f'
Write-Host "Tweaking complete!"
Write-Host "Unmounting Registry..."
reg unload HKLM\zCOMPONENTS
reg unload HKLM\zDRIVERS
reg unload HKLM\zDEFAULT
reg unload HKLM\zNTUSER
reg unload HKLM\zSCHEMA
reg unload HKLM\zSOFTWARE
reg unload HKLM\zSYSTEM
Write-Host "Cleaning up image..."
& 'dism' "/image:$mainOSDrive\scratchdir" '/Cleanup-Image' '/StartComponentCleanup' '/ResetBase'
Write-Host "Cleanup complete."
Write-Host "Unmounting image..."
& 'dism' '/unmount-image' "/mountdir:$mainOSDrive\scratchdir" '/commit'
Write-Host "Exporting image..."
& 'Dism' '/Export-Image' "/SourceImageFile:$mainOSDrive\tiny10\sources\install.wim" "/SourceIndex:$index" "/DestinationImageFile:$mainOSDrive\tiny10\sources\install2.wim" '/compress:max'
Remove-Item -Path "$mainOSDrive\tiny10\sources\install.wim" -Force
Rename-Item -Path "$mainOSDrive\tiny10\sources\install2.wim" -NewName "install.wim"
Write-Host "Windows image completed. Continuing with boot.wim."
Start-Sleep -Seconds 2
Clear-Host
Write-Host "Mounting boot image:"
$wimFilePath = "$($env:SystemDrive)\tiny10\sources\boot.wim"
& takeown "/F" $wimFilePath
& icacls $wimFilePath "/grant" "Administrators:(F)"
Set-ItemProperty -Path $wimFilePath -Name IsReadOnly -Value $false
& 'dism' '/mount-image' "/imagefile:$mainOSDrive\tiny10\sources\boot.wim" '/index:2' "/mountdir:$mainOSDrive\scratchdir"
Write-Host "Loading registry..."
reg load HKLM\zCOMPONENTS $mainOSDrive\scratchdir\Windows\System32\config\COMPONENTS
reg load HKLM\zDEFAULT $mainOSDrive\scratchdir\Windows\System32\config\default
reg load HKLM\zNTUSER $mainOSDrive\scratchdir\Users\Default\ntuser.dat
reg load HKLM\zSOFTWARE $mainOSDrive\scratchdir\Windows\System32\config\SOFTWARE
reg load HKLM\zSYSTEM $mainOSDrive\scratchdir\Windows\System32\config\SYSTEM
Write-Host "Bypassing system requirements(on the setup image):"
& 'reg' 'add' 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV1' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zDEFAULT\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV2' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV1' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zNTUSER\Control Panel\UnsupportedHardwareNotificationCache' '/v' 'SV2' '/t' 'REG_DWORD' '/d' '0' '/f'
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassCPUCheck' '/t' 'REG_DWORD' '/d' '1' '/f'
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassRAMCheck' '/t' 'REG_DWORD' '/d' '1' '/f'
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassSecureBootCheck' '/t' 'REG_DWORD' '/d' '1' '/f'
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassStorageCheck' '/t' 'REG_DWORD' '/d' '1' '/f'
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\LabConfig' '/v' 'BypassTPMCheck' '/t' 'REG_DWORD' '/d' '1' '/f'
& 'reg' 'add' 'HKLM\zSYSTEM\Setup\MoSetup' '/v' 'AllowUpgradesWithUnsupportedTPMOrCPU' '/t' 'REG_DWORD' '/d' '1' '/f'
Write-Host "Tweaking complete!"
Write-Host "Smontando Registro..."
reg unload HKLM\zCOMPONENTS
reg unload HKLM\zDRIVERS
reg unload HKLM\zDEFAULT
reg unload HKLM\zNTUSER
reg unload HKLM\zSCHEMA
reg unload HKLM\zSOFTWARE
reg unload HKLM\zSYSTEM
Write-Host "Smontando Immagine..."
& 'dism' '/unmount-image' "/mountdir:$mainOSDrive\scratchdir" '/commit'
Clear-Host
Write-Host "The tiny10 image is now completed. Proceeding with the making of the ISO..."
Write-Host "Copying unattended file for bypassing MS account on OOBE..."
Copy-Item -Path "$PSScriptRoot\autounattend.xml" -Destination "$mainOSDrive\tiny10\autounattend.xml" -Force
Write-Host "Creating ISO image..."
& "$PSScriptRoot\oscdimg.exe" '-m' '-o' '-u2' '-udfver102' "-bootdata:2#p0,e,b$mainOSDrive\tiny10\boot\etfsboot.com#pEF,e,b$mainOSDrive\tiny10\efi\microsoft\boot\efisys.bin" "$mainOSDrive\tiny10" "$PSScriptRoot\tiny10.iso"
Write-Host "Creation completed! Press any key to exit the script..."
Read-Host "Press Enter to continue"
Write-Host "Performing Cleanup..."
Remove-Item -Path "$mainOSDrive\tiny10" -Recurse -Force
Remove-Item -Path "$mainOSDrive\scratchdir" -Recurse -Force
exit
