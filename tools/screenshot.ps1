# Capture a running game window to a PNG (Windows).
# Usage:
#   powershell -ExecutionPolicy Bypass -File tools/screenshot.ps1 -ProcessId <pid> -Out shot.png
#   powershell -ExecutionPolicy Bypass -File tools/screenshot.ps1 -Title "Marble (DEBUG)" -Out shot.png
# Find the pid with:  Get-Process Godot_v4.7.2-stable_mono_win64
param(
  [int]$ProcessId = 0,
  [string]$Title = '',
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
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  public static void Grab(IntPtr h, string path) {
    ShowWindow(h, 9);            // SW_RESTORE
    // Force topmost so the capture isn't blocked by other windows.
    SetWindowPos(h, new IntPtr(-1), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0040);
    SetForegroundWindow(h);
    Thread.Sleep(700);
    RECT r; GetWindowRect(h, out r);
    int w = r.Right - r.Left; int ht = r.Bottom - r.Top;
    if (w <= 0 || ht <= 0) { w = 1280; ht = 720; }
    using (var bmp = new Bitmap(w, ht))
    using (var g = Graphics.FromImage(bmp)) {
      g.CopyFromScreen(r.Left, r.Top, 0, 0, new Size(w, ht));
      bmp.Save(path, ImageFormat.Png);
    }
    // Drop topmost afterwards.
    SetWindowPos(h, new IntPtr(-2), 0, 0, 0, 0, 0x0001 | 0x0002);
  }
}
"@ -ReferencedAssemblies System.Drawing
if ($Title -ne '') {
  $h = [WinCap]::FindWindow($null, $Title)
} else {
  $h = (Get-Process -Id $ProcessId).MainWindowHandle
}
if ($h -eq [IntPtr]::Zero) { Write-Output "NO_WINDOW_HANDLE" }
else { [WinCap]::Grab($h, $Out); Write-Output ("SAVED " + $Out) }
