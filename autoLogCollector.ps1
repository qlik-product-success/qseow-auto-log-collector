# The MIT License (MIT)

# Copyright (c) 2024 QLIKTECH INTERNATIONAL A.B. (QLIK)

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to permit
# persons to whom the Software is furnished to do so, subject to the
# following conditions:

# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

<#
.SYNOPSIS
    Enables scheduled collection of logs and uploads them to provided Filecloud location.
.DESCRIPTION
    This script calls the log collector api from Repository service to collect logs for the specified
    date range. It then uses the UrlUploadDestination param to upload those collected logs to that Filecloud destination.

    This script is intended to run on a regular schedule (ie. once per day) to avoid
    uploading large amounts of data per day. Modifications can be made.
    For example, if you schedule this script to run every 2 days, then you should set the TimeInterval
    param as 49 (48 +1). 

.PARAMETER UrlUploadDestination
    Filecloud location to which logs will be uploaded. 
.PARAMETER TimeRangeInHours
    Time range for which QRS will fetch logs. For example, if "25" is passed in as an argument, QRS will fetch the logs between now and 25 hours ago.
    This argument should be in accordance to the time interval to which you schedule this script to run in order to avoid unwanted results.
    For example, if you schedule this script to run every 48 hours, then TimeRangeInHours should be 49 (48 hours + 1 to bridge any gap).
    If you set the script to run every 48 hours, and do not provide an argument of 49 hours, then it will default to 25, which means every time the script executes,
    you'll be missing 24 hours worth of logs. 
    The default value for this is 25 hours.
.PARAMETER CaseNumber
    The case number found in Salesforce. Value cannot be empty.

.PARAMETER LocalTempContentPath
    The path to which QRS outputs the logs after collecting them. Default value is "C:\ProgramData\Qlik\Sense\Repository\TempContent\".
.PARAMETER Options
    Additional Folders to gather upon log collection. Must be a comma separated value ie.options: eventlog,systeminfo,scriptlogs,allfolders
    To include Windows event logs: eventlog
    To include system information: systeminfo
    To include scriptlog files from Qlik folders: scriptlogs
    To ignore log-folder filter and export all: allfolders
#>

#Requires -RunAsAdministrator

param (
    [string] $UrlUploadDestination  = "", 
    [string] $TimeRangeInHours      = "25",
	[string] $CaseNumber            = "",
    [string] $LocalTempContentPath  = "C:\ProgramData\Qlik\Sense\Repository\TempContent\",
    [string] $Options               = "",

	[Parameter()]
    [string] $UserName   = $env:USERNAME, 
    [Parameter()]
    [string] $UserDomain = $env:USERDOMAIN,
    [Parameter()]
    [string] $FQDN       = [string][System.Net.Dns]::GetHostByName(($env:computerName)).Hostname, 
    [Parameter()]
    [string] $CertIssuer = [string][System.Net.Dns]::GetHostByName(($env:computerName)).Hostname
)

# Load required assemblies
Add-Type -AssemblyName System.Net.Http


#Part 1: Validation
# Validate that UrlUploadDestination is not empty
if ($UrlUploadDestination -eq '') {
   Write-Host "Url Upload destination cannot be empty." -ForegroundColor Red
   Exit
} 

# Validate UrlUploadDestination Authority
if (!($UrlUploadDestination -like "https://files.qlik.com/*")) { 
    Write-Host "Error: Invalid UrlUploadDestination." -ForegroundColor Red
    Exit
}

# Validate that CaseNumber is not empty
if ($CaseNumber -eq '') {
   Write-Host "Case Number cannot be empty." -ForegroundColor Red
   Exit
} 

# Check if CaseNumber is not numeric
if (!($CaseNumber -match "^\d+$")) {
    Write-Host "Invalid Case Number." -ForegroundColor Red
    Exit
}


$ValidOptions = "eventlog", "systeminfo", "scriptlogs", "allfolders"

if(!($Options -eq "")) {
    # Split the input value into an array
    $InputArray = $Options -split ","

    # Check if each value in the array exists in the valid options
    $IsValid = $InputArray | ForEach-Object { $ValidOptions -contains $_ }

    # Check if all values are valid
    if ($IsValid -contains $false) {
        Write-Host "Invalid Options param." -ForegroundColor Red
        Exit
    }
}

$ClientCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object {$_.Issuer -like "*$($CertIssuer)*"}

if (($ClientCert | measure-object).count -ne 1) { 
    Write-Host "Failed. Could not find one unique certificate." -ForegroundColor Red
    Exit 
}


#Part 2: Redirect URL retrieval
$GetUploadUrlResponse = ""

Write-Host "Getting Upload URL from: $($UrlUploadDestination)"

