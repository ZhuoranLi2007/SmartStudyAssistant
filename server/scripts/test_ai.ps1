param(
  [string]$BaseUrl = "http://127.0.0.1:8000",
  [string]$Token = "",
  [int]$StudentProfileId = 0
)

$health = Invoke-RestMethod -Uri "$BaseUrl/api/ai/health" -Method Get
$health | ConvertTo-Json -Depth 8

if (-not $Token -or $StudentProfileId -le 0) {
  Write-Host "AI health completed. Provide -Token and -StudentProfileId to run an authenticated chat smoke test."
  exit 0
}

$headers = @{ Authorization = "Bearer $Token"; "Content-Type" = "application/json" }
$payload = @{
  studentProfileId = $StudentProfileId
  clientMessageId = "smoke_$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
  message = "请根据学生档案推荐合适的数学课程"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$BaseUrl/api/ai/chat" -Method Post -Headers $headers -Body $payload | ConvertTo-Json -Depth 12
