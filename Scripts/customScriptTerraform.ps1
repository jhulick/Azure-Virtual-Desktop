﻿Param(
  [string] $storageAccountName
  )

#install teams flag (change as needed)
[bool]$installTeams = $true
 
#create directory for log file
New-Item -ItemType "directory" -Path C:\DeploymentLogs
sleep 5

#create Log File and error log file
New-Item C:\DeploymentLogs\log.txt
New-Item C:\DeploymentLogs\errorlog.txt
sleep 5

#create initial log
Add-Content C:\DeploymentLogs\log.txt "Starting Script. exit code is: $LASTEXITCODE"
Add-Content C:\DeploymentLogs\log.txt "Install Teams is set to: $installTeams"
sleep 5

#set execution policy
try {
    Add-Content C:\DeploymentLogs\log.txt "Setting Execution Policy. exit code is: $LASTEXITCODE"
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -force
}
catch {
        Add-Content C:\DeploymentLogs\log.txt "Error occurred while setting execution policy with exit code: $LASTEXITCODE."
}

#enable TLS 1.2 to work for Windows Server 2016 environments
try {
    Add-Content C:\DeploymentLogs\log.txt "Setting TLS. exit code is: $LASTEXITCODE"
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
    sleep 5

    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
    sleep 5
}
catch {
    Add-Content C:\DeploymentLogs\log.txt "Error occurred while setting TLS 1.2 with exit code: $LASTEXITCODE."
}

#Install Nuget Modules
try {
  Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
  Add-Content C:\DeploymentLogs\log.txt "Installing Nuget Modules. exit code is: $LASTEXITCODE"
  sleep 10
}
catch {
    Add-Content C:\DeploymentLogs\log.txt "Error occurred downloading NuGet Modules with exit code: $LASTEXITCODE."
}


#install PSGet modules
try {
    Add-Content C:\DeploymentLogs\log.txt "Installing powershellGet Modules. exit code is: $LASTEXITCODE"
    Install-Module -Name PowerShellGet -Force -AllowClobber
    sleep 10
}
catch {
    Add-Content C:\DeploymentLogs\log.txt "Error occurred downloading PSGet with exit code: $LASTEXITCODE"
}

#install AZ modules
try {
 Install-Module -Name Az -force -AllowClobber
 Add-Content C:\DeploymentLogs\log.txt "Installing AZ Modules. exit code is: $LASTEXITCODE"
 sleep 10
}
catch {
    Add-Content C:\DeploymentLogs\log.txt "Error occurred downloading az Modules with exit code: $LASTEXITCODE"
}

#install AZAccounts modules
try {
    Add-Content C:\DeploymentLogs\log.txt "Importing AZ.Accounts module. exit code is: $LASTEXITCODE"
    Import-Module Az.Accounts -force 
    sleep 10
}
catch {
    Add-Content C:\DeploymentLogs\log.txt "Error occurred Importing azAccounts Modules with exit code: $LASTEXITCODE"
}

#download storage account script
try {
    Add-Content C:\DeploymentLogs\log.txt "downloading storageAccountScript. exit code is: $LASTEXITCODE"
    $Url = 'https://github.com/jhulick/Azure-Virtual-Desktop/blob/main/Scripts/JoinStorageAccount.zip?raw=true'
    Invoke-WebRequest -Uri $Url -OutFile "C:\JoinStorageAccount.zip"
    sleep 5
    Expand-Archive -Path "C:\JoinStorageAccount.zip" -DestinationPath "C:\JoinStorageAccount" -Force
}
catch {
     Add-Content C:\DeploymentLogs\log.txt "Error downloading and expanding storage account script. exit code is: $LASTEXITCODE"
}

#create share name for fslogix
$shareName = $storageAccountName+'.file.core.windows.net'
$connectionString = '\\' + $storageAccountName + '.file.core.usgovcloudapi.net\fslogixprofiles'

#configure fslogix profile containers
Add-Content C:\DeploymentLogs\log.txt "Setting FSLogix Registry Keys. exit code is: $LASTEXITCODE"

#create profiles key
New-Item 'HKLM:\Software\FSLogix\Profiles' -Force 
sleep 05

#create enabled value
New-ITEMPROPERTY 'HKLM:\Software\FSLogix\Profiles' -Name Enabled -Value 1
sleep 05

