#Requires -RunAsAdministrator

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "multipart/form-data")

$multipartContent = [System.Net.Http.MultipartFormDataContent]::new()
$multipartFile = "C:\ProgramData\Qlik\Sense\Repository\TempContent\97b3a962-51d4-45db-9fd5-838ac756f99d\LogCollector_temp123456.zip"
$FileStream = [System.IO.FileStream]::new($multipartFile, [System.IO.FileMode]::Open)
$fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
$fileHeader.Name = "filedata"
$fileHeader.FileName = "LogCollector_temp123456.zip"
$fileContent = [System.Net.Http.StreamContent]::new($FileStream)
$fileContent.Headers.ContentDisposition = $fileHeader
$multipartContent.Add($fileContent)

$body = $multipartContent

try {

$response = Invoke-RestMethod "https://files.qlik.com/upload?path=%2FSHARED%2F%21UBQFBx7wFdQ2OoMnV%2FjavEIJYoP6KL35Tt&appname=explorer&filename=LogCollector_temp123456.zip&complete=1&offset=0&uploadpath=" -Method 'Post' -Headers $headers -Body $body
$response | ConvertTo-Json
} catch {
	$FileStream.Close()
	$_
}
$FileStream.Close()
Exit