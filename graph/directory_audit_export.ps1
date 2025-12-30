<#
Reference script: Export Entra ID directory audit logs via Microsoft Graph (directoryAudits).

Purpose
- Demonstrates a Microsoft Graph-based extraction approach for group membership/ownership changes.
- Documents the practical limitation that Graph audit log availability depends on tenant retention.
- Complements the Log Analytics approach (AuditLogs table) used for longer retention when configured.

Safety
- All IDs and names in this script are placeholders.
- Do not paste real tenant/group identifiers into a public repository.

Prerequisites
- Microsoft Graph PowerShell SDK installed (Microsoft.Graph)
- App registration with certificate-based auth (client credentials)
- Appropriate Graph application permissions (e.g., AuditLog.Read.All) with admin consent
#>

# ----------------------------
# Configuration (placeholders)
# ----------------------------
$TenantId            = "<TENANT_ID>"
$ClientId            = "<CLIENT_ID>"
$CertificateThumbprint = "<CERT_THUMBPRINT>"

# Target groups (placeholders)
$GroupIds = @(
  "00000000-0000-0000-0000-000000000001",
  "00000000-0000-0000-0000-000000000002"
)

# Activities to keep
$Activities = @(
  "Add member to group",
  "Remove member from group",
  "Add owner to group",
  "Remove owner from group"
)

# Desired lookback (note: actual availability depends on tenant retention)
$Start = (Get-Date).AddDays(-365).ToString("o")

# ----------------------------
# Connect (app-only with cert)
# ----------------------------
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint | Out-Null

# ----------------------------
# Retrieve audit logs
# ----------------------------
$results = @()
$uri = "/v1.0/auditLogs/directoryAudits?`$filter=activityDateTime ge $Start&`$top=999"

do {
  $resp = Invoke-MgGraphRequest -Method GET -Uri $uri
  if ($null -ne $resp.value) { $results += $resp.value }
  $uri = $resp.'@odata.nextLink'
} while ($uri)

# ----------------------------
# Filter + transform
# ----------------------------
$filtered =
  $results |
  Where-Object { $Activities -contains $_.activityDisplayName } |
  Where-Object {
    # Keep events where a target resource is a Group in our list
    ($_.targetResources | Where-Object { $_.type -eq "Group" -and ($GroupIds -contains $_.id) }).Count -gt 0
  } |
  ForEach-Object {
    $group = $_.targetResources | Where-Object { $_.type -eq "Group" } | Select-Object -First 1
    $affected = $_.targetResources | Where-Object { $_.type -in @("User","ServicePrincipal") }

    [pscustomobject]@{
      activityDateTime     = $_.activityDateTime
      activityDisplayName  = $_.activityDisplayName
      groupId              = $group.id
      groupName            = $group.displayName
      actorUPN             = $_.initiatedBy.user.userPrincipalName
      actorApp             = $_.initiatedBy.app.displayName
      affectedDisplayNames = ($affected.displayName -join "; ")
      affectedObjectIds    = ($affected.id -join "; ")
      result               = $_.result
      correlationId        = $_.correlationId
    }
  }

# ----------------------------
# Output
# ----------------------------
$filtered |
  Sort-Object activityDateTime -Descending |
  Export-Csv ".\GroupAccessChanges.csv" -NoTypeInformation

Write-Host "Export complete: GroupAccessChanges.csv"
Write-Host "Note: If results look incomplete for a 12-month window, validate tenant audit log retention and whether logs are streamed to Log Analytics."
