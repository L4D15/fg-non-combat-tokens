# Non-Combat Tokens

A Fantasy Grounds Unity extension (CoreRPG and derived rulesets) that separates placing an NPC on a map from adding it to combat.

- **Dropping an NPC on a map does not add it to the Combat Tracker.** Only its token is placed, sized and named from the NPC record.
- **Double-clicking the token opens the NPC record**, even if it is not in the Combat Tracker.
- **Right-click the token → "Add to Combat Tracker"** adds the NPC to the Combat Tracker, keeping the token's position. If the token is part of a selection, every selected token not yet in the Combat Tracker is added.
- **Dropping an effect on the token adds the NPC to the Combat Tracker** and applies the effect, since effects can only live on combatants (in rulesets that support dropping effects on tokens).

PCs, tokens dragged from the Combat Tracker and loose tokens behave as usual. All features are GM-only.

## Build

```sh
python3 build.py                 # package to dist/NonCombatTokens.ext and install into Fantasy Grounds
python3 build.py --no-install    # package only
tests/run.sh                     # Lua tests with stubbed FG APIs (requires luajit)
```

The extension is installed into `~/.smiteworks/fgdata/extensions/`; set `FGDATA=PATH` to use another Fantasy Grounds data folder. Then enable it when loading the campaign, or run `/reload` if it is already enabled.

## Releases

Download `NonCombatTokens.ext` from the [Releases](../../releases) page and copy it into the `extensions` folder of your Fantasy Grounds data directory.

Pushing a version tag (`X.Y.Z`) on `main` runs the tests, builds the extension and publishes a GitHub release with it attached. The tag must match `<version>` in `ext/extension.xml`.
