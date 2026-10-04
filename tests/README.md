# Tests

Run from the repository root with Lua 5.1 or LuaJIT:

```sh
lua tests/compatibility.lua
```

The regression test models WoW Forever's Classic project ID 18 with
`PanelTabButtonTemplate` available and `CharacterFrameTabButtonTemplate` absent.
The mocked `CreateFrame` rejects unavailable templates with the reported error.
The test creates Scrap's merchant tab and cover, clicks the tab, and clicks the
cover to restore the native merchant tab.

To reproduce the failure with an unpatched copy of the library:

```sh
lua tests/compatibility.lua /path/to/unpatched/SecureTabs-2.0.lua
```

The first test must fail with
`Couldn't find inherited node 'CharacterFrameTabButtonTemplate'` on the unpatched
implementation and pass with the fix. The remaining checks cover modern and
legacy templates, tab anchoring, and selection. These tests mock Blizzard's APIs;
they do not replace verification in-game.
