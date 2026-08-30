# new_invoice.ps1 - izveido Conta izejoso faktura (klienta rekinu).
# Parbaudits 18.06.2026 (faktura 31012055 Pal Nordby, 14458 + 25% MVA = 18072.50).
# ASCII-only fails - BOM nav vajadzigs. Unicode (o-slash, a-ring) padod kaa -Description / -CustomerReference parametru.
#
# UZMANIBU: POST izveido UZREIZ IZRAKSTITU faktura ar realu numuru (nav "utkast"/melnraksts).
#           Forfall/dati JAUZLIEK PAREIZI seit - velak caur API NEVAR labot (skat. SKILL.md).
#
# Lietosana:
#   powershell -ExecutionPolicy Bypass -File new_invoice.ps1 `
#     -CustomerId 7651711 -InvoiceDate 2026-06-18 -DueDate 2026-06-25 `
#     -Description "Montering av gipsplater og maling" -Price 14458 `
#     -CustomerReference "Pal Nordby" `
#     -KeyPath "<your-folder>\conta_api_key.txt"
#
# Papildus parametri: -Quantity (def 1), -VatCode (def "high"=25%; "medium"=15%; "low"=12%; "none"/"exempt"=0),
#                     -OrgReference (def "MARTINS GIRSS"), -Discount (def 0), -Language (def "NO"), -Currency (def "NOK")

param(
  [Parameter(Mandatory=$true)][int]$CustomerId,
  [Parameter(Mandatory=$true)][string]$InvoiceDate,    # ISO yyyy-MM-dd
  [Parameter(Mandatory=$true)][string]$DueDate,        # ISO yyyy-MM-dd (forfall - uzliec pareizi uzreiz!)
  [Parameter(Mandatory=$true)][string]$Description,    # rindas teksts (norv. valoda)
  [Parameter(Mandatory=$true)][double]$Price,          # neto cena (eks. mva)
  [int]$Quantity = 1,
  [double]$Discount = 0,
  [string]$VatCode = "high",
  [string]$CustomerReference = "",
  [string]$OrgReference = "MARTINS GIRSS",
  [string]$Language = "NO",
  [string]$Currency = "NOK",
  [string]$KeyPath = $env:CONTA_API_KEY_PATH
)
$ProgressPreference = 'SilentlyContinue'
$key  = (Get-Content $KeyPath -Raw).Trim()
$base = "https://api.gateway.conta.no/invoice/organizations/$($env:CONTA_ORG_ID)"

# SVARIGI: NEPIEVIENO bankAccountId / vatId / bookkeepingAccountNo - serveris tos pieliek pats.
# Ja tos iekauj -> 400 "forbidden for this activity".
$line = [ordered]@{
  description = $Description
  vatCode     = $VatCode      # "high"=25% (vatId 13, konts 3000)
  price       = $Price
  quantity    = $Quantity
  discount    = $Discount
  lineNo      = 1
}
$body = [ordered]@{
  type            = "NORMAL"
  customerId      = $CustomerId
  invoiceDate     = $InvoiceDate
  invoiceDueDate  = $DueDate
  deliveryDate    = $InvoiceDate
  invoiceLanguage = $Language
  invoiceCurrency = $Currency
  orgReference    = $OrgReference
  showDiscount    = $true
  invoiceLines    = @($line)
}
if($CustomerReference -ne ""){ $body.customerReference = $CustomerReference }

$json  = $body | ConvertTo-Json -Depth 8
$bytes = [System.Text.Encoding]::UTF8.GetBytes($json)   # UTF-8 o-slash/a-ring deel
try {
  $r = Invoke-RestMethod -Uri "$base/invoices" -Headers @{apiKey=$key} -Method POST -ContentType "application/json; charset=utf-8" -Body $bytes
  Write-Host ("OK faktura " + $r.invoiceNo + " (id " + $r.id + ")  neto=" + $r.sumNet + " mva=" + $r.sumVAT + " kopa=" + $r.sumTotal + "  forfall=" + $r.invoiceDueDate + "  status=" + $r.status + "  fileId=" + $r.invoiceFileId)
} catch {
  $resp = $_.Exception.Response
  if($resp){ $sr = New-Object IO.StreamReader($resp.GetResponseStream()); Write-Host ("ERR: " + $sr.ReadToEnd()) }
  Write-Host ("MSG: " + $_.Exception.Message)
  exit 1
}