#removes any local profiles that are found
New-ITEMPROPERTY 'HKLM:\Software\FSLogix\Profiles' -Name DeleteLocalProfileWhenVHDShouldApply -Value 1
sleep 05

#set  connection string
New-ITEMPROPERTY 'HKLM:\Software\FSLogix\Profiles' -Name VHDLocations -PropertyType String -Value $connectionString
sleep 05

#flipflop username to front of profile name
New-ITEMPROPERTY 'HKLM:\Software\FSLogix\Profiles' -Name FlipFlopProfileDirectoryName -Value 1
sleep 10

#set to vhdx
New-ITEMPROPERTY 'HKLM:\Software\FSLogix\Profiles' -Name VolumeType -PropertyType String -Value "vhdx"
sleep 05

#configure RDP shortpath reg keys
REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations" /v ICEControl /t REG_DWORD  /d 2 /f

#Add Defender Exclusions for FSLogix
try{
    Add-Content C:\DeploymentLogs\log.txt "Setting Defender Exclusions for FSLogix. exit code is: $LASTEXITCODE"
    powershell -Command "Add-MpPreference -ExclusionPath 'C:\Program Files\FSLogix\Apps\frxdrv.sys’"
    powershell -Command "Add-MpPreference -ExclusionPath 'C:\Program Files\FSLogix\Apps\frxdrvvt.sys’"
    powershell -Command "Add-MpPreference -ExclusionPath 'C:\Program Files\FSLogix\Apps\frxccd.sys’"
    powershell -Command "Add-MpPreference -ExclusionExtension '%TEMP%\*.VHD’"
    powershell -Command "Add-MpPreference -ExclusionExtension '%TEMP%\*.VHDX’"
    powershell -Command "Add-MpPreference -ExclusionExtension '%Windir%\*.VHD’"
    powershell -Command "Add-MpPreference -ExclusionExtension '%Windir%\*.VHDX’"
    powershell -Command "Add-MpPreference -ExclusionExtension '\\$storageAccountName.file.core.usgovcloudapi.net\fslogixprofiles\*\*.*.VHDX’"
    powershell -Command "Add-MpPreference -ExclusionExtension '\\$storageAccountName.file.core.usgovcloudapi.net\fslogixprofiles\*\*.*.VHD’"
    powershell -Command "Add-MpPreference -ExclusionProcess '%Program Files%\FSLogix\Apps\frxccd.exe’"
    powershell -Command "Add-MpPreference -ExclusionProcess '%Program Files%\FSLogix\Apps\frxccds.exe’"
    powershell -Command "Add-MpPreference -ExclusionProcess '%Program Files%\FSLogix\Apps\frxsvc.exe’"
    Add-Content C:\DeploymentLogs\log.txt "Defender Exclusions for FSLogix successful! Storage account used is:$storageAccountName Current exit code is: $LASTEXITCODE"
}
catch {
    Add-Content C:\DeploymentLogs\log.txt "Error setting defender exclusions. exit code is: $LASTEXITCODE"
}

# Enable Azure AD Kerberos

Add-Content '*** WVD AIB CUSTOMIZER PHASE *** Enable Azure AD Kerberos ***'
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
$registryKey= "CloudKerberosTicketRetrievalEnabled"
$registryValue = "1"

IF(!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

try {
    New-ItemProperty -Path $registryPath -Name $registryKey -Value $registryValue -PropertyType DWORD -Force | Out-Null
}
catch {
    Add-Content "*** AVD AIB CUSTOMIZER PHASE ***  Enable Azure AD Kerberos - Cannot add the registry key $registryKey *** : [$($_.Exception.Message)]"
    Add-Content "Message: [$($_.Exception.Message)"]
}


# Create new reg key "LoadCredKey"

Add-Content '*** AVD AIB CUSTOMIZER PHASE *** Create new reg key LoadCredKey ***'

$LoadCredRegPath = "HKLM:\Software\Policies\Microsoft\AzureADAccount"
$LoadCredName = "LoadCredKeyFromProfile"
$LoadCredValue = "1"

IF(!(Test-Path $LoadCredRegPath)) {
    New-Item -Path $LoadCredRegPath -Force | Out-Null
}

