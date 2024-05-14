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
	[string] $CaseNumber = "",

	[Parameter()]
    [string] $UserName   = $env:USERNAME, 
    [Parameter()]
    [string] $UserDomain = $env:USERDOMAIN,
    [Parameter()]
    [string] $FQDN       = [string][System.Net.Dns]::GetHostByName(($env:computerName)).Hostname, 
    [Parameter()]
    [string] $CertIssuer = [string][System.Net.Dns]::GetHostByName(($env:computerName)).Hostname
)

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

# HTTP headers to be used in REST API call
$HttpHeaders = @{}
$HttpHeaders.Add("X-Qlik-Xrfkey","$XrfKey")
$HttpHeaders.Add("X-Qlik-User", "UserDirectory=$UserDomain;UserId=$UserName")
$HttpHeaders.Add("Content-Type", "application/json")

# HTTP body for REST API call
$HttpBody = @{}

# GET /logexport?caseNumber={caseNumber}&start={logStart}&end={logEnd}&options={options}

# Invoke REST API call
$Response = Invoke-RestMethod -Uri "https://$($FQDN):4242/qrs/logexport?caseNumber=$($CaseNumber)&start=$($LogStart)&end=$($LogEnd)&xrfkey=$($xrfkey)" `
                  -Method GET `
                  -Headers $HttpHeaders  `
                  -Body $HttpBody `
                  -ContentType 'application/json' `
                  -Certificate $ClientCert

# Make GET call to /qrs/logexport from repository service

$responseStatus = [int]$Response.StatusCode
Write-Host $responseStatus
# if successful
# save zip output locally


# make post call to filecloud to upload zip output