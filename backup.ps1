<#
=============================================================================
 backup.ps1  --  Minecraft 1.21.1 NeoForge : flush, snapshot, archive, offsite
-----------------------------------------------------------------------------
 WHAT IT DOES

   -Mode Snapshot   (every 30 min, SYSTEM)
       RCON save-off -> save-all flush -> save-on, then robocopy the world into
       a ROTATING SLOT. Slots are numbered 0..11, giving 6 hours of 30-minute
       granularity. Each slot is an independent full copy, but writing one only
       costs the delta since that slot was last used, so a 25GB world snapshots
       in seconds instead of minutes.

   -Mode Archive    (nightly 04:15, and from update.bat)
       Compress the NEWEST SLOT -- not the live world -- to a timestamped zip.
       Prune to the last 14. With -Offsite, copy the newest zip to Google Drive.

   -Mode Announce / Stop / Presence
       RCON helpers used by update.bat and the presence poller.

-----------------------------------------------------------------------------
 WHY IT IS BUILT THIS WAY

  * ZIP A QUIESCED COPY, NEVER THE LIVE WORLD.
      The Palworld backup script zipped the live save and ~9% of 4,565 runs
      failed -- Compress-Archive racing the server's own writes. Here the zip
      is made from a slot that nothing is writing to, so that race cannot
      happen. (Palworld's own mothball archive was clean for exactly this
      reason: it zipped only after the process exited.)

  * ROBOCOPY /E, NOT /MIR, NOT /PURGE.
      House rule: never mirror a live save. A mirror will happily delete your
      good copy to match a bad source. /E only adds and updates. The cost is
      that a slot can retain a region file that was later deleted upstream --
      an acceptable trade, since region files are essentially never deleted in
      a growing world (only by an explicit Chunky trim).

  * SLOTS LIVE ON H:.
      930GB free, and it keeps sustained backup writes off the drive holding
      the live world.

  * FLUSH BEFORE COPY, ALWAYS.
      save-off stops the world-save thread, save-all flush forces everything to
      disk and blocks until done, save-on resumes. Copying without this gives
      you a torn snapshot that looks fine until you try to restore it.
      save-on is in a finally block: if anything throws mid-backup, autosave
      MUST come back on or the server silently stops saving forever.

  * NO EXTERNAL RCON BINARY.
      The protocol is 3 int32s and a null-terminated string. Implementing it
      inline means one less downloaded exe on the SYSTEM account's PATH.

  * LOG STATUSES mirror the harmonium/Palworld convention:
      [OK]   flushed and copied
      [SKIP] maintenance.lock present -- planned downtime
      [DOWN] server unreachable and NOT planned -- snapshot taken UNFLUSHED
      [FAIL] the copy or zip itself threw

 USAGE
   powershell -NoProfile -ExecutionPolicy Bypass -File backup.ps1 -Mode Snapshot
=============================================================================
#>

[CmdletBinding()]
param(
  [ValidateSet('Snapshot','Archive','Announce','Stop','Presence')]
  [string]$Mode = 'Snapshot',
  [string]$Message = '',
  [switch]$Offsite
)

$ErrorActionPreference = 'Stop'

# --- configuration -----------------------------------------------------------
$SRV        = 'C:\Game Servers\Minecraft'
$WORLD      = Join-Path $SRV 'world'
$LOCK       = Join-Path $SRV 'maintenance.lock'
$BAK        = 'H:\Game Server Backups\Minecraft'
$SLOTS      = Join-Path $BAK 'slots'
$ARCHIVES   = Join-Path $BAK 'archives'
# Named OFFSITE_DIR, not OFFSITE: PS variable names are case-insensitive, and
# $OFFSITE would silently BE the [switch]$Offsite parameter -- assigning a string
# to it throws at parse-of-config time. Doc 02's draft had this bug (found live 2026-08-30).
$OFFSITE_DIR = 'F:\Google Drive\My Drive\Game Server Backups\Minecraft'
$LOG        = Join-Path $BAK 'backup.log'
$PRESENCE   = Join-Path $BAK 'presence.csv'
$SLOT_COUNT = 12          # 12 x 30min = 6h of rolling 30-minute granularity
$KEEP_ZIPS  = 14          # nightly archives kept locally
$RCON_HOST  = '127.0.0.1'
$RCON_PORT  = 25575
$LOCK_STALE_MIN = 10

New-Item -ItemType Directory -Force -Path $BAK,$SLOTS,$ARCHIVES | Out-Null

function Write-Log { param([string]$Status,[string]$Text)
  $line = '{0}  [{1}]  {2}' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'), $Status, $Text
  Write-Host $line
  Add-Content -Path $LOG -Value $line -Encoding utf8
}

function Get-RconPassword {
  $p = (Select-String -Path (Join-Path $SRV 'server.properties') -Pattern '^rcon\.password=(.*)$').Matches[0].Groups[1].Value
  if ([string]::IsNullOrWhiteSpace($p)) { throw 'rcon.password is empty in server.properties' }
  return $p
}

# --- minimal RCON client (Source RCON protocol, as used by vanilla MC) --------
function Invoke-Rcon {
  param([string[]]$Commands,[int]$TimeoutMs = 8000)
  $pw = Get-RconPassword
  $client = New-Object System.Net.Sockets.TcpClient
  try {
    $iar = $client.BeginConnect($RCON_HOST,$RCON_PORT,$null,$null)
    if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs)) { throw 'RCON connect timeout' }
    $client.EndConnect($iar)
    $s = $client.GetStream(); $s.ReadTimeout = $TimeoutMs; $s.WriteTimeout = $TimeoutMs

    function Send-Packet($id,$type,$body) {
      $b  = [Text.Encoding]::ASCII.GetBytes($body)
      $ms = New-Object IO.MemoryStream
      $bw = New-Object IO.BinaryWriter($ms)
      $bw.Write([int](4 + 4 + $b.Length + 2)); $bw.Write([int]$id); $bw.Write([int]$type)
      $bw.Write($b); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Flush()
      $out = $ms.ToArray(); $s.Write($out,0,$out.Length); $s.Flush()
    }
    function Read-Packet {
      $hdr = New-Object byte[] 4; $n = 0
      while ($n -lt 4) { $r = $s.Read($hdr,$n,4-$n); if ($r -le 0) { throw 'RCON closed' }; $n += $r }
      $len = [BitConverter]::ToInt32($hdr,0)
      $buf = New-Object byte[] $len; $n = 0
      while ($n -lt $len) { $r = $s.Read($buf,$n,$len-$n); if ($r -le 0) { throw 'RCON closed' }; $n += $r }
      [pscustomobject]@{
        Id   = [BitConverter]::ToInt32($buf,0)
        Type = [BitConverter]::ToInt32($buf,4)
        Body = [Text.Encoding]::ASCII.GetString($buf,8,$len-10)
      }
    }

    Send-Packet 1 3 $pw                       # 3 = SERVERDATA_AUTH
    $auth = Read-Packet
    if ($auth.Type -ne 2) { $auth = Read-Packet }   # tolerate a leading empty packet
    if ($auth.Id -eq -1)  { throw 'RCON auth failed (wrong password)' }

    $results = @(); $i = 2
    foreach ($c in $Commands) { Send-Packet $i 2 $c; $results += (Read-Packet).Body; $i++ }
    return $results
  } finally { $client.Close() }
}

function Test-ServerUp { try { Invoke-Rcon -Commands @('list') -TimeoutMs 4000 | Out-Null; $true } catch { $false } }

function Test-Maintenance {
  if (-not (Test-Path $LOCK)) { return $false }
  if (((Get-Date) - (Get-Item $LOCK).LastWriteTime).TotalMinutes -gt $LOCK_STALE_MIN) {
    Write-Log 'OK' 'stale maintenance.lock ignored (>10 min)'; return $false
  }
  return $true
}

function Format-Size { param([long]$b) '{0:N2} GB' -f ($b / 1GB) }

