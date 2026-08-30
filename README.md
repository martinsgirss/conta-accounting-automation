# conta-accounting-automation

PowerShell tooling for the [Conta.no](https://conta.no) API — creates bookkeeping entries,
issues customer invoices, and retrieves invoice PDFs for a Norwegian AS without touching
the web interface.

## The problem

Closing a month in a Norwegian limited company means matching every bank transaction to a
receipt, creating a `bilag` for each one, attaching the document, and repeating it a hundred
times through a web form. It is the same six clicks, over and over, and every one of them is
a chance to book to the wrong account.

## What it does

| Script | What it does |
|---|---|
| `new_bilag.ps1` | Creates a bookkeeping entry with debit/credit lines, VAT code and attachment |
| `new_invoice.ps1` | Issues a customer invoice with line items and Norwegian MVA handling |
| `get_invoice_pdf.ps1` | Fetches an issued invoice PDF through the presigned download URL |

The scripts encode the parts of the API that are not obvious from the documentation:
which fields the API rejects on POST because it fills them itself
(`bankAccountId`, `vatId`, `bookkeepingAccountNo`), how VAT codes map to Norwegian MVA
rates, and the two-step presigned S3 flow for retrieving a PDF.

## Known limitation

An issued invoice cannot be edited, deleted, or re-sent through the API. Sending has to
happen in the Conta interface. This is a constraint of the platform, not of these scripts,
and it is worth knowing before you build a workflow around it.

## Stack

PowerShell 7 · Conta REST API · Norwegian accounting rules (NS 4102 chart of accounts, MVA codes)

## Result

Monthly bookkeeping for a construction AS went from a full day of manual entry to well
under an hour. In production since early 2026.

## Setup

```powershell
$env:CONTA_API_KEY_PATH = "C:\path\to\conta_api_key.txt"   # file containing the API key
$env:CONTA_ORG_ID       = "123456"                          # your Conta organization id

.\scripts\new_bilag.ps1 -Date 2026-06-15 -Description "Fuel" -Amount 842.50
```

The API key file and organization id stay outside the repository — never commit either.

## License

MIT
