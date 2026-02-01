
Add-Type -AssemblyName System.Drawing

$sourcePath = "c:\Users\souna\DEMANDY\ecommerce_app\assets\app_icon.png"
$webIconsDir = "c:\Users\souna\DEMANDY\ecommerce_app\web\icons"
$targets = @(
    @{ Size = 192; File = "Icon-maskable-192.png" },
    @{ Size = 512; File = "Icon-maskable-512.png" }
)

$sourceImg = [System.Drawing.Image]::FromFile($sourcePath)

foreach ($target in $targets) {
    $size = $target.Size
    $outFile = Join-Path $webIconsDir $target.File
    
    # Create new square bitmap with white background
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    
    # Calculate padded size (70% of canvas)
    $contentScale = 0.70
    $newWidth = [int]($size * $contentScale)
    $newHeight = [int]($size * $contentScale)
    
    # Center position
    $x = [int](($size - $newWidth) / 2)
    $y = [int](($size - $newHeight) / 2)
    
    # Draw source image centered
    $g.DrawImage($sourceImg, $x, $y, $newWidth, $newHeight)
    
    # Save
    $bmp.Save($outFile, [System.Drawing.Imaging.ImageFormat]::Png)
    
    Write-Host "Generated $outFile"
    $g.Dispose()
    $bmp.Dispose()
}

$sourceImg.Dispose()
