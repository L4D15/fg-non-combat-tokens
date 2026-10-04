# Non-Combat Tokens

Fantasy Grounds Unity extension for CoreRPG-based rulesets. See `README.md` for features and build commands. Everything (code, comments, strings, docs, commits) is in English.

## Workflow

- Git Flow: `main` holds releases (tagged `X.Y.Z`), `develop` is the integration branch, work happens in `feature/*` branches merged into `develop` with `--no-ff`; releases go through `release/X.Y.Z`. Keep `<version>` and the announcement in `ext/extension.xml` in sync with the release.
- Run `tests/run.sh` after changing `ext/scripts/`. The stubs imitate CoreRPG; they do not replace testing in FG (`/reload`, errors in `~/.smiteworks/fgdata/console.log`).

## How it works (`ext/scripts/noncombat_tokens.lua`)

- Host only. `onInit` replaces `ImageManager.onImageTokenDrop` (both the `"token"` drop callback and the function, since `onImageShortcutDrop` calls it by name) and wraps `TokenManager.handleDoubleClickOpen`.
- `onTabletopInit` registers `Token` events. Token menu items do not persist, so `onAdd` (also fired on image load) re-registers them.
- Token → record links live in the campaign node `noncombattokens`: `imagenode`, `tokenid` (string), `link` (windowreference).
- "Add to Combat Tracker" calls `CombatRecordManager.onRecordTypeEvent` without `tPlacement`, then `CombatManager.replaceCombatantToken` swaps in the CT token at the same position.
- CoreRPG source: `~/.smiteworks/fgdata/rulesets/CoreRPG.pak` (zip). Relevant: `scripts/manager_image.lua`, `scripts/manager_token.lua`, `scripts/manager_combat_record.lua`, `scripts/manager_combat.lua`.
