# br-cleaner

Cleans the leftovers that Boss Rush practice mods leave inside a Bloons TD 6 profile save.

No mod loader, no injection, nothing loaded into the game. It reads the save file while the
game is closed, fixes a handful of values, writes it back, and keeps a backup.

---

## 1. What problem does this fix?

Boss Rush practice mods (this project's `BossRushMod`, `CEBossRushEditor`, and others) apply
the real Boss Rush rules by writing into the game's live challenge model. The game then saves
that model into your profile, so the values stay behind after the mod is removed:

| Value | Leftover | After cleanup |
| --- | --- | --- |
| `cashModifiers.towerCashMultiplier` | `0.25` (tower income stuck at 25%) | `1.0` |
| `cashModifiers.popCashMultiplier` | modified | `1.0` |
| `cashModifiers.roundCashMultiplier` | modified | `1.0` |
| `roundSets` | `["EnduranceRoundSet"]` | `["default"]` |
| `startRules.maxLives` | `999999` | `0` |
| `startRules.endRound` | `round + 10000` | `100` |
| `startRules.revives` | `2` | `0` |

Reinstalling the game or removing the mod does not help, because the values live in the
profile (and in the Ninja Kiwi cloud save), not in the game folder.

---

## 2. Requirements

* Windows 10 or 11
* PowerShell 5.1 (already installed on Windows 10/11)
* Bloons TD 6 closed
* Nothing else: no .NET SDK, no MelonLoader, no Python

---

## 3. Download

### Option A - GitHub

1. Open this repository.
2. `Code` -> `Download ZIP`.
3. Extract it anywhere on your own disk (for example `Desktop\br-cleaner`).
4. If Windows blocks the scripts: right click the downloaded ZIP -> `Properties` ->
   tick `Unblock` -> `OK`, then extract.

### Option B - a shared folder / network drive

Windows blocks `.bat` and `.ps1` files that are started straight from a UNC path
(`\\server\share\...`). Copy the folder to local disk first, then unblock it:

```powershell
Copy-Item "\\server\share\br-cleaner" "$env:USERPROFILE\Desktop\br-cleaner" -Recurse -Force
Get-ChildItem "$env:USERPROFILE\Desktop\br-cleaner" -Recurse | Unblock-File
```

### Folder layout

```
br-cleaner\
  Clean-BossRush.bat      <- double click this
  Clean-BossRush.ps1      <- does the work
  tools\monke.exe         <- Ninja Kiwi save unpacker/packer
```

All three files must stay together. `monke.exe` is only used to decrypt and re-encrypt the
save file; it never touches the game process.

---

## 4. Quick start

1. **Quit Bloons TD 6 completely.** Check Task Manager: no `BloonsTD6.exe`.
2. Double click `Clean-BossRush.bat`.
3. Read the console output. You want the last lines:

```
[OK] written to ...\960090\local\link\<guid>\Profile.Save
[i] backup: ...\Profile.Save.cleanup-backup-20261108_144305
```

4. Start the game. On a new challenge, tower income should be normal again.

If SmartScreen or your antivirus complains about `monke.exe` (an unsigned third-party
binary), choose `More info` -> `Run anyway`, or allow it once in your antivirus.

---

## 5. Options

Run them through the `.bat`, for example `Clean-BossRush.bat -Check`.

| Option | What it does |
| --- | --- |
| *(none)* | Full cleanup: income multipliers, round set, lives cap, revives, end round |
| `-Check` | Prints the values currently stored in the save. **Changes nothing.** |
| `-Inspect` | Prints every round-related key plus the whole challenge editor model. Read only. |
| `-Minimal` | Only rewrites the income multipliers (`0.25` -> `1.0`) |
| `-Save "<path>"` | Use a specific `Profile.Save` instead of auto-detecting it |
| `-GameDir "<path>"` | Extra folder to search for the save |

> The tool only rewrites values that match the leftovers (`0.25`, `999999`,
> `endRound >= 1000`, `revives > 0`, `EnduranceRoundSet`). A deliberate `0.5` multiplier or a
> normal challenge is left untouched.

---

## 6. Recommended flow

```
1. Quit the game
2. Clean-BossRush.bat -Check     <- see what is stored right now
3. Clean-BossRush.bat           <- cleanup (writes + backup)
4. Start the game, play a bit, quit
5. Clean-BossRush.bat -Check     <- still 1.0? then the fix is permanent
```

If step 5 shows `0.25` again, the cloud save overwrote the local file. Start the game in
**Steam offline mode** once, run the cleaner while offline, then go back online - the cleaned
profile is uploaded and the cloud copy is replaced.

---

## 7. Safety rules - read these

1. **Close the game first.** The game rewrites the save on exit; cleaning while it runs loses
   the change or corrupts the file.
2. **A backup is always created** next to the save
   (`Profile.Save.cleanup-backup-YYYYMMDD_HHMMSS`). Do not delete it until you confirmed the
   game works normally.
3. **Make your own copy too** if you care about the profile: copy `Profile.Save` to another
   folder before running anything.
4. **Only one account is cleaned at a time.** The local file holds whichever Ninja Kiwi
   account was logged in last. Log in with the account you want to clean, quit the game, run
   the tool, start the game again (this uploads the cleaned profile). Repeat for other accounts.
5. **Never share your `Profile.Save`.** It contains your account id, progress and purchases.
   The console output is safe to share.
6. **Editing save data breaks the Ninja Kiwi terms of service.** Use an account you can lose,
   not your main one. There is no way to make this risk zero.
7. **Do not run two copies of the tool at once**, and do not run it on a save that another
   tool is writing.
8. **Failure is safe:** if unpacking or packing fails, the original file is restored from the
   backup automatically and nothing is changed.
9. **A healthy profile is never touched.** Before patching, the tool checks for the Boss Rush
   signature (`0.25` income, `EnduranceRoundSet`, `maxLives = 999999`). If none of it is
   present it prints `no Boss Rush leftovers in this profile - nothing to do` and exits
   without writing, so a normal profile is byte-for-byte identical afterwards.

---

## 8. Where the save actually is

The save is **not** inside the game folder, so a copied or second install of the game shares
the same profile. The tool searches all of these and uses the most recently modified file:

```
Steam : <Steam>\userdata\<id>\960090\local\link\<guid>\Profile.Save
also   : D:\Steam\userdata\..., D:\SteamLibrary\userdata\..., E: F: G: ...
Epic  : %USERPROFILE%\AppData\LocalLow\Ninja Kiwi\BloonsTD6-Epic\...\profile.save
legacy: %USERPROFILE%\AppData\LocalLow\Ninja Kiwi\BloonsTD6\link\Profile.Save
```

When several are found the list is printed and the newest one is used:

```
several profile saves found, using the most recent:
  11/08/2026 14:40  ...\userdata\222\960090\local\link\bbb\Profile.Save
  01/01/2026 00:00  ...\userdata\111\960090\local\link\aaa\Profile.Save
```

Wrong one? Pass it explicitly:

```
Clean-BossRush.bat -Save "D:\Steam\userdata\222\960090\local\link\bbb\Profile.Save"
```

---

## 9. Troubleshooting

| Message | Meaning | Fix |
| --- | --- | --- |
| `Bloons TD 6 is running` | game still open | close it completely, including the tray |
| `no Profile save file found` | no save under the searched roots | run with `-Save "<path to Profile.Save>"` |
| `unpack failed (save format not supported)` | save version newer than `monke` supports | nothing was changed; report your game version |
| `nothing to change (already clean)` | values are already normal | nothing to do |
| cleaned, but income is still 25% in game | another copy of the value exists | run `-Inspect` and report the output |
| "Custom Rounds" still shown on a challenge | that is the challenge definition stored by Ninja Kiwi, not the profile | delete that challenge and create a new one |

---

## 10. Restoring the backup

1. Close the game.
2. Rename `Profile.Save` to `Profile.Save.broken`.
3. Rename `Profile.Save.cleanup-backup-YYYYMMDD_HHMMSS` to `Profile.Save`.
4. Start the game.

---

## 11. Files and credits

| File | Purpose |
| --- | --- |
| `Clean-BossRush.bat` | launcher, passes arguments to the script |
| `Clean-BossRush.ps1` | locates the save, backs it up, patches, verifies |
| `tools/monke.exe` | Ninja Kiwi save packer/unpacker, MIT, from [codeshaunted/monke](https://github.com/codeshaunted/monke) |

The save is a zlib-compressed, AES-encrypted JSON container; `monke` handles the format so this
project does not have to ship its own crypto code.
