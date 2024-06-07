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
    date range. It then uses the url param to upload those collected logs to the url from 
    FileCloud.
    This script is intended to run on a regular schedule (ie. once per day) to avoid
    uploading large amounts of data per day. 
.PARAMETER UrlUploadDestination
    
.PARAMETER TimeInterval

.PARAMETER CaseNumber
#>

#Requires -RunAsAdministrator

param (
    [string] $UrlUploadDestination = "", 
    [string] $TimeIntervalInHours    = "25",
	[string] $CaseNumber = "temp123456",
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
   Write-Error "Url Upload destination cannot be empty"
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
$LogStart = (Get-Date).AddHours(-$TimeIntervalInHours) 
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

# GET /logexport?caseNumber={caseNumber}&start={logStart}&end={logEnd}&options={options}

Write-Host "What is this? https://$($FQDN):4242/qrs/logexport?caseNumber=$($CaseNumber)&start=$($formattedStart)&end=$($formattedEnd)&xrfkey=$($xrfkey)"

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

Write-Output  "OG upload URL: $($UploadUrl)"
Write-Output  "Upload Path before: $($UploadPath)"
Write-Output  "encoded upload URL: $($encodedPath)"

$FormattedUploadUrl = "$($UploadUrl)upload?path=$($encodedPath)&appname=explorer&filename=$($FileName)&complete=1&offset=0&uploadpath=" 

Write-Output  "UPLOAD URL: $($FormattedUploadUrl)"

#$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
#$headers.Add("Content-Type", "multipart/form-data")
# $headers = @{
#     'Content-Type' = 'multipart/form-data'
# }

# $multipartContent = [System.Net.Http.MultipartFormDataContent]::new()
# $multipartFile = $LocalPathOfZip
# $FileStream = [System.IO.FileStream]::new($multipartFile, [System.IO.FileMode]::Open)
# $fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
# $fileHeader.Name = "filedata"
# $fileHeader.FileName = $FileName
# $fileContent = [System.Net.Http.StreamContent]::new($FileStream)
# $fileContent.Headers.ContentDisposition = $fileHeader
# $multipartContent.Add($fileContent)

# $body = $multipartContent

# #make sure to add a timestamp to the filename because they will be overwritten when uploaded 

# try {
#     $response = Invoke-RestMethod -Method 'Post' -Uri $FormattedUploadUrl -Headers $headers -Body $body
#     $response | ConvertTo-Json

#     Write-Output $response
# } catch {
#     Write-Output "Error --- $($_.Exception.Response.Message) "
#     Write-Output "Error --- $($_.Exception.Message) "
# }

# Write-Output $response

$fs = [System.IO.FileStream]::New($LocalPathOfZip, [System.IO.FileMode]::Open)

$f1 = New-Object System.Net.Http.StreamContent $fs

$handler = New-Object System.Net.Http.HttpClientHandler
$handler.AllowAutoRedirect = $false # Don't follow after post redirect code 303
$client = New-Object System.Net.Http.HttpClient -ArgumentList $handler
$client.DefaultRequestHeaders.ConnectionClose = $true # Disable keep alive, get a 200 response rather than 303
$form = New-Object System.Net.Http.MultipartFormDataContent

$form.Add($f1, 'file', $FileName)

try{
    $rsp = $client.PostAsync($FormattedUploadUrl, $form).Result
    $rsp.IsSuccessStatusCode # false if 303
    $rsp.StatusCode -eq 303 # true if 303
}
catch {
    Write-Output "Error in Upload to Filecloud"
    Write-Output "Error --- $($_.Exception.Response.Message) "
    Write-Output "Error --- $($_.Exception.Message) "

}
$fs.Close(); $fs.Dispose()

Exit