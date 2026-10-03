# Builds the Google Play graphics from real phone screenshots in store/raw:
#   store/screenshots/*.png   (1080x1920, colourful, captions, tilted phone)
#   store/feature_graphic_1024x500.png
# Run:  powershell -ExecutionPolicy Bypass -File store\make_graphics.ps1
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$raw = Join-Path $root 'raw'
$out = Join-Path $root 'screenshots'
New-Item -ItemType Directory -Force $out | Out-Null
$logoPath = Join-Path (Split-Path -Parent $root) 'docs\logo.png'

function C([int]$a, [int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

function New-RoundedPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

function Draw-Star($g, [float]$cx, [float]$cy, [float]$r, $brush) {
  $pts = @()
  for ($i = 0; $i -lt 10; $i++) {
    $rr = if ($i % 2 -eq 0) { $r } else { $r * 0.45 }
    $a = -[Math]::PI / 2 + $i * [Math]::PI / 5
    $pts += New-Object System.Drawing.PointF(($cx + [Math]::Cos($a) * $rr), ($cy + [Math]::Sin($a) * $rr))
  }
  $g.FillPolygon($brush, [System.Drawing.PointF[]]$pts)
}

function New-Canvas([int]$w, [int]$h, $c1, $c2) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.TextRenderingHint = 'AntiAliasGridFit'
  $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
  $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 60)
  $g.FillRectangle($br, $rect)
  $br.Dispose()
  # soft bubbles
  $soft = New-Object System.Drawing.SolidBrush((C 38 255 255 255))
  $softer = New-Object System.Drawing.SolidBrush((C 24 255 255 255))
  $g.FillEllipse($soft, [int](-0.18 * $w), [int](0.10 * $h), [int](0.55 * $w), [int](0.55 * $w))
  $g.FillEllipse($softer, [int](0.62 * $w), [int](-0.06 * $h), [int](0.55 * $w), [int](0.55 * $w))
  $g.FillEllipse($soft, [int](0.70 * $w), [int](0.72 * $h), [int](0.50 * $w), [int](0.50 * $w))
  # sparkles
  $gold = New-Object System.Drawing.SolidBrush((C 255 255 224 102))
  $white = New-Object System.Drawing.SolidBrush((C 230 255 255 255))
  $spots = @(@(0.045, 0.012, 0.018, 'g'), @(0.955, 0.014, 0.014, 'w'), @(0.80, 0.165, 0.022, 'g'), @(0.05, 0.20, 0.012, 'w'),
             @(0.95, 0.52, 0.016, 'g'), @(0.04, 0.60, 0.018, 'w'), @(0.93, 0.90, 0.020, 'g'), @(0.07, 0.93, 0.015, 'g'))
  foreach ($s in $spots) {
    $b = if ($s[3] -eq 'g') { $gold } else { $white }
    Draw-Star $g ($s[0] * $w) ($s[1] * $h) ($s[2] * $w) $b
  }
  return @{ bmp = $bmp; g = $g }
}

# file, title, subtitle, pill, colour1, colour2, tilt
$shots = @(
  @('01_home.png',       'Your cute cyber guardian',         'A pet that gets sick when your phone is in danger', 'FREE  -  NO ADS',        (C 255 91 75 255),  (C 255 34 199 230), -3.5),
  @('02_shield.png',     'All your security tools',          'Link, message, QR, number & password checks',       'EVERYTHING IN ONE APP',  (C 255 0 160 150),  (C 255 52 120 255), 3.5),
  @('03_link.png',       'Catch fake links before you tap',  'Smart detection + cloud checks',                    'SCAM LINK ALERT',        (C 255 255 74 98),  (C 255 255 146 60), -3.5),
  @('04_message.png',    'Spot scam messages instantly',     'On-device AI: English, Urdu, Hindi & more',         '100% ON YOUR PHONE',     (C 255 232 62 140), (C 255 255 140 66), 3.5),
  @('05_deepscan.png',   'Deep Scan your phone',             'Finds spy apps, weak lock & risky settings',        'ONE-TAP REMOVE',         (C 255 80 70 230),  (C 255 150 70 235), -3.5),
  @('06_protection.png', 'Live Guard + Shield VPN',          'Alerts for scams in WhatsApp & SMS',                'ALWAYS WATCHING',        (C 255 22 163 74),  (C 255 24 190 200), 3.5),
  @('07_pal_ai.png',     'Pal AI speaks your language',      'Ask anything - English, Roman Urdu, Hindi...',      'ASK ME ANYTHING',        (C 255 120 80 250), (C 255 40 130 255), -3.5),
  @('08_pets.png',       'Pick your pet and its voice',      'Cat, bunny, bear, puppy or fox',                    'COLLECT OUTFITS & COINS', (C 255 255 120 50), (C 255 235 70 160), 3.5),
  @('09_threats.png',    'Every threat in one log',          'Filter, review and clear - plus a daily cyber tip', 'DAILY CYBER TIP',        (C 255 240 80 80),  (C 255 130 80 240), -3.5)
)