# =============================================================================
switch ($Mode) {

  'Announce' { Invoke-Rcon -Commands @("say $Message") | Out-Null; break }

  'Stop' {
    Invoke-Rcon -Commands @('save-all flush','stop') | Out-Null
    Write-Log 'OK' 'graceful stop issued via RCON'
    break
  }

  'Presence' {
    if (-not (Test-Path $PRESENCE)) { Add-Content $PRESENCE 'timestamp,count,names' -Encoding utf8 }
    try {
      $r = (Invoke-Rcon -Commands @('list'))[0]
      # "There are N of a max of M players online: a, b, c"
      $count = 0; $names = ''
      if ($r -match 'There are (\d+) of a max of \d+ players online:?\s*(.*)$') {
        $count = [int]$Matches[1]; $names = ($Matches[2] -replace ',\s*',';').Trim()
      }
      Add-Content $PRESENCE ('{0},{1},{2}' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss'),$count,$names) -Encoding utf8
    } catch {
      Add-Content $PRESENCE ('{0},-1,DOWN' -f (Get-Date -f 'yyyy-MM-dd HH:mm:ss')) -Encoding utf8
    }
    break
  }

  'Snapshot' {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $slot = Join-Path $SLOTS ('slot{0:d2}' -f ([int]((Get-Date).ToFileTimeUtc() / 18000000000) % $SLOT_COUNT))
    $status = 'OK'; $flushed = $false

    if (-not (Test-Path (Join-Path $WORLD 'level.dat'))) {
      Write-Log 'FAIL' 'world\level.dat missing -- refusing to snapshot'; break
    }

    if (Test-Maintenance) {
      $status = 'SKIP'
      Write-Log 'SKIP' 'maintenance lock present -- planned downtime, snapshot skipped'
      break
    }

    if (Test-ServerUp) {
      try {
        Invoke-Rcon -Commands @('save-off','save-all flush') | Out-Null
        Start-Sleep -Seconds 3
        $flushed = $true
      } catch { Write-Log 'FAIL' "flush failed: $($_.Exception.Message)"; $status = 'FAIL' }
    } else {
      $status = 'DOWN'    # unplanned outage: still snapshot, but flag it unflushed
    }

    try {
      New-Item -ItemType Directory -Force -Path $slot | Out-Null
      # /E   copy subdirs incl. empty     /XO  skip older      /MT:16 multithreaded
      # /XF session.lock -- the RUNNING server holds a byte-range lock on it (that is
      #   how vanilla implements the session lock); robocopy fails on it every time.
      #   It is a lock sentinel, not world data; the server recreates it on start.
      # NO /MIR AND NO /PURGE -- see header. We never delete from a snapshot slot.
      $rc = Start-Process robocopy -ArgumentList @(
              "`"$WORLD`"", "`"$slot`"", '/E','/XO','/R:1','/W:1','/MT:16',
              '/XF','session.lock',
              '/NFL','/NDL','/NP','/NJH','/NJS'
            ) -NoNewWindow -Wait -PassThru
      if ($rc.ExitCode -ge 8) { throw "robocopy exit $($rc.ExitCode)" }
      if ($status -ne 'DOWN' -and $status -ne 'FAIL') { $status = 'OK' }
    } catch {
      $status = 'FAIL'; Write-Log 'FAIL' "snapshot copy failed: $($_.Exception.Message)"
    } finally {
      # AUTOSAVE MUST COME BACK ON NO MATTER WHAT.
      if ($flushed) { try { Invoke-Rcon -Commands @('save-on') | Out-Null } catch { Write-Log 'FAIL' 'save-on FAILED -- AUTOSAVE IS OFF, INTERVENE NOW' } }
    }

    $sw.Stop()
    $size = (Get-ChildItem $slot -Recurse -File -ErrorAction SilentlyContinue |
             Measure-Object Length -Sum).Sum
    if ($status -in 'OK','DOWN') {
      Write-Log $status ('{0}  {1:mm\:ss}  slot={2}  flushed={3}' -f (Format-Size $size), $sw.Elapsed, (Split-Path $slot -Leaf), $flushed)
    }
    break
  }

  'Archive' {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $newest = Get-ChildItem $SLOTS -Directory -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $newest) { Write-Log 'FAIL' 'no snapshot slot to archive'; break }

    $zip = Join-Path $ARCHIVES ('Minecraft-{0}.zip' -f (Get-Date -f 'yyyy-MM-dd_HH-mm'))
    try {
      # Zipping a QUIESCED SLOT, not the live world. This is the fix for the
      # ~9% Compress-Archive failure rate the Palworld backup suffered.
      Compress-Archive -Path (Join-Path $newest.FullName '*') -DestinationPath $zip -CompressionLevel Optimal
    } catch {
      $sw.Stop(); Write-Log 'FAIL' "archive failed: $($_.Exception.Message)"; break
    }

    Get-ChildItem $ARCHIVES -Filter 'Minecraft-*.zip' | Sort-Object LastWriteTime -Descending |
      Select-Object -Skip $KEEP_ZIPS | Remove-Item -Force -ErrorAction SilentlyContinue

    if ($Offsite) {
      if (Test-Path (Split-Path $OFFSITE_DIR -Parent)) {
        New-Item -ItemType Directory -Force -Path $OFFSITE_DIR | Out-Null
        # Plain copy of ONE file. Never robocopy /MIR into the offsite folder.
        Copy-Item $zip -Destination $OFFSITE_DIR -Force
      } else {
        Write-Log 'FAIL' 'offsite path unavailable -- is Google Drive mounted for this user?'
      }
    }

    $sw.Stop()
    Write-Log 'OK' ('{0}  {1:hh\:mm\:ss}  archive={2}  offsite={3}' -f (Format-Size (Get-Item $zip).Length), $sw.Elapsed, (Split-Path $zip -Leaf), [bool]$Offsite)
    break
  }
}
