# Joining the server — one-time setup

You do this **once**. After that the pack updates itself every time you hit Play, so you
will never have to think about mod versions, or ask "did everyone update?", or get kicked
for a mismatch.

Takes about 10 minutes.

---

## 1. Install Prism Launcher

<https://prismlauncher.org/download/> — free, open source, no account.

Keep your normal Minecraft launcher; Prism sits alongside it and doesn't interfere.

On first run it asks you to sign in with your **Microsoft / Minecraft account**. That's
the account you already own the game with — Prism is just a different way to launch it.

## 2. Install Java 21

<https://adoptium.net/temurin/releases/?version=21> — pick **JDK 21**, Windows x64,
`.msi` installer.

> Not Java 23, not Java 8. The pack is built against 21 and other versions produce
> crashes that look like mod bugs but aren't.

## 3. Import the instance

Grab the instance `.zip` from the download button at the top of this page. (No
button there, or you're reading this as a plain file? Ask Wesley for the zip.)

**Prism → Add Instance → Import from zip → pick the file → OK.**

That's it. The instance already has the modloader, the Java settings, and the auto-update
hook configured.

## 4. Verify Java (10 seconds, saves an hour later)

Right-click the instance → **Edit** → **Settings** → **Java**.
<span class="info-tip" tabindex="0"><span class="tip-icon">ⓘ&nbsp;screenshots</span><span class="tip-pop"><a href="/guides/mc-setup/assets/prism-edit-menu.png" target="_blank"><img src="/guides/mc-setup/assets/prism-edit-menu.png" alt="Prism: right-click the instance, choose Edit"></a><a href="/guides/mc-setup/assets/prism-java-settings.png" target="_blank"><img src="/guides/mc-setup/assets/prism-java-settings.png" alt="Prism Settings → Java tab: the executable path must say jdk-21; 8192 MiB max memory"></a></span></span>

Make sure the Java path points at your **21** install. Prism usually auto-detects
correctly, but if you have several JDKs it sometimes picks the newest instead of the right
one. If there's a dropdown, choose the 21.

## 5. Hit Play

**The first launch downloads ~130 mods and will take several minutes.** A console window
appears and looks alarming. It is fine. Let it finish.

Every launch after this one syncs any changes in seconds.

---

## What happens on every launch after setup

Before the game starts, the pack checks the server manifest and:

- downloads mods that were added
- updates mods that changed
- **deletes mods that were removed**

That last one is why this works — everyone converges on exactly the same pack, and it's
impossible to drift.

> ⚠ **Don't hand-add mods to this instance.** Anything not in the manifest gets deleted on
> the next launch, and if it *doesn't* get deleted it desyncs you from the server and you
> get kicked. Want a mod added? Ask Wesley — client-only cosmetic stuff is usually an easy
> yes.
>
> Resource packs and shaders are fine, those aren't mods.

---

## If something breaks

**"Failed to download <some mod>"**
The mod author blocked third-party downloads. Not your fault and not fixable on your end
— tell Wesley which mod, he'll swap or remove it.

**Crash on startup, everyone else is fine**
Almost always Java. Redo step 4. If it still crashes, right-click the instance →
**Folder**, grab `logs/latest.log`, and send that file. The log is the useful part — a
screenshot of the crash screen usually isn't.

**"Outdated server" / "Outdated client" when connecting**
Close Minecraft completely and relaunch. You launched just before an update landed.

**It worked yesterday and now it doesn't**
Relaunch once. If that fails, send `logs/latest.log`.

---

## Useful to know

- Your worlds, screenshots and configs live in the instance folder (right-click →
  **Folder**). They survive updates.
- Allocate RAM: right-click instance → **Edit** → **Settings** → **Memory**.
  **6–8 GB is right** for this pack. More is not better — oversized heaps make Java's
  garbage collector pause longer, which you feel as stutter.
- Shaders and resource packs are yours to choose. They're client-side and won't desync you.
