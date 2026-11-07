# Assemble isolated native Rainmeter captures; clip away the desktop at rounded corners.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$root=Split-Path $PSScriptRoot -Parent
$out=Join-Path $root 'previews'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$board=New-Object Drawing.Bitmap 970,810
$g=[Drawing.Graphics]::FromImage($board)
$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([Drawing.ColorTranslator]::FromHtml('#1B201D'))
$titleFont=New-Object Drawing.Font 'Segoe UI',24
$smallFont=New-Object Drawing.Font 'Segoe UI',10
$white=New-Object Drawing.SolidBrush ([Drawing.ColorTranslator]::FromHtml('#F4F2EA'))
$muted=New-Object Drawing.SolidBrush ([Drawing.ColorTranslator]::FromHtml('#AFBBAF'))
$g.DrawString('Nerd Widgets for Windows',$titleFont,$white,28,22)
$g.DrawString('Native Rainmeter skins  /  Live Windows readings  /  Light · Peach',$smallFont,$muted,31,68)
$placements=@(@('battery',32,118,12),@('network',32,344,12),@('vitals',32,532,12),@('settings',439,118,16))
foreach($p in $placements) {
    $src=[Drawing.Image]::FromFile((Join-Path $root ".tools\$($p[0])-capture.jpg"))
    $tile=New-Object Drawing.Bitmap $src.Width,$src.Height
    $tg=[Drawing.Graphics]::FromImage($tile)
    $tg.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $path=New-Object Drawing.Drawing2D.GraphicsPath
    $d=[single]($p[3]*2);$w=[single]$src.Width;$h=[single]$src.Height
    $path.AddArc(0,0,$d,$d,180,90)
    $path.AddArc(($w-$d),0,$d,$d,270,90)
    $path.AddArc(($w-$d),($h-$d),$d,$d,0,90)
    $path.AddArc(0,($h-$d),$d,$d,90,90)
    $path.CloseFigure()
    $tg.SetClip($path)
    $tg.DrawImage($src,0,0,$src.Width,$src.Height)
    $tile.Save((Join-Path $out "$($p[0]).png"),[Drawing.Imaging.ImageFormat]::Png)
    $g.DrawImageUnscaled($tile,[int]$p[1],[int]$p[2])
    $path.Dispose();$tg.Dispose();$tile.Dispose();$src.Dispose()
}
$g.DrawString('Actual Rainmeter captures. Values reflect the preview session.',$smallFont,$muted,31,768)
$board.Save((Join-Path $out 'NerdWidgets-preview.png'),[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$board.Dispose();$titleFont.Dispose();$smallFont.Dispose();$white.Dispose();$muted.Dispose()
Write-Host (Join-Path $out 'NerdWidgets-preview.png')
