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
  startRules.lives / maxLives / revives / endRound
  gameEventId
```

Because the value lives in the profile (and syncs with the Ninja Kiwi cloud save), removing
or reinstalling the mod does not reset it. This tool edits the save file directly instead of
loading anything into the game.

## Usage

1. Close Bloons TD 6 completely.
2. Run `Clean-BossRush.bat`.

```
Clean-BossRush.bat           towerCashMultiplier -> 1.0
Clean-BossRush.bat -Full     also resets pop/round multipliers and roundSets to ["default"]
```

Optional arguments (pass through the .bat or use the .ps1 directly):

```
-GameDir <path>   default: %USERPROFILE%\AppData\LocalLow\Ninja Kiwi\BloonsTD6
-Monke <path>     default: monke.exe next to the script, then tools\monke.exe
```

## Output

```
-- before --
  editor.cashModifiers  {"popCashMultiplier":1.0,"towerCashMultiplier":0.25,...}
  editor.startRules      {...}
  editor.roundSets       ["EnduranceRoundSet"]
-- after --
  editor.cashModifiers  {"popCashMultiplier":1.0,"towerCashMultiplier":1.0,...}
[OK] saved. challengeEditorModel.towerCashMultiplier = 1.0
```

## Safety

- A timestamped backup is written next to the save before anything changes
  (`Profile.Save.cleanup-backup-YYYYMMDD_HHMMSS`).
- The save is re-read after packing and the new value is printed.
- If unpack or pack fails, the original save is restored from the backup.
- Only the `challengeEditorModel` object is touched; other cash modifier blocks are left alone.
- Editing save data violates Ninja Kiwi's terms of service. Use a throwaway account.

## Files

| File | Purpose |
| --- | --- |
| `Clean-BossRush.bat` | launcher |
| `Clean-BossRush.ps1` | backup, patch, verify |
| `tools/monke.exe` | Ninja Kiwi save packer/unpacker ([codeshaunted/monke](https://github.com/codeshaunted/monke), MIT) |

## Requirements

Windows, PowerShell 5.1 or newer. No MelonLoader, no mod loader, no .NET SDK.
