# Runs the compiler team's adreno_mandelbrot demo, captures its console
# verification output AND a screenshot of the live window, then closes it.
#
# Screen-DC capture (CopyFromScreen) rather than PrintWindow: a DXGI
# flip-model swapchain often renders black through PrintWindow, but anything
# actually on the screen photographs fine. The RECT is fetched inside the C#
# helper - marshalling one through [ref] across the PowerShell boundary
# silently yields zeroes (lesson inherited from tools/shot.ps1).

param(
    [string]$Exe = "C:\projects\WINMOJO\bazel-bin\examples\win32\adreno_mandelbrot.exe",
    [string]$OutPng = "C:\projects\DRAGONMAX\dragon\assets\adreno_mandelbrot.png",
    [string]$OutTxt = "C:\projects\DRAGONMAX\dragon\assets\adreno_mandelbrot.txt",
    [int]$WarmupSeconds = 8
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Cap {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    static extern IntPtr FindWindowW(string cls, string title);
    [DllImport("user32.dll")]
    static extern bool SetForegroundWindow(IntPtr h);
    [StructLayout(LayoutKind.Sequential)]
    struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")]
    static extern bool GetWindowRect(IntPtr h, out RECT r);
    public static int[] Find(string title) {
        IntPtr h = FindWindowW(null, title);
        if (h == IntPtr.Zero) return null;
        SetForegroundWindow(h);
        System.Threading.Thread.Sleep(400);
        RECT r;
        GetWindowRect(h, out r);
        return new int[] { r.L, r.T, r.R - r.L, r.B - r.T };
    }
}
"@

$p = Start-Process -FilePath $Exe -RedirectStandardOutput $OutTxt -PassThru `
     -WorkingDirectory (Split-Path $Exe)
Write-Host "launched pid $($p.Id); warming up $WarmupSeconds s..."
Start-Sleep -Seconds $WarmupSeconds

$rect = [Cap]::Find("Mandelbrot - Mojo kernel on the Adreno X1-45 - Esc to close")
if (-not $rect) { Stop-Process -Id $p.Id -Force; throw "window not found" }
Write-Host "window at $($rect -join ',')"

$bmp = New-Object System.Drawing.Bitmap($rect[2], $rect[3])
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.CopyFromScreen($rect[0], $rect[1], 0, 0, $bmp.Size)
$gfx.Dispose()
$bmp.Save($OutPng, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Stop-Process -Id $p.Id -Force
Write-Host "captured: $OutPng"
Get-Content $OutTxt
