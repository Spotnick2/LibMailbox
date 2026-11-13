# LibMailbox-1.0

The mailbox, read as plain values, for **World of Warcraft: Forever** addons: an embedded LibStub
library shared by [Glass Mail](https://github.com/Spotnick2/GlassMail) and
[AltStable](https://github.com/Spotnick2/AltStable).

- `ScanInbox()`: every loaded mail with its sender, subject, money, COD, days left, type (player,
  auction house, system) and attachments, plus a fingerprint to find the same mail again after
  the inbox changes. Read-only: it never marks mail read.
- `Summary(mails, now)`: how many mails hold items or gold, how much gold, and when the first one
  expires.
- `NameKey(name)` / `NameDisplay(name)`: how a mail address is compared and shown.

Values the client withholds (secret values) are never read into a result, and an inbox that
couldn't be read is never reported as empty. [docs/DESIGN.md](docs/DESIGN.md) is the contract.

## Embedding

```yaml
# .pkgmeta
externals:
  Libs/LibMailbox-1.0:
    url: https://github.com/Spotnick2/LibMailbox
    tag: r1
```

Load `Libs\LibMailbox-1.0\LibMailbox-1.0.xml` from your TOC before your own files, and repeat
this repo's `.pkgmeta` ignore entries under `Libs/LibMailbox-1.0/` in yours (the packager doesn't
apply a library's own ignore list).

```lua
local LM = LibStub("LibMailbox-1.0")
-- At MAIL_INBOX_UPDATE, while the mailbox is open:
if LM.Ready() then
    local scan = LM.ScanInbox()
    if scan.headers then
        local sum = LM.Summary(scan.mails, time())   -- nil: nothing worth keeping
    end
end
```

Call through the library table (`LM.ScanInbox()`), never a function you stored: when several
addons embed copies, the newest one's functions replace the others'.

## Development

`pwsh tests/run.ps1` (Lua 5.1, through [WowTestKit](https://github.com/Spotnick2/WowTestKit) at
`tests/kit.pin`). `pwsh Tools/deploy.ps1 -Addon <Addon>` copies this checkout into an addon's
`Libs` for in-game testing.

MIT licensed.
