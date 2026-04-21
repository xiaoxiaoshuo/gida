$ErrorActionPreference = "Continue"
try {
    $raw = Invoke-WebRequest 'https://www.techradar.com/rss' -TimeoutSec 15 -UseBasicParsing
    Write-Host "Status:" $raw.StatusCode
    Write-Host "ContentType:" $raw.ContentType
    Write-Host "Content length:" $raw.Content.Length
    [xml]$xml = $raw.Content
    Write-Host "xml type:" $xml.GetType().FullName
    Write-Host "xml.RSS:" $xml.RSS
    Write-Host "xml.RSS.Channel:" $xml.RSS.Channel
    Write-Host "xml.RSS.Channel.Item.Count:" $xml.RSS.Channel.Item.Count
} catch {
    Write-Host "ERR:" $_.Exception.Message
    Write-Host "ERR type:" $_.Exception.GetType().FullName
}
