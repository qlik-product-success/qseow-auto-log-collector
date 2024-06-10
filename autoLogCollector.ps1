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
    The path to which 

#>

#Requires -RunAsAdministrator

param (
    [string] $UrlUploadDestination = "", 
    [string] $TimeRangeInHours    = "25",
	[string] $CaseNumber = "",
    [string] $LocalTempContentPath = "C:\ProgramData\Qlik\Sense\Repository\TempContent\",

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

if ($UrlUploadDestination -eq '') {
   Write-Error "Url Upload destination cannot be empty."
   Exit
} 

if ($CaseNumber -eq '') {
   Write-Error "Case Number cannot be empty."
   Exit
} 

# Qlik Sense client certificate to be used for connection authentication
# Note, certificate lookup must return only one certificate. 
$ClientCert = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object {$_.Issuer -like "*$($CertIssuer)*"}

# Only continue if one unique client cert was found 
if (($ClientCert | measure-object).count -ne 1) { 
    Write-Host "Failed. Could not find one unique certificate." -ForegroundColor Red
    Exit 
}

# 16 character Xrfkey to use for QRS API call
$XrfKey = "hfFOdh87fD98f7sf"

# calculate the date times using timeRange.
$LogStart = (Get-Date).AddHours(-$TimeRangeInHours) 
$LogEnd = Get-Date

$formattedStart = Get-Date $LogStart -Format "yyyy-MM-dd'T'00:00:00.000'Z'"
$formattedEnd = Get-Date $LogEnd -Format "yyyy-MM-dd'T'00:00:00.000'Z'"

# HTTP headers to be used in REST API call
$HttpHeaders = @{}
$HttpHeaders.Add("X-Qlik-Xrfkey","$XrfKey")
$HttpHeaders.Add("X-Qlik-User", "UserDirectory=$UserDomain;UserId=$UserName")
$HttpHeaders.Add("Content-Type", "application/json")

# HTTP body for REST API call
$HttpBody = @{}

# Invoke REST API call
$GetLogsResponse = ""
try{
   $GetLogsResponse = Invoke-RestMethod -Uri "https://$($FQDN):4242/qrs/logexport?caseNumber=$($CaseNumber)&start=$($formattedStart)&end=$($formattedEnd)&xrfkey=$($xrfkey)" `
                  -Method GET `
                  -Headers $HttpHeaders  `
                  -Body $HttpBody `
                  -ContentType 'application/json' `
                  -Certificate $ClientCert

   Write-output "Status Code -- $($GetLogsResponse.StatusCode)"
   Write-output "Response: $($GetLogsResponse)"
   Write-Output "GET request to /logexport successful."
} catch {
   Write-Output "Status Code --- $($_.Exception.Response.StatusCode.Value__) "
   Write-Output "GET request to /logexport failed. Exiting..."
   Exit
}


$uuid = [regex]::Match($GetLogsResponse, "(?<=/tempcontent/)[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}").Value

$LocalPathOfZip = "$($LocalTempContentPath)$($uuid)\LogCollector_$($CaseNumber).zip"

Write-Output "Local Path of ZIP file: $($LocalPathOfZip)"

$FileName = "LogCollector_$CaseNumber.zip"

$UploadUrl = [regex]::Match($UrlUploadDestination, "^.*\.com\/").Value
$UploadPath = ($UrlUploadDestination -split "#")[1]

$encodedPath = $UploadPath -replace "/", "%2F"

$FormattedUploadUrl = "$($UploadUrl)upload?path=$($encodedPath)&appname=explorer&filename=$($FileName)&complete=1&offset=0&uploadpath=" 

$fs = [System.IO.FileStream]::New($LocalPathOfZip, [System.IO.FileMode]::Open)

$f1 = New-Object System.Net.Http.StreamContent $fs

$handler = New-Object System.Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $false # Don't follow after post redirect code 303
$client = New-Object System.Net.Http.HttpClient -ArgumentList $handler
$client.DefaultRequestHeaders.ConnectionClose = $true # Disable keep alive, get a 200 response rather than 303
$form = New-Object System.Net.Http.MultipartFormDataContent

$form.Add($f1, 'file', $FileName)

Write-Output  "Attempting upload to : $($FormattedUploadUrl)"
try{
    $rsp = $client.PostAsync($FormattedUploadUrl, $form).Result
    if ($rsp.IsSuccessStatusCode) {
     Write-Output "Success uploading to Filecloud"
    }  
}
catch {
    Write-Output "Error uploading to Filecloud"
    Write-Output "Error --- $($_.Exception.Response.Message) "
    Write-Output "Error --- $($_.Exception.Message) "
}

$fs.Close(); $fs.Dispose()

Exit