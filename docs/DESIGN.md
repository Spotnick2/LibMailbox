# LibMailbox-1.0: design

The mailbox as plain values, shared by GlassMail and AltStable. The plan and its review:
GlassMail `docs/PLAN.md`, "M3: LibMailbox-1.0". The measured facts below are GlassMail's
(`docs/FOREVER-PROBE.md`, sessions 2-6, and `C:\Projects\WoW\CLAUDE.md`'s porting guide).

## The contract

Within `LibMailbox-1.0` the API only grows. Every function is dot-called on the library table,
keeps no state between calls, makes no frame and registers no event.

| Function | Returns |
|---|---|
| `Ready()` | true when this copy loaded whole and is the one LibStub hands out |
| `ScanInbox()` | `{ loaded, total, mails, resolved, headers }`, read only while the mailbox is open |
| `Fingerprint(mail)` | an opaque string: sender, subject, money, COD, returned, each slot's number, link and count |
| `Count(scan)` | `{ [fp] = n }` over the resolved mails |
| `Residual(mail, "money" \| "item", slot)` | the fingerprint after that take, and whether it may empty the mail out of the inbox |
| `Summary(mails, now)` | `{ count, money, soonest }` or nil |
| `Expires(daysLeft, now)` | `floor((now + daysLeft * 86400) / 60) * 60` |
| `NameKey(name)`, `NameDisplay(name)` | the comparison key (trimmed, spaces collapsed, lower-cased, a `-Realm` kept) and the trimmed name; nil when secret, not a string or blank |

### A scan

Each mail: `{ index, sender, subject, money, cod, daysLeft, itemCount, wasRead, wasReturned,
canReply, isGM, type, items = { { slot, itemID, link, count, isCurrency } }, resolved, fp }`.
- `type`: `system` for a GM's mail, `ah` when the subject matches one of the six
  `AUCTION_*_MAIL_SUBJECT` templates (localized globals; never the faction-specific sender),
  `system` when it can't be replied to, else `player`.
- A slot is occupied when it has an item ID (an uncached item's name is `""`). Slots keep their
  numbers after a take (session 5).
- `resolved` false on a mail: a secret attachment field or an attachment without a link. No fingerprint;
  the header values stand.
- A **withheld** mail (a secret header field) is `{ index, secret = true, resolved = false, items = {} }`.
- `scan.resolved`: every loaded mail was read and has a fingerprint (a row that didn't come back
  makes it false: a count can't prove a mail unique without it). `scan.headers`: the counts were readable, every
  row up to `loaded` came back and none was withheld, so the header values describe the whole
  loaded inbox. Secret counts give `{ loaded = 0, total = 0, mails = {}, resolved = false,
  headers = false }`: unknown, never empty.
- The inbox loads at most 100 mails (`loaded` vs `total`). There is no stable mail ID: an index
  is good until the next `MAIL_INBOX_UPDATE`; a consumer finds a mail again by fingerprint before
  acting on it, and doesn't act when two match.
- Cost: a header per loaded mail, and for a mail whose header has items, `ATTACHMENTS_MAX_RECEIVE`
  (16) `GetInboxItem` calls and a `GetInboxItemLink` per occupied slot.

### The summary

Two shapes; a mail with an `expires` field is a saved one, any other a live one.

| Shape | Counts when | Its expiry |
|---|---|---|
| live (a `ScanInbox` mail) | (`itemCount > 0` or `money > 0`) and `daysLeft > 0`: AltStable's rule; `items` is never read | `Expires(daysLeft, now)`, never compared with `now` |
| saved (a consumer's snapshot) | (`#items > 0` or `money > 0`) and `expires > now` | `expires` |

`money` is summed and `soonest` is the smallest expiry; nil when nothing counts. A withheld mail
counts for nothing. Rounding the expiry to the minute keeps it stable across re-scans (a later
scan reports the same moment through a smaller `daysLeft`).

A consumer that must not clear what it stored on an unreadable inbox checks `scan.headers` (and
`Ready()`) before summarizing: an unreadable scan is not an empty one.

## Upgrades

Several addons embed copies; LibStub keeps one table, and a newer copy's functions replace the
older's on it. So:
- consumers hold the table and look each function up when they call it, never a captured one;
- private helpers are per-copy locals (nothing escapes into a callback; the AH patterns are
  cached per copy);
- `lib.ready = MINOR` is the last line, and `Ready()` compares it with LibStub's current minor:
  a newer copy that errored after claiming its minor makes it false, and consumers then read
  nothing.

`tests/test_upgrade.lua` proves it with synthetic copies: newer (a held reference and an adapter
made before reach the new functions; an older copy's scan goes through the new `Summary` and
`Residual`), older and equal (nothing changes), and half-loaded (`Ready()` false).
`tests/test_upgrade_r1.lua` does it against the real r1 (`tests/fixtures/LibMailbox-r1.lua`,
frozen): the current file over it keeps the table, reaches an adapter made under r1, takes r1's
scans and keeps their fingerprints (a consumer's remembered target still matches); under it,
nothing changes.

## Not here

The loot and send queues (GlassMail's `Core/Loot.lua`, `Core/Ops.lua`), snapshots and records
(`Core/Store.lua`, `Core/Memory.lua`): one consumer each. A header-only scan is an additive API
for later if AltStable's call count shows in game.
