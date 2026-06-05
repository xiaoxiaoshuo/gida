# G-57 Diagnose - check why XML registration is failing
$backup = "C:\Users\Administrator\clawd\agents\workspace-gid\data\system\cron-principal-backup-2026-06-05-12-12\BridgeCollector2h.xml"
[xml]$xml = Get-Content $backup -Raw
$ns = New-Object System.Xml.XmlNamespaceManager $xml.NameTable
$ns.AddNamespace("t", "http://schemas.microsoft.com/windows/2004/02/mit/task")
$root = $xml.DocumentElement

# 检查所有节点
Write-Host "=== Root element children ==="
foreach ($c in $root.ChildNodes) {
    Write-Host ("  {0}" -f $c.LocalName)
}

# 显示 LogonType/UserId/RunLevel 节点的详细信息
$principal = $xml.SelectSingleNode("/t:Task/t:Principals/t:Principal", $ns)
Write-Host "=== Principal children ==="
foreach ($c in $principal.ChildNodes) {
    Write-Host ("  {0} = {1}" -f $c.LocalName, $c.InnerText)
}

# 看健康参考任务的 XML (直接 Export 不修改)
Write-Host "=== Healthy ref: AINewsCollector_6h XML (first 30 lines) ==="
$refXml = schtasks /Query /XML /TN "\AINewsCollector_6h"
$refXml | Select-Object -First 30
