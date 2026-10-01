# Generates placeholder dish photos (PNG) for local QA — one per dish name
# given on stdin (one per line) — into backend/.data/qa-media. Local only;
# these are drawn cards, not real photographs.
param([string]$OutDir = "$PSScriptRoot\..\.data\qa-media")
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$palette = @('#E8590C','#2F9E44','#C2255C','#1971C2','#F08C00','#6741D9','#0B7285','#A61E4D','#5C940D','#862E9C')
$i = 0
foreach ($line in [Console]::In.ReadToEnd() -split "`n") {
  $name = $line.Trim()
  if (-not $name) { continue }
  $slug = ($name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
  $bmp = New-Object System.Drawing.Bitmap 640, 480
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.TextRenderingHint = 'AntiAlias'
  $bg = [System.Drawing.ColorTranslator]::FromHtml($palette[$i % $palette.Count])
  $g.Clear($bg)
  # a soft "plate" circle
  $plate = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 255, 255, 255))
  $g.FillEllipse($plate, 200, 90, 240, 240)
  $font = New-Object System.Drawing.Font 'Segoe UI', 30, ([System.Drawing.FontStyle]::Bold)
  $small = New-Object System.Drawing.Font 'Segoe UI', 14
  $white = [System.Drawing.Brushes]::White
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = 'Center'
  $g.DrawString($name, $font, $white, (New-Object System.Drawing.RectangleF 20, 350, 600, 90), $fmt)
  $g.DrawString('Latur Spice House - sample photo', $small, $white, (New-Object System.Drawing.RectangleF 20, 440, 600, 30), $fmt)
  $path = Join-Path $OutDir "$slug.png"
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output "$slug.png"
  $i++
}
