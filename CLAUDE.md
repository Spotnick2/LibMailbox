# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

LibMailbox-1.0 is the **World of Warcraft: Forever 1.60.1** (Interface `16001`) mailbox, read as
plain values: an **embedded LibStub library** in **Lua 5.1**. Single owner (Spotnick). It holds
what GlassMail's `Core/Scan.lua`, `Core/Summary.lua` and `Core/Names.lua` did (GlassMail
docs/PLAN.md, "M3: LibMailbox-1.0"; Codex gpt-6-astra, high, 2 rounds, consensus), and the
summary rule AltStable's `ScanMail` uses.

Players never install it: each addon embeds a copy under `Libs\LibMailbox-1.0\` through
`.pkgmeta` externals, and LibStub runs the newest copy loaded. It must stay **public**: the
packager clones externals anonymously. MIT. Consumers: **GlassMail** and **AltStable** (its
`mail_*` summary). `docs/DESIGN.md` is the contract. Work goes through issues and pull requests.

## Layout

- **No TOC.** Entry point `LibMailbox-1.0.xml`: `LibStub\LibStub.lua`, then `LibMailbox.lua`.
- **`LibMailbox.lua`**: the one runtime file. `MAJOR, MINOR = "LibMailbox-1.0", N`.
- **`Tools\deploy.ps1`**: copies this checkout into `AddOns\<Addon>\Libs\LibMailbox-1.0` (preflight:
  the XML, every file it loads, LICENSE). Consumers' deploys call it.
- **`docs\DESIGN.md`**: the contract and the measured facts. **Any behaviour change updates it in
  the same commit.**
- **`tests\`**: WowTestKit (`tests\kit.pin`; its README is the reference). Never edit the bootstrap
  copies (`kit.lua`, `kit.ps1`, `fetch_kit.sh`). `wow_stubs.lua` adds the inbox APIs,
  `harness.lua` loads the library from its XML (and synthetic copies for `test_upgrade`).

## The contract (read before changing anything)

Within `LibMailbox-1.0` **the API only grows**: never remove, rename or change the meaning of a
function, a returned field or a rule. A breaking change is `LibMailbox-2.0`.
- Functions on the library table, **dot-called**, no state between calls, no frames, no events:
  `Ready`, `ScanInbox`, `Fingerprint`, `Count`, `Residual`, `Summary`, `Expires`, `NameKey`,
  `NameDisplay`. `lib._test` is a test seam, not API.
- **Consumers hold the table and look functions up when they call** (`LM.ScanInbox()`), never a
  captured function: the newest copy's functions replace the older's on the same table.
- **`lib.ready = MINOR` is the last line**; `Ready()` compares it with LibStub's current minor, so a
  newer copy that failed half-way reads as not ready. Consumers check it at each entry.
- **Read-only.** Never `GetInboxText` (it marks mail read), never a take, return, delete or send.
- **Secrets first:** `issecretvalue` before any other use of a value the client may withhold; a
  secret is never copied into a result.
- Upgrades: `tests\test_upgrade.lua` loads synthetic newer, older, equal and half-loaded copies.
  `tests\test_upgrade_r1.lua` loads the real r1, frozen byte for byte as
  `tests\fixtures\LibMailbox-r1.lua` (`git show r1:LibMailbox.lua`; its length and Adler-32 are
  checked), under and over the current file. Never edit a fixture: a release that players will
  embed adds its own beside it.

## Toolchain and commands

```powershell
pwsh tests\run.ps1                                                  # luac -p on the XML's files, then every tests\test_*.lua, through WowTestKit at its pin
& 'C:\Program Files (x86)\Lua\5.1\lua.exe' tests\test_scan.lua     # one test, from the repo root (once run.ps1 has fetched the kit)
pwsh Tools\deploy.ps1 -Addon GlassMail                              # this checkout into an addon's Libs
```

**Mutation-test every new test**: break the behaviour, confirm it goes red.

## Releasing

A release is an annotated tag `rN` on `main` (`MINOR` = N), after the PR is merged and CI is
green. Consumers bump their `.pkgmeta` pin in a release they make anyway, and repeat this repo's
`.pkgmeta` ignore entries under `Libs/LibMailbox-1.0/` (the packager doesn't apply them).
Before tagging, test each consumer against this checkout (`$LIBMAILBOX`).

## Conventions

Shared with the sibling repos (`C:\Projects\WoW\CLAUDE.md`): the Forever API reference, the
References folder, WowTestKit, Codex for plans (`codex-consult`, gpt-6-astra, high, to
consensus), commit or push only when asked, never commit to `main` after the scaffold, the owner
merges PRs. Measured facts come from GlassMail's `docs\FOREVER-PROBE.md`; cite them, don't copy
them.
