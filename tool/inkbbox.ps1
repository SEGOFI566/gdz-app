param([string]$Path = "C:\dev\gdz_app\tool\img2022\p-009.jpg")
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile($Path)
$w = $img.Width; $h = $img.Height
$minX = $w; $maxX = 0; $minY = $h; $maxY = 0
$stepX = 2; $stepY = 2
for ($y = 0; $y -lt $h; $y += $stepY) {
  for ($x = 0; $x -lt $w; $x += $stepX) {
    $c = $img.GetPixel($x, $y)
    if (($c.R + $c.G + $c.B) -lt 420) {
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
$img.Dispose()
Write-Host ("size: " + $w + "x" + $h)
Write-Host ("ink bbox: x=" + $minX + ".." + $maxX + " y=" + $minY + ".." + $maxY)