try{
   $GetUploadUrlResponse = Invoke-WebRequest -Uri $UrlUploadDestination -Method GET -MaximumRedirection 0 -ErrorAction SilentlyContinue

   Write-Host "GetUploadUrlResponse Status: $($GetUploadUrlResponse.StatusCode)"
} catch {
   $_
   Write-Host "Status Code --- $($_.Exception.Response.StatusCode.Value__) " -ForegroundColor Red
   Write-Host "GET request to get Upload URL failed. Exiting..." -ForegroundColor Red
   Exit
}

$RedirectedUploadLocation = $GetUploadUrlResponse.Headers.Location

#Part 3: Log Retrieval
$XrfKey = "hfFOdh87fD98f7sf"

$LogStart = (Get-Date).AddHours(-$TimeRangeInHours) 
$LogEnd = Get-Date

$FormattedStart = Get-Date $LogStart -Format "yyyy-MM-dd'T'HH:mm:ss.000'Z'"
$FormattedEnd = Get-Date $LogEnd -Format "yyyy-MM-dd'T'HH:mm:ss.000'Z'"

$HttpHeaders = @{}
$HttpHeaders.Add("X-Qlik-Xrfkey","$XrfKey")
$HttpHeaders.Add("X-Qlik-User", "UserDirectory=$UserDomain;UserId=$UserName")
$HttpHeaders.Add("Content-Type", "application/json")

$HttpBody = @{}

# Invoke REST API call to QRS
Write-Host "Collecting Logs from QRS"
$GetLogsResponse = ""
try{
   $GetLogsResponse = Invoke-RestMethod -Uri "https://$($FQDN):4242/qrs/logexport?caseNumber=$($CaseNumber)&start=$($FormattedStart)&end=$($FormattedEnd)&xrfkey=$($XrfKey)&options=$($Options)" `
                  -Method GET `
                  -Headers $HttpHeaders  `
                  -Body $HttpBody `
                  -ContentType 'application/json' `
                  -Certificate $ClientCert
   Write-Host "GET request to /logexport successful."
} catch {
   $_
   Write-Host "Status Code --- $($_.Exception.Response.StatusCode.Value__) " -ForegroundColor Red
   Write-Host "GET request to /logexport failed. Exiting..." -ForegroundColor Red
   Exit
}

$Uuid = [regex]::Match($GetLogsResponse, "(?<=/tempcontent/)[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}").Value
$FileName = "LogCollector_$CaseNumber.zip"
$LocalPathOfZip = "$($LocalTempContentPath)$($Uuid)\$($FileName)"

#Part 4: Log Upload
$CollectedStartDate = Get-Date $LogStart -Format "yyyy-MM-dd-HHmmss"
$CollectedEndDate = Get-Date $LogEnd -Format "yyyy-MM-dd-HHmmss"
$UpdatedFileName = "LogCollector_$($CaseNumber)_$($CollectedStartDate)_$($CollectedEndDate).zip"

$UploadUrl = [regex]::Match($UrlUploadDestination, "^.*\.com\/").Value
$UploadPath = ($RedirectedUploadLocation -split "#")[1]
$EncodedPath = $UploadPath -replace "/", "%2F"
$FormattedUploadUrl = "$($UploadUrl)upload?path=$($EncodedPath)&appname=explorer&filename=$($UpdatedFileName)&complete=1&offset=0&uploadpath=" 

$Fs = [System.IO.FileStream]::New($LocalPathOfZip, [System.IO.FileMode]::Open)
$FileContent = New-Object System.Net.Http.StreamContent $Fs

$Handler = New-Object System.Net.Http.HttpClientHandler
$Handler.AllowAutoRedirect = $false 
$Client = New-Object System.Net.Http.HttpClient -ArgumentList $Handler
$Client.DefaultRequestHeaders.ConnectionClose = $true 
$Form = New-Object System.Net.Http.MultipartFormDataContent

$Form.Add($FileContent, 'file', $UpdatedFileName)

Write-Host  "Attempting upload to : $($FormattedUploadUrl)"
try{
    $Rsp = $Client.PostAsync($FormattedUploadUrl, $Form).Result
    if ($Rsp.IsSuccessStatusCode) {
        Write-Output "Success uploading to Filecloud"
    }  
} catch {
    Write-Host "Error uploading to Filecloud" -ForegroundColor Red
    Write-Host "Error --- $($_.Exception.Response.Message) " -ForegroundColor Red
    Write-Host "Error Message --- $($_.Exception.Message) " -ForegroundColor Red
    $Fs.Close(); $Fs.Dispose()
    Exit
}

$Fs.Close(); $Fs.Dispose()

#Part 5: Log upload result



Exit