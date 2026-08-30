# get_invoice_pdf.ps1 - lejupielade Conta faktura PDF.
# Parbaudits 18.06.2026 (faktura 31012055).
# ASCII-only fails - BOM nav vajadzigs.
#
# Soli: GET /files/{invoiceFileId} -> JSON ar presigned S3 'fileUrl' (bez auth, der ~1h) -> lejupielade PDF.
#
# Lietosana:
#   powershell -ExecutionPolicy Bypass -File get_invoice_pdf.ps1 `
#     -FileId 174065286 -Out "<your-folder>\Faktura_31012055.pdf" `
#     -KeyPath "<your-folder>\conta_api_key.txt"
# (FileId = atbildes 'invoiceFileId' no new_invoice.ps1 vai no GET /invoices/{id})

param(
  [Parameter(Mandatory=$true)][int]$FileId,
  [Parameter(Mandatory=$true)][string]$Out,
  [string]$KeyPath = $env:CONTA_API_KEY_PATH
)
$ProgressPreference = 'SilentlyContinue'
$key  = (Get-Content $KeyPath -Raw).Trim()
$base = "https://api.gateway.conta.no/invoice/organizations/$($env:CONTA_ORG_ID)"
$meta = Invoke-RestMethod -Uri "$base/files/$FileId" -Headers @{apiKey=$key} -Method GET
Invoke-WebRequest -Uri $meta.fileUrl -OutFile $Out
Write-Host ("SAVED " + $Out + " -> " + (Get-Item $Out).Length + " bytes  (" + $meta.filename + ")")
