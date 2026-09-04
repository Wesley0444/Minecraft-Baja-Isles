# =============================================================================
#  build.ps1  --  compile bajatiers against the SERVER's own NeoForge runtime
#
#  No Gradle, no MDK: javac against the jars the dedicated server already runs
#  (patched Minecraft + NeoForge universal + FML + Apotheosis + Placebo), then
#  `jar` it with META-INF/neoforge.mods.toml. Same technique as the AC magnetism
#  patch. Output: mods-src\bajatiers\build\bajatiers-<version>.jar (+ sha1 file).
#
#  Run from anywhere:  powershell -File "C:\Game Servers\Minecraft\mods-src\bajatiers\build.ps1"
# =============================================================================
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$srv  = 'C:\Game Servers\Minecraft'
$jdk  = 'C:\Program Files\Microsoft\jdk-21.0.4.7-hotspot\bin'
$ver  = ((Get-Content "$here\resources\META-INF\neoforge.mods.toml") | Select-String '^version="(.+)"').Matches[0].Groups[1].Value

$nf   = "$srv\libraries\net\neoforged\neoforge\21.1.249"
$cp = @(
    "$nf\neoforge-21.1.249-server.jar",
    "$nf\neoforge-21.1.249-universal.jar",
    # patched classes above win; the "-srg" jar is the full Mojang-named vanilla server (legacy filename)
    "$srv\libraries\net\minecraft\server\1.21.1-20240808.144430\server-1.21.1-20240808.144430-srg.jar",
    "$srv\libraries\net\neoforged\mergetool\2.0.0\mergetool-2.0.0-api.jar",
    "$srv\libraries\net\neoforged\fancymodloader\loader\4.0.44\loader-4.0.44.jar",
    "$srv\libraries\net\neoforged\bus\8.0.5\bus-8.0.5.jar",
    "$srv\libraries\org\slf4j\slf4j-api\2.0.9\slf4j-api-2.0.9.jar",
    "$srv\libraries\com\mojang\logging\1.2.7\logging-1.2.7.jar",
    "$srv\libraries\com\mojang\datafixerupper\8.0.16\datafixerupper-8.0.16.jar",
    "$srv\libraries\com\mojang\brigadier\1.3.10\brigadier-1.3.10.jar",
    (Get-ChildItem "$srv\mods\Apotheosis-*.jar" | Select-Object -First 1).FullName,
    (Get-ChildItem "$srv\mods\Placebo-*.jar"    | Select-Object -First 1).FullName
) -join ';'

$out = "$here\build"
if (Test-Path "$out\classes") { Remove-Item "$out\classes" -Recurse -Force }
New-Item -ItemType Directory -Force "$out\classes" | Out-Null

& "$jdk\javac.exe" --release 21 -proc:none -cp $cp -d "$out\classes" (Get-ChildItem "$here\src" -Recurse -Filter *.java).FullName
if ($LASTEXITCODE -ne 0) { throw "javac failed ($LASTEXITCODE)" }

Copy-Item "$here\resources\*" "$out\classes" -Recurse -Force
$jar = "$out\bajatiers-$ver.jar"
if (Test-Path $jar) { Remove-Item $jar -Force }
& "$jdk\jar.exe" --create --file $jar -C "$out\classes" .
if ($LASTEXITCODE -ne 0) { throw "jar failed ($LASTEXITCODE)" }

$sha1 = (Get-FileHash $jar -Algorithm SHA1).Hash.ToLower()
[IO.File]::WriteAllText("$jar.sha1", $sha1, (New-Object Text.UTF8Encoding $false))
Write-Host "built $jar"
Write-Host "sha1  $sha1"
