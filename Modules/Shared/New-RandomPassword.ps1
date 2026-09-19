function New-RandomPassword {
    [CmdletBinding()]
    param(
        [ValidateRange(12, 128)]
        [int]$Length = 16
    )

    # No look-alike characters (0/O, 1/l/I) since people have to type it
    $sets = @(
        'ABCDEFGHJKLMNPQRSTUVWXYZ'
        'abcdefghijkmnpqrstuvwxyz'
        '23456789'
        '!@#$%&*?-+'
    )
    $all = -join $sets
    $rng = [System.Security.Cryptography.RandomNumberGenerator]

    # One from each set so it always meets AD complexity, the rest from everything
    $chars = @($sets | ForEach-Object { $_[$rng::GetInt32($_.Length)] })
    $chars += 1..($Length - $sets.Count) | ForEach-Object { $all[$rng::GetInt32($all.Length)] }

    # Shuffle so the guaranteed characters aren't always first
    return -join ($chars | Sort-Object { $rng::GetInt32([int]::MaxValue) })
}
