-- ScanInbox, Fingerprint, Count, Residual: the inbox as plain values (from
-- GlassMail's tests/test_scan.lua), plus `secret` and `headers`.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local LM = loadLib()
check(LM.Ready(), "loaded whole: ready")

local ARROW = { id = 2512, count = 20 }
local ORE = { id = 2770, count = 5 }
WoW.inbox = {
    { sender = "Cowruzo Kashmere", subject = "arrows", money = 100, items = { [1] = ARROW, [2] = ORE } },
    { sender = "Horde Auction House", subject = "Auction canceled: Scroll of Spirit (3)", canReply = false,
      items = { [1] = { id = 1180, count = 3 } } },
    { sender = "Horde Auction House", subject = "Outbid on Copper Ore", money = 500, canReply = false },
    { sender = "The Postmaster", subject = "Recovered Item", canReply = false, items = { [1] = ORE } },
    { sender = "Cowruzo Kashmere", subject = "returned", wasReturned = true, items = { [1] = ORE } },
    { sender = "Gamemaster", subject = "hello", isGM = true },
}
local snap = LM.ScanInbox()
eq(snap.loaded, 6, "the loaded count")
eq(#snap.mails, 6, "one entry per mail")
check(snap.headers, "every header read: headers")
local m1 = snap.mails[1]
eq(m1.index, 1, "each mail knows its index")
eq(m1.money, 100, "  its money")
eq(m1.daysLeft, 29.5, "  its days left")
eq(m1.itemCount, 2, "  the header's item count")
eq(#m1.items, 2, "  its attachments")
eq(m1.items[2].slot, 2, "  each with its slot number")
eq(m1.items[2].itemID, 2770, "  its item ID")
check(m1.resolved and m1.fp ~= nil, "a mail whose links all came back has a fingerprint")
eq(m1.secret, nil, "  and no secret flag")
eq(m1.type, "player", "a player's mail")
eq(snap.mails[2].type, "ah", "an AH subject, by template, is AH mail (the count suffix inside %s)")
eq(snap.mails[3].type, "ah", "  an outbid notice too (no trailing period)")
eq(snap.mails[4].type, "system", "not AH and can't be replied to: system mail")
eq(snap.mails[5].type, "player", "a returned mail can be replied to: player mail")
eq(snap.mails[6].type, "system", "a GM's mail is system mail")
eq(snap.mails[6].money, 0, "no money reads as 0")
eq(#snap.mails[6].items, 0, "  no items as an empty list")
eq(snap.mails[6].itemCount, nil, "  and no item count")

-- No attachment is read for a mail whose header says it has none.
WoW.inboxCalls = 0
WoW.inbox = { { sender = "A", subject = "letter" } }
LM.ScanInbox()
eq(WoW.inboxCalls, 0, "a mail without items: no attachment call")
WoW.inbox = { { sender = "A", subject = "one", items = { [1] = ORE } } }
LM.ScanInbox()
eq(WoW.inboxCalls, 17, "a mail with items: every slot read, and the occupied one's link (16 + 1)")

WoW.inbox = {
    { sender = "Cowruzo Kashmere", subject = "arrows", money = 100, items = { [1] = ARROW, [2] = ORE } },
    { sender = "Horde Auction House", subject = "Auction canceled: Scroll of Spirit (3)", canReply = false,
      items = { [1] = { id = 1180, count = 3 } } },
    { sender = "Horde Auction House", subject = "Outbid on Copper Ore", money = 500, canReply = false },
    { sender = "The Postmaster", subject = "Recovered Item", canReply = false, items = { [1] = ORE } },
    { sender = "Cowruzo Kashmere", subject = "returned", wasReturned = true, items = { [1] = ORE } },
    { sender = "Gamemaster", subject = "hello", isGM = true },
}

-- Slots keep their numbers after a take (session 5).
WoW.inbox[1].items[1] = nil
eq(LM.ScanInbox().mails[1].items[1].slot, 2, "slot 2 stays slot 2 when slot 1 empties")

-- An uncached attachment (name "") is still there: occupied by its item ID.
WoW.inbox[1].items[1] = { id = 9999, count = 1, name = "" }
eq(#LM.ScanInbox().mails[1].items, 2, "an uncached item still counts as an attachment")

-- A missing link: the mail is unresolved, and so is the scan; its header is good.
WoW.inbox[1].items[1].link = false
local s2 = LM.ScanInbox()
check(not s2.mails[1].resolved and s2.mails[1].fp == nil, "an attachment without a link leaves the mail unresolved")
check(not s2.resolved, "  and the scan with it")
check(s2.headers and s2.mails[1].money == 100, "  but the headers stand")
eq(s2.mails[1].secret, nil, "  not withheld")
local counted = 0
for _, n in pairs(LM.Count(s2)) do counted = counted + n end
eq(counted, 5, "an unresolved mail isn't counted (5 of 6)")
WoW.inbox[1].items[1] = ARROW

-- A secret header field: withheld, checked before any other use (a secret
-- can't even be compared on the client; the kit's secrets throw on the other
-- uses: concat, ordering, indexing).
for _, field in ipairs({ "subject", "sender", "money", "wasReturned", "canReply", "isGM", "daysLeft" }) do
    local keep = WoW.inbox[3][field]
    WoW.inbox[3][field] = WoW.Secret(field)
    local ok, s3 = pcall(LM.ScanInbox)
    check(ok and not s3.mails[3].resolved, "a secret " .. field .. " leaves the mail unresolved, no error")
    check(ok and s3.mails[3].secret == true, "  withheld: secret")
    check(ok and s3.mails[3].type == nil and s3.mails[3].sender == nil and s3.mails[3].money == nil,
        "  unclassified, its values not kept")
    check(ok and s3.headers == false, "  and the scan's headers aren't whole")
    WoW.inbox[3][field] = keep
end
-- A secret attachment field: no fingerprint, but the header is readable.
WoW.inbox[2].items[1].id = WoW.Secret("itemID")
local okItem, s6 = pcall(LM.ScanInbox)
check(okItem and not s6.mails[2].resolved, "a secret attachment ID leaves the mail unresolved, no error")
check(okItem and s6.mails[2].secret == nil and s6.mails[2].type == "ah", "  its header still read, not withheld")
check(okItem and s6.headers, "  and the headers stand")
WoW.inbox[2].items[1].id = 1180
WoW.inbox[2].items[1].count = WoW.Secret("count")
check(not LM.ScanInbox().mails[2].resolved, "a secret attachment count too")
WoW.inbox[2].items[1].count = 3
WoW.inbox[2].items[1].link = WoW.Secret("link")
check(not LM.ScanInbox().mails[2].resolved, "  and a secret link")
WoW.inbox[2].items[1].link = nil

-- Secret counts: unreadable, never "empty".
WoW.inboxCounts = function() return WoW.Secret(6), 6 end
local s7 = LM.ScanInbox()
check(s7.loaded == 0 and #s7.mails == 0 and s7.resolved == false and s7.headers == false,
    "a secret loaded count: an unreadable scan")
WoW.inboxCounts = function() return 6, WoW.Secret(6) end
check(LM.ScanInbox().headers == false, "  a secret total too")
WoW.inboxCounts = nil
-- A row that didn't come back.
WoW.inbox[4].missing = true
local s8 = LM.ScanInbox()
eq(#s8.mails, 5, "a missing header row is left out")
check(s8.headers == false, "  and the headers aren't whole")
WoW.inbox[4].missing = nil
WoW.inbox = {}
local empty = LM.ScanInbox()
check(empty.headers and empty.loaded == 0 and #empty.mails == 0, "an empty inbox is read whole: headers, no mails")
WoW.inbox = {
    { sender = "Cowruzo Kashmere", subject = "arrows", money = 100, items = { [1] = ARROW, [2] = ORE } },
    { sender = "Horde Auction House", subject = "Auction canceled: Scroll of Spirit (3)", canReply = false,
      items = { [1] = { id = 1180, count = 3 } } },
    { sender = "Horde Auction House", subject = "Outbid on Copper Ore", money = 500, canReply = false },
    { sender = "The Postmaster", subject = "Recovered Item", canReply = false, items = { [1] = ORE } },
    { sender = "Cowruzo Kashmere", subject = "returned", wasReturned = true, items = { [1] = ORE } },
    { sender = "Gamemaster", subject = "hello", isGM = true },
}

-- Fingerprints: what identifies a mail, and what doesn't.
local fp = LM.ScanInbox().mails[1].fp
WoW.inbox[1].daysLeft = 3.2
WoW.inbox[1].wasRead = true
eq(LM.ScanInbox().mails[1].fp, fp, "expiry and read state don't change a fingerprint")
WoW.inbox[1].items[2] = { id = 2770, count = 4 }
check(LM.ScanInbox().mails[1].fp ~= fp, "an attachment's count does")
WoW.inbox[1].items[2] = ORE
WoW.inbox[1].wasReturned = true
check(LM.ScanInbox().mails[1].fp ~= fp, "  and being returned")
WoW.inbox[1].wasReturned = nil

-- Length-prefixed fields: a delimiter inside a field can't merge two mails.
local a = LM.Fingerprint({ sender = "A", subject = "1:B", money = 0, cod = 0, items = {} })
local b = LM.Fingerprint({ sender = "A1:", subject = "B", money = 0, cod = 0, items = {} })
check(a ~= b, "fields can't run into each other")

-- Two identical mails share a fingerprint (session 2): counted, not merged.
WoW.inbox[7] = { sender = "Cowruzo Kashmere", subject = "returned", wasReturned = true, items = { [1] = ORE } }
local s4 = LM.ScanInbox()
eq(LM.Count(s4)[s4.mails[5].fp], 2, "twins are counted twice")
table.remove(WoW.inbox, 7)

-- Residuals: the fingerprint each action should leave behind.
local mail = LM.ScanInbox().mails[1]
local afterMoney = LM.Residual(mail, "money")
WoW.inbox[1].money = 0
eq(LM.ScanInbox().mails[1].fp, afterMoney, "after its money: the same mail with money 0")
local afterSlot1 = LM.Residual(LM.ScanInbox().mails[1], "item", 1)
WoW.inbox[1].items[1] = nil
eq(LM.ScanInbox().mails[1].fp, afterSlot1, "after slot 1: the same mail without slot 1, slot 2 unmoved")
local emptied, mayVanish = LM.Residual(LM.ScanInbox().mails[1], "item", 2)
check(mayVanish, "taking the last item of a mail without money: it may be removed")
WoW.inbox[1].items[2] = nil
eq(LM.ScanInbox().mails[1].fp, emptied, "  or stay, empty (a mail with letter text): that's its residual")
local moneyOnly = LM.ScanInbox().mails[3]
check(not select(2, LM.Residual(moneyOnly, "money")), "a money-only mail stays, at money 0 (session 3)")
local withMoney = { sender = "x", subject = "y", money = 5, cod = 0, items = { { slot = 1, link = "l", count = 1 } } }
check(not select(2, LM.Residual(withMoney, "item", 1)), "an item mail still holding money stays")

-- The template patterns: magic characters, positional specifiers, %%.
local T = LM._test
check(("Gewonnen (100%): Ore"):find(T.templatePattern("Gewonnen (100%%): %1$s")) ~= nil,
    "a positional %1$s and a literal %% match")
check(("Outbid on Ore."):find(T.templatePattern("Outbid on %s")) ~= nil, "  a %s takes the rest")
check(("xOutbid on Ore"):find(T.templatePattern("Outbid on %s")) == nil, "  anchored at the start")

-- A missing template global is skipped, not an error.
rawset(_G, "AUCTION_WON_MAIL_SUBJECT", nil)
T.resetPatterns()
eq(LM.ScanInbox().mails[2].type, "ah", "a missing template global is skipped")

done("test_scan")
