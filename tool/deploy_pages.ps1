# Builds the Flutter web app + the landing page in site/ and publishes both to GitHub Pages (branch gh-pages):
#   https://usmanfarazz.github.io/shieldpal/        landing page with the live demo in a phone frame
#   https://usmanfarazz.github.io/shieldpal/app/    the real Flutter web app
#   https://usmanfarazz.github.io/shieldpal/privacy.html
# Run from the project root:  powershell -ExecutionPolicy Bypass -File tool\deploy_pages.ps1
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

# ---- 1. images for the landing page ----
$img = Join-Path $root 'site\img'
New-Item -ItemType Directory -Force $img | Out-Null
function Save-Resized($src, $dst, [int]$w, [int]$h, [bool]$jpg) {
  $im = [System.Drawing.Image]::FromFile($src)
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'AntiAlias'
  $g.DrawImage($im, 0, 0, $w, $h)
  if ($jpg) {
    $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $p = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $p.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 86L)
    $bmp.Save($dst, $enc, $p)
  } else { $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png) }
  $g.Dispose(); $bmp.Dispose(); $im.Dispose()
}
Save-Resized (Join-Path $root 'docs\logo.png') (Join-Path $img 'logo.png') 256 256 $false
Save-Resized (Join-Path $root 'store\feature_graphic_1024x500.png') (Join-Path $img 'og.jpg') 1200 586 $true
$names = '01_home','02_shield','03_link','04_message','05_deepscan','06_protection','07_pal_ai','08_pets'
for ($i = 0; $i -lt 8; $i++) {
  Save-Resized (Join-Path $root "store\screenshots\$($names[$i]).png") (Join-Path $img "shot$($i+1).jpg") 540 960 $true
}

# ---- 2. Flutter web build (the app lives under /shieldpal/app/) ----
& flutter build web --release --base-href /shieldpal/app/
if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

# ---- 3. assemble the site ----
$out = Join-Path $env:TEMP 'shieldpal_pages'
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory $out | Out-Null
Copy-Item -Recurse (Join-Path $root 'site\*') $out
Copy-Item -Recurse (Join-Path $root 'build\web') (Join-Path $out 'app')
Copy-Item (Join-Path $root 'store\privacy_policy.html') (Join-Path $out 'privacy.html')
New-Item -ItemType File (Join-Path $out '.nojekyll') | Out-Null

# ---- 4. publish to gh-pages ----
Set-Location $out
git init -q -b gh-pages
git add -A
git -c user.name='Usman Faraz' -c user.email='usmanfaraz1818@gmail.com' commit -q -m 'Deploy ShieldPal site + live demo'
git remote add origin https://github.com/usmanfarazz/shieldpal.git
git push -q -f origin gh-pages
Set-Location $root
Write-Host 'Deployed: https://usmanfarazz.github.io/shieldpal/'
