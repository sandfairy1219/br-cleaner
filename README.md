# br-cleaner

Removes the leftovers that Boss Rush practice mods leave in a Bloons TD 6 profile save.

## What is being cleaned

Practice mods apply the Boss Rush income rule by writing into the game's live challenge
model, which the game then persists in the profile:

```
ProfileModel.challengeEditorModel          (DailyChallengeModel)
  cashModifiers.towerCashMultiplier = 0.25   <-- stays after the mod is gone
  cashModifiers.popCashMultiplier / roundCashMultiplier
  roundSets = ["EnduranceRoundSet"]
  startRules.maxLives = 999999 / revives = 2 / endRound = round + 10000
  gameEventId
```

Because the values live in the profile and sync with the Ninja Kiwi cloud save, removing or
reinstalling the mod does not reset them. This tool edits the save file directly instead of
loading anything into the game.

## Usage

1. Close Bloons TD 6 completely.
2. Run `Clean-BossRush.bat`.

```
Clean-BossRush.bat            full cleanup (default)
Clean-BossRush.bat -Minimal   income multiplier only
```

Both write a timestamped backup next to the save and re-read the save afterwards.

## Save location

The save is not inside the game folder, so a copied/second install of the game still shares
it. It is one file per Windows user (or per Steam account):

```
Steam : <Steam>\userdata\<id>\960090\local\link\<guid>\Profile.Save
Epic  : %USERPROFILE%\AppData\LocalLow\Ninja Kiwi\BloonsTD6-Epic\...\profile.save
legacy: %USERPROFILE%\AppData\LocalLow\Ninja Kiwi\BloonsTD6\link\Profile.Save
```

The script searches all of these (including `Steam\userdata` and `SteamLibrary\userdata` on
D: through G:) and uses the most recently modified file. If it picks the wrong one:

```
Clean-BossRush.bat -Save "D:\...\960090\local\link\<guid>\Profile.Save"
```

## Accounts

The local file holds whichever Ninja Kiwi account was logged in last, so the cleanup applies
to that account. Switch accounts normally: the game downloads that account's profile on login.
If several accounts were polluted, log into each one, quit the game, run the cleaner, then
start the game again so the cleaned profile is uploaded.

## Running from a network share

Windows blocks scripts and executables launched from a UNC path. Copy the folder to local
disk first, then unblock:

```powershell
Copy-Item "\\server\share\bossrush-clean" "$env:USERPROFILE\Desktop\br-cleaner" -Recurse -Force
Get-ChildItem "$env:USERPROFILE\Desktop\br-cleaner" -Recurse | Unblock-File
```

## Output

```
found several profile saves, using the most recent:
  11/08/2026 14:40:24  ...\960090\local\link\bbb\Profile.Save
-- before --
  editor.cashModifiers  {"popCashMultiplier":1.0,"towerCashMultiplier":0.25,...}
  editor.startRules     {"lives":150,"maxLives":999999,"endRound":10001,"revives":2}
  editor.roundSets      ["EnduranceRoundSet"]
-- after --
  editor.cashModifiers  {"popCashMultiplier":1.0,"towerCashMultiplier":1.0,...}
  editor.startRules     {"lives":150,"maxLives":0,"endRound":100,"revives":0}
  editor.roundSets      ["default"]
[OK] saved. challengeEditorModel.towerCashMultiplier = 1.0
```

## Safety

- A timestamped backup is written next to the save before anything changes
  (`Profile.Save.cleanup-backup-YYYYMMDD_HHMMSS`).
- The save is re-read after packing and the new values are printed.
- If unpack or pack fails, the original save is restored from the backup.
- Only the `challengeEditorModel` object is touched; other cash modifier blocks are left alone.
- Editing save data violates Ninja Kiwi's terms of service. Use a throwaway account.

## Files

| File | Purpose |
| --- | --- |
| `Clean-BossRush.bat` | launcher |
| `Clean-BossRush.ps1` | locate, backup, patch, verify |
| `tools/monke.exe` | Ninja Kiwi save packer/unpacker ([codeshaunted/monke](https://github.com/codeshaunted/monke), MIT) |

## Requirements

Windows, PowerShell 5.1 or newer. No MelonLoader, no mod loader, no .NET SDK.
