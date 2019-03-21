#Declare the parameter for package name
param (
    [Parameter(Mandatory=$true)][string]$package
)
$User = "%pdquser%"
$PasswordFile = "%pwfile location.txt%"
$KeyFile = "%keyfile location.txt%"
$key = Get-Content $KeyFile
$MyCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, (Get-Content $PasswordFile | ConvertTo-SecureString -Key $key)
ipconfig /registerdns
Enable-PSRemoting -force
# Find the ip address from the computername - helps to use IP if you have unreliable DNS
$ipV4 = Test-Connection -Computername "$env:COMPUTERNAME" -count 1 |Select -ExpandProperty IPV4Address

# Run the deployment command using ip address as the target
#Invoke-Command -ComputerName %PDQ SERVER IP% -ScriptBlock { param ($compname) & 'C:\Program Files (x86)\Admin Arsenal\PDQ Deploy\pdqdeploy.exe' Deploy -Package $Using:package -Targets $Using:ipV4.IPAddressToString} -ArgumentList "$env:COMPUTERNAME"

# Run the deployment command using computername address as the target
Invoke-Command -ComputerName %PDQ SERVER DNS NAME% -Credential $MyCredential -ScriptBlock { param ($compname) & 'C:\Program Files (x86)\Admin Arsenal\PDQ Deploy\pdqdeploy.exe' Deploy -Package $Using:package -Targets $compname} -ArgumentList "$env:COMPUTERNAME"

#Add a timeout so if the deployment doesn't start it continues after 60 minutes
$timeout= new-timespan -Minutes 60
$StopWatch = [diagnostics.stopwatch]::StartNew()

#wait for the package to start by waiting for the lock file to appear
## This is good for when deployments may be queued up if PDQ deployment server is heavily used.
$LockfileExist=$false
Do{
If(Test-Path 'c:\windows\AdminArsenal\PDQDeployRunner\service-1.lock') {$LockfileExist = $true} Else {Write-Host 'Waiting PDQ install to start on ' $env:COMPUTERNAME - $ipV4.IPAddressToString ; Start-Sleep -s 10}
}
Until (($LockfileExist) -or ($StopWatch.elapsed -ge $timeout))

### Check if the package is still running by looking for the lock file to disappear
$fileDeleted=$false
Do{
If(Test-Path 'c:\windows\AdminArsenal\PDQDeployRunner\service-1.lock') {Write-Host 'PDQ install started: waiting to complete on ' $env:COMPUTERNAME - $ipV4.IPAddressToString; Start-Sleep -s 10} Else {$fileDeleted = $true}
}
Until ($fileDeleted)