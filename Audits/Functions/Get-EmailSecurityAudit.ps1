function Get-EmailSecurityAudit {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )

    # Every verified domain except the built-in onmicrosoft.com ones
    $domains = @(Get-MgDomain -All -ErrorAction Stop | Where-Object { $_.IsVerified -and $_.Id -notlike "*.onmicrosoft.com" })

    function Get-TxtRecords([string]$name) {
        @(Resolve-DnsName -Name $name -Type TXT -ErrorAction SilentlyContinue |
          Where-Object { $_.Strings } | ForEach-Object { $_.Strings -join "" })
    }

    foreach ($domain in $domains.Id) {

        # SPF: which servers may send mail as this domain
        $spf = @(Get-TxtRecords $domain | Where-Object { $_ -like "v=spf1*" })
        $spfReason = if ($spf.Count -eq 0) { "No SPF record: anyone can send email pretending to be $domain" }
                     elseif ($spf.Count -gt 1) { "$($spf.Count) SPF records: receivers treat that as an error, so SPF doesn't work" }
                     elseif ($spf[0] -match '\+all\b') { "SPF ends in +all: it allows every server in the world to send as $domain" }
                     elseif ($spf[0] -match '\?all\b') { "SPF ends in ?all (neutral): spoofed mail isn't treated as suspicious" }
        New-AuditFinding -Check "EmailSecurity" -Name $domain -Detail "SPF: $(if ($spf) { $spf -join ' | ' } else { 'none' })" `
                         -Flagged ([bool]$spfReason) -Reason $spfReason

        # DMARC: what receivers should do with mail that fails SPF/DKIM
        $dmarc = @(Get-TxtRecords "_dmarc.$domain" | Where-Object { $_ -like "v=DMARC1*" }) | Select-Object -First 1
        $policy = if ($dmarc -match '\bp=(\w+)') { $Matches[1].ToLower() }
        $dmarcReason = if (-not $dmarc) { "No DMARC record: spoofed mail from $domain isn't blocked or reported" }
                       elseif ($policy -eq "none") { "DMARC is p=none (monitor only): spoofed mail is still delivered" }
        New-AuditFinding -Check "EmailSecurity" -Name $domain -Detail "DMARC: $(if ($dmarc) { $dmarc } else { 'none' })" `
                         -Flagged ([bool]$dmarcReason) -Reason $dmarcReason

        # DKIM: Microsoft 365 publishes keys through selector1/selector2 CNAMEs
        $dkim = @("selector1", "selector2" | ForEach-Object {
            Resolve-DnsName -Name "$_._domainkey.$domain" -Type CNAME -ErrorAction SilentlyContinue | Where-Object { $_.NameHost }
        })
        New-AuditFinding -Check "EmailSecurity" -Name $domain -Detail "DKIM: $(if ($dkim) { "$($dkim.Count) selector(s)" } else { 'none' })" `
                         -Flagged ($dkim.Count -eq 0) -Reason $(if (-not $dkim) { "No DKIM selectors: mail from $domain isn't signed, so it's easier to spoof and more likely to hit spam" })
    }
}
