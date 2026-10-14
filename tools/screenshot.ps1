# Capture a running game window to a PNG (Windows).
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools/screenshot.ps1 -ProcessId <pid> -Out shot.png
# Find the pid with:  Get-Process Godot_v4.7.2-stable_mono_win64
param(
  [Parameter(Mandatory=$true)][int]$ProcessId,
  [Parameter(Mandatory=$true)][string]$Out
)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Threading;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public class WinCap {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  public static void Grab(IntPtr h, string path) {
    ShowWindow(h, 9);            // SW_RESTORE
    SetForegroundWindow(h);
    Thread.Sleep(600);
    RECT r; GetWindowRect(h, out r);
    int w = r.Right - r.Left; int ht = r.Bottom - r.Top;
    if (w <= 0 || ht <= 0) { w = 1280; ht = 720; }
    using (var bmp = new Bitmap(w, ht))
    using (var g = Graphics.FromImage(bmp)) {
      g.CopyFromScreen(r.Left, r.Top, 0, 0, new Size(w, ht));
      bmp.Save(path, ImageFormat.Png);
    }
  }
}
"@ -ReferencedAssemblies System.Drawing
$p = Get-Process -Id $ProcessId
$h = $p.MainWindowHandle
if ($h -eq [IntPtr]::Zero) { Write-Output "NO_WINDOW_HANDLE" }
else { [WinCap]::Grab($h, $Out); Write-Output ("SAVED " + $Out) }
