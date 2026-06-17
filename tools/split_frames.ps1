Add-Type -AssemblyName System.Drawing

$WHITE = 232

function Split-Sheet {
    param(
        [string]$SheetPath,
        [string]$OutDir,
        [string]$Prefix,
        [int]$ExpectedBands
    )

    $bmp = New-Object System.Drawing.Bitmap -ArgumentList $SheetPath
    $W = $bmp.Width
    $H = $bmp.Height

    $rect = New-Object System.Drawing.Rectangle 0,0,$W,$H
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $bytes = [byte[]]::new($stride * $H)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $bmp.UnlockBits($data)
    $bmp.Dispose()

    # ---- detect content rows ----
    $rowHasContent = [bool[]]::new($H)
    for ($y = 0; $y -lt $H; $y++) {
        $count = 0
        $base = $y * $stride
        for ($x = 0; $x -lt $W; $x++) {
            $i = $base + $x * 4
            $bb = $bytes[$i]; $gg = $bytes[$i+1]; $rr = $bytes[$i+2]; $aa = $bytes[$i+3]
            if ($aa -gt 8 -and -not ($rr -gt $WHITE -and $gg -gt $WHITE -and $bb -gt $WHITE)) { $count++ }
        }
        if ($count -gt 6) { $rowHasContent[$y] = $true }
    }

    $bands = New-Object System.Collections.ArrayList
    $start = -1
    for ($y = 0; $y -lt $H; $y++) {
        if ($rowHasContent[$y]) {
            if ($start -lt 0) { $start = $y }
        } else {
            if ($start -ge 0) {
                if (($y - $start) -ge 20) { [void]$bands.Add(@($start, ($y-1))) }
                $start = -1
            }
        }
    }
    if ($start -ge 0 -and ($H - $start) -ge 20) { [void]$bands.Add(@($start, ($H-1))) }

    Write-Output "[$Prefix] detected $($bands.Count) bands (expected $ExpectedBands)"
    if ($bands.Count -ne $ExpectedBands) {
        Write-Output "[$Prefix] falling back to equal split"
        $bands = New-Object System.Collections.ArrayList
        $bh = [math]::Floor($H / $ExpectedBands)
        for ($k = 0; $k -lt $ExpectedBands; $k++) {
            $y0 = $k * $bh
            if ($k -eq $ExpectedBands-1) { $y1 = $H-1 } else { $y1 = ($k+1)*$bh - 1 }
            [void]$bands.Add(@($y0, $y1))
        }
    }

    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

    $idx = 0
    foreach ($band in $bands) {
        $y0 = $band[0]; $y1 = $band[1]
        $minX = $W; $maxX = 0
        for ($y = $y0; $y -le $y1; $y++) {
            $base = $y * $stride
            for ($x = 0; $x -lt $W; $x++) {
                $i = $base + $x*4
                $bb = $bytes[$i]; $gg = $bytes[$i+1]; $rr = $bytes[$i+2]; $aa = $bytes[$i+3]
                if ($aa -gt 8 -and -not ($rr -gt $WHITE -and $gg -gt $WHITE -and $bb -gt $WHITE)) {
                    if ($x -lt $minX) { $minX = $x }
                    if ($x -gt $maxX) { $maxX = $x }
                }
            }
        }
        $pad = 6
        $minX = [math]::Max(0, $minX - $pad); $maxX = [math]::Min($W-1, $maxX + $pad)
        $by0 = [math]::Max(0, $y0 - $pad); $by1 = [math]::Min($H-1, $y1 + $pad)
        $cw = $maxX - $minX + 1
        $ch = $by1 - $by0 + 1

        $cb = [byte[]]::new($cw * $ch * 4)
        for ($yy = 0; $yy -lt $ch; $yy++) {
            $srow = ($by0+$yy) * $stride
            $drow = $yy * $cw * 4
            for ($xx = 0; $xx -lt $cw; $xx++) {
                $si = $srow + ($minX+$xx) * 4
                $di = $drow + $xx * 4
                $cb[$di]   = $bytes[$si]
                $cb[$di+1] = $bytes[$si+1]
                $cb[$di+2] = $bytes[$si+2]
                $cb[$di+3] = $bytes[$si+3]
            }
        }

        # flood fill white background from the borders -> transparent
        $visited = [bool[]]::new($cw * $ch)
        $stack = New-Object System.Collections.Generic.Stack[int]
        for ($x = 0; $x -lt $cw; $x++) {
            $q = $x;             if (-not $visited[$q]) { $visited[$q]=$true; $stack.Push($q) }
            $q = ($ch-1)*$cw+$x; if (-not $visited[$q]) { $visited[$q]=$true; $stack.Push($q) }
        }
        for ($y = 0; $y -lt $ch; $y++) {
            $q = $y*$cw;        if (-not $visited[$q]) { $visited[$q]=$true; $stack.Push($q) }
            $q = $y*$cw+($cw-1); if (-not $visited[$q]) { $visited[$q]=$true; $stack.Push($q) }
        }
        while ($stack.Count -gt 0) {
            $p = $stack.Pop()
            $di = $p * 4
            $bb = $cb[$di]; $gg = $cb[$di+1]; $rr = $cb[$di+2]; $aa = $cb[$di+3]
            if ($aa -gt 0 -and $rr -gt $WHITE -and $gg -gt $WHITE -and $bb -gt $WHITE) {
                $cb[$di+3] = 0
                $px = $p % $cw; $py = [math]::Floor($p / $cw)
                if ($px -gt 0)     { $n=$p-1;   if (-not $visited[$n]) { $visited[$n]=$true; $stack.Push($n) } }
                if ($px -lt $cw-1) { $n=$p+1;   if (-not $visited[$n]) { $visited[$n]=$true; $stack.Push($n) } }
                if ($py -gt 0)     { $n=$p-$cw; if (-not $visited[$n]) { $visited[$n]=$true; $stack.Push($n) } }
                if ($py -lt $ch-1) { $n=$p+$cw; if (-not $visited[$n]) { $visited[$n]=$true; $stack.Push($n) } }
            }
        }

        $out = New-Object System.Drawing.Bitmap -ArgumentList $cw, $ch, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $orect = New-Object System.Drawing.Rectangle 0,0,$cw,$ch
        $odata = $out.LockBits($orect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        [System.Runtime.InteropServices.Marshal]::Copy($cb, 0, $odata.Scan0, $cb.Length)
        $out.UnlockBits($odata)
        $outPath = Join-Path $OutDir ("{0}_{1}.png" -f $Prefix, $idx)
        $out.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $out.Dispose()
        Write-Output ("  saved {0}  ({1}x{2})  src-rows {3}..{4}" -f (Split-Path $outPath -Leaf), $cw, $ch, $y0, $y1)
        $idx++
    }
}

$root = "C:\Users\harry\gravic\gravic-hackathon-2026\assets"
Split-Sheet -SheetPath "$root\Spiders\spiders.png" -OutDir "$root\Spiders" -Prefix "spider" -ExpectedBands 4
Split-Sheet -SheetPath "$root\EggSac\sac.png" -OutDir "$root\EggSac" -Prefix "sac" -ExpectedBands 2
