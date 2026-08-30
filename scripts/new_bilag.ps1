# new_bilag.ps1 - izveido Conta bilagu ar (neobligatu) pielikumu.
# Parbaudits 12.06.2026 (bilagi 118-141). ASCII-only fails - BOM nav vajadzigs.
# Lietosana:
#   powershell -ExecutionPolicy Bypass -File new_bilag.ps1 `
#     -Date 2026-05-24 -Amount 908.95 -DebitAccount 7000 `
#     -Description "Uno-X Hovleriet - 95 blyfri 45,47L" `
#     -AttachmentPath "C:\...\kvits.jpg" -KeyPath "C:\...\conta_api_key.txt"
# Papildus: -CreditAccount (default 1921), -DebitSupplierId (vajadzigs 2400!)

param(
  [Parameter(Mandatory=$true)][string]$Date,
  [Parameter(Mandatory=$true)][double]$Amount,
  [Parameter(Mandatory=$true)][string]$DebitAccount,
  [Parameter(Mandatory=$true)][string]$Description,
  [string]$CreditAccount = "1921",
  [string]$AttachmentPath = "",
  [int]$DebitSupplierId = 0,
  [string]$KeyPath = $env:CONTA_API_KEY_PATH
)
$ProgressPreference='SilentlyContinue'
$key = (Get-Content $KeyPath -Raw).Trim()
$base = "https://api.gateway.conta.no/accounting/organizations/$($env:CONTA_ORG_ID)"
New-Item -ItemType Directory -Force -Path C:\Temp | Out-Null

$fid = $null
if($AttachmentPath -ne ""){
  $ext = [IO.Path]::GetExtension($AttachmentPath).ToLower()
  $tmp = "C:\Temp\" + [IO.Path]::GetFileName($AttachmentPath)
  if($ext -in ".jpg",".jpeg",".png"){
    # saspiez 1200px @85% (Skatteetaten pietiek, Conta limits draudzigs)
    Add-Type -AssemblyName System.Drawing
    $img=[System.Drawing.Image]::FromFile($AttachmentPath)
    $scale=[Math]::Min(1.0,1200.0/[Math]::Max($img.Width,$img.Height))
    $bmp=New-Object System.Drawing.Bitmap ([int]($img.Width*$scale)),([int]($img.Height*$scale))
    $gr=[System.Drawing.Graphics]::FromImage($bmp)
    $gr.InterpolationMode='HighQualityBicubic'
    $gr.DrawImage($img,0,0,$bmp.Width,$bmp.Height)
    $codec=[System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()|Where-Object{$_.MimeType -eq 'image/jpeg'}
    $ep=New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0]=New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality,[long]85)
    $tmp = [IO.Path]::ChangeExtension($tmp,".jpg")
    $bmp.Save($tmp,$codec,$ep); $gr.Dispose();$bmp.Dispose();$img.Dispose()
  } else {
    Copy-Item $AttachmentPath $tmp -Force   # PDF u.c. - kope uz C:\Temp (Unicode celi lauz curl -F)
  }
  $up = curl.exe -s -X POST "$base/transaction-attachments/files" -H "apiKey: $key" -F "files=@$tmp" | ConvertFrom-Json
  $fid = $up[0].attachmentFileId
  if(-not $fid){ Write-Host "ERR upload: $($up|ConvertTo-Json -Compress)"; exit 1 }
}

$line = [ordered]@{
  date = $Date; description = $Description; amount = $Amount
  debitBookkeepingAccountNo = $DebitAccount
  creditBookkeepingAccountNo = $CreditAccount
}
if($DebitSupplierId -gt 0){ $line.debitSupplierId = $DebitSupplierId }
$body = [ordered]@{
  transactionType = "MANUAL_TRANSACTION"; date = $Date; description = $Description
  transactionLinesAdvanced = @($line)
}
if($fid){ $body.transactionAttachments = @(@{attachmentFileId=$fid}) }
$json = $body | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText("C:\Temp\bilag_tmp.json",$json)
$resp = curl.exe -s -X POST "$base/transactions-advanced" -H "apiKey: $key" -H "Content-Type: application/json" --data-binary "@C:\Temp\bilag_tmp.json" | ConvertFrom-Json
if($resp.transactionNoYear){ Write-Host ("OK bilag " + $resp.transactionNoYear) }
else { Write-Host ("ERR: " + ($resp|ConvertTo-Json -Compress -Depth 3)); exit 1 }