try {
    New-ItemProperty -Path $LoadCredRegPath -Name $LoadCredName -Value $LoadCredValue -PropertyType DWORD -Force | Out-Null
}
catch {
    Add-Content "*** AVD AIB CUSTOMIZER PHASE ***  LoadCredKey - Cannot add the registry key $LoadCredName *** : [$($_.Exception.Message)]"
    Add-Content "Message: [$($_.Exception.Message)"]
}

if ($installTeams) {

    Add-Content C:\DeploymentLogs\log.txt "Installing Teams. exit code is: $LASTEXITCODE"

    #create Teams folder in C drive
    New-Item -Path "c:\" -Name "Install" -ItemType "directory"

    # Add registry Key
    reg add "HKLM\SOFTWARE\Microsoft\Teams" /v IsWVDEnvironment /t REG_DWORD /d 1 /f
    sleep 5

    #Download C++ Runtime
    try {
        Add-Content C:\DeploymentLogs\log.txt "Downloading C++ Runtime. exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://aka.ms/vs/16/release/vc_redist.x64.exe -OutFile "C:\Install\vc_redist.x64.exe"
        sleep 5
    }
    catch {
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://aka.ms/vs/16/release/vc_redist.x64.exe -OutFile "C:\Install\vc_redist.x64.exe"
        sleep 5
    }

    #Download RDCWEBRTCSvc
    try {
        Add-Content C:\DeploymentLogs\log.txt "Downloading WebRTC Redirector Service. exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt -OutFile "C:\Install\MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi"
        sleep 5
    }
    catch {
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt -OutFile "C:\Install\MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi"
        sleep 5
    }

    #Download Teams
    try {
        Add-Content C:\DeploymentLogs\log.txt "Downloading Teams Machine-Wide Installer. exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://statics.teams.cdn.office.net/production-windows-x64/1.7.00.6058/Teams_windows_x64.msi -OutFile "C:\Install\Teams_windows_x64.msi"
        sleep 5
    }
    catch {
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        invoke-WebRequest -Uri https://statics.teams.cdn.office.net/production-windows-x64/1.7.00.6058/Teams_windows_x64.msi -OutFile "C:\Install\Teams_windows_x64.msi"
        sleep 5
    }

    #Install C++ runtime
    try {
        Add-Content C:\DeploymentLogs\log.txt "Installing C++ Runtime. exit code is: $LASTEXITCODE"
        Start-Process -FilePath C:\Install\vc_redist.x64.exe -ArgumentList '/q', '/norestart'
        sleep 5
    }
    catch {
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        Start-Process -FilePath C:\Install\vc_redist.x64.exe -ArgumentList '/q', '/norestart'
        sleep 5
    }

    #Install Web Socket Redirector Service
    try {
        Add-Content C:\DeploymentLogs\log.txt "Installing Redirector Service. exit code is: $LASTEXITCODE"
        msiexec /i C:\Install\MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi /q /n
        sleep 5
    }
    catch {
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        msiexec /i C:\Install\MsRdcWebRTCSvc_HostSetup_1.0.2006.11001_x64.msi /q /n
        sleep 5
    }

    # Install Teams
    try {
        Add-Content C:\DeploymentLogs\log.txt "Installing Teams. exit code is: $LASTEXITCODE"
        msiexec /i "C:\Install\Teams_windows_x64.msi" /l*v c:\Install\Teams.log ALLUSER=1 ALLUSERS=1 
        sleep 5
    }
    catch {
        Add-Content C:\DeploymentLogs\log.txt "Error. Check the error log. Retrying... exit code is: $LASTEXITCODE"
        msiexec /i "C:\Install\Teams_windows_x64.msi" /l*v c:\Install\Teams.log ALLUSER=1 ALLUSERS=1 
        sleep 5
    }

}

if($LASTEXITCODE -ne 0) {
    Add-Content C:\DeploymentLogs\log.txt "Execution finished with non-zero exit code of: $LASTEXITCODE. Please check the error log."
    Add-Content C:\DeploymentLogs\errorlog.txt $Error
    exit 0
}

Add-Content C:\DeploymentLogs\log.txt "Execution complete. Final exit code is: $LASTEXITCODE"
Add-Content C:\DeploymentLogs\errorlog.txt $Error
exit 0