$logo = [System.Drawing.Image]::FromFile($logoPath)
$n = 0
foreach ($s in $shots) {
  $n++
  $src = [System.Drawing.Image]::FromFile((Join-Path $raw $s[0]))
  $cv = New-Canvas 1080 1920 $s[4] $s[5]
  $bmp = $cv.bmp; $g = $cv.g

  # title + subtitle
  $fTitle = New-Object System.Drawing.Font('Segoe UI Black', 56, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $fSub = New-Object System.Drawing.Font('Segoe UI Semibold', 31, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $fPill = New-Object System.Drawing.Font('Segoe UI Black', 24, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $shadowB = New-Object System.Drawing.SolidBrush((C 70 0 0 60))
  $g.DrawString($s[1], $fTitle, $shadowB, (New-Object System.Drawing.RectangleF(63, 66, 960, 110)), $sf)
  $g.DrawString($s[1], $fTitle, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(60, 62, 960, 110)), $sf)
  $g.DrawString($s[2], $fSub, (New-Object System.Drawing.SolidBrush((C 235 255 255 255))), (New-Object System.Drawing.RectangleF(60, 176, 960, 56)), $sf)

  # pill badge
  $pillW = [int]($g.MeasureString($s[3], $fPill).Width + 60)
  $px = [int]((1080 - $pillW) / 2)
  $pp = New-RoundedPath $px 244 $pillW 50 25
  $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 255 255 255))), $pp)
  $g.DrawString($s[3], $fPill, (New-Object System.Drawing.SolidBrush((C 255 40 40 90))), (New-Object System.Drawing.RectangleF($px, 244, $pillW, 50)), $sf)

  # tilted phone (status bar cropped away)
  $cropY = 120
  $cropH = $src.Height - $cropY
  $dw = 700
  $dh = 1540
  $dx = [int]((1080 - $dw) / 2)
  $dy = 340
  $srcRectH = [int]($dh * $src.Width / $dw)
  if ($srcRectH -gt $cropH) { $srcRectH = $cropH }
  $state = $g.Save()
  $g.TranslateTransform(540, ($dy + $dh / 2))
  $g.RotateTransform([float]$s[6])
  $g.TranslateTransform(-540, -($dy + $dh / 2))
  $shadow = New-RoundedPath ($dx - 4) ($dy + 22) ($dw + 8) ($dh + 4) 62
  $g.FillPath((New-Object System.Drawing.SolidBrush((C 80 0 0 50))), $shadow)
  $frame = New-RoundedPath ($dx - 16) ($dy - 16) ($dw + 32) ($dh + 32) 66
  $g.FillPath((New-Object System.Drawing.SolidBrush((C 255 14 18 34))), $frame)
  $g.DrawPath((New-Object System.Drawing.Pen((C 255 255 255 255), 4)), $frame)
  $clip = New-RoundedPath $dx $dy $dw $dh 50
  $g.SetClip($clip)
  $g.DrawImage($src, (New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)),
               (New-Object System.Drawing.Rectangle(0, $cropY, $src.Width, $srcRectH)), [System.Drawing.GraphicsUnit]::Pixel)
  $g.ResetClip()
  $g.Restore($state)

  # logo badge, bottom corner
  $g.DrawImage($logo, 36, 1770, 120, 120)

  $name = Join-Path $out ('{0:D2}_{1}' -f $n, ($s[0] -replace '^\d+_', ''))
  $bmp.Save($name, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $src.Dispose()
  Write-Host "made $name"
}

# ---- feature graphic 1024x500 ----
$cv = New-Canvas 1024 500 (C 255 91 75 255) (C 255 34 199 230)
$bmp = $cv.bmp; $g = $cv.g
$g.DrawImage($logo, 36, 90, 300, 300)
$f1 = New-Object System.Drawing.Font('Segoe UI Black', 84, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$f2 = New-Object System.Drawing.Font('Segoe UI Semibold', 31, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$f3 = New-Object System.Drawing.Font('Segoe UI Semibold', 25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$white = [System.Drawing.Brushes]::White
$g.DrawString('ShieldPal', $f1, (New-Object System.Drawing.SolidBrush((C 70 0 0 60))), 344, 104)
$g.DrawString('ShieldPal', $f1, $white, 340, 100)
$g.DrawString('Your cute cyber guardian', $f2, $white, 344, 205)
$bul = [string][char]0x2022
$g.DrawString("Scam links  $bul  Fake messages", $f3, $white, 346, 275)
$g.DrawString("Safe QR  $bul  Deep Scan  $bul  Pal AI", $f3, $white, 346, 313)
# pill
$fp = New-Object System.Drawing.Font('Segoe UI Black', 22, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$pp = New-RoundedPath 346 365 250 44 22
$g.FillPath((New-Object System.Drawing.SolidBrush((C 255 255 255 255))), $pp)
$sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
$g.DrawString('FREE  -  NO ADS', $fp, (New-Object System.Drawing.SolidBrush((C 255 40 40 90))), (New-Object System.Drawing.RectangleF(346, 365, 250, 44)), $sf)
# tilted phone at the right
$phone = [System.Drawing.Image]::FromFile((Join-Path $raw '03_link.png'))
$state = $g.Save()
$g.TranslateTransform(850, 300); $g.RotateTransform(8); $g.TranslateTransform(-850, -300)
$frame = New-RoundedPath 745 90 210 440 26
$g.FillPath((New-Object System.Drawing.SolidBrush((C 255 14 18 34))), $frame)
$clip = New-RoundedPath 752 98 196 420 20
$g.SetClip($clip)
$g.DrawImage($phone, (New-Object System.Drawing.Rectangle(752, 98, 196, 420)), (New-Object System.Drawing.Rectangle(0, 120, $phone.Width, [int](420 * $phone.Width / 196))), [System.Drawing.GraphicsUnit]::Pixel)
$g.ResetClip(); $g.Restore($state)
$bmp.Save((Join-Path $root 'feature_graphic_1024x500.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose(); $phone.Dispose(); $logo.Dispose()
Write-Host 'made feature graphic'
