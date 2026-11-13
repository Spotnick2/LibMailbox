-- wow_stubs.lua: the mailbox APIs LibMailbox reads, over WowTestKit's core.
-- dofile("tests/wow_stubs.lua") FIRST in every test; drive it via WoW.inbox.
--
-- The mechanics are WowTestKit's (tests/kit.lua loads the commit and the build
-- tests/kit.pin names): strict globals, secrets (WoW.Secret), check / eq /
-- done. This file adds the inbox the way GlassMail's probe sessions read it
-- (GlassMail docs/FOREVER-PROBE.md).

dofile("tests/kit.lua")

ATTACHMENTS_MAX_RECEIVE = 16
-- The six AH subjects as GlassMail's session 5 read them.
AUCTION_EXPIRED_MAIL_SUBJECT = "Auction expired: %s"
AUCTION_INVOICE_MAIL_SUBJECT = "Sale Pending: %s"
AUCTION_OUTBID_MAIL_SUBJECT = "Outbid on %s"
AUCTION_REMOVED_MAIL_SUBJECT = "Auction canceled: %s"
AUCTION_SOLD_MAIL_SUBJECT = "Auction successful: %s"
AUCTION_WON_MAIL_SUBJECT = "Auction won: %s"

-- WoW.inbox: one table per mail { sender, subject, money, cod, daysLeft,
-- wasRead, wasReturned, canReply, isGM, items = { [slot] = { id, count, name,
-- link, currency } } }. WoW.inboxTotal: the server's total when it differs.
-- WoW.inboxCounts: a function returning GetInboxNumItems' values instead.
WoW.inbox, WoW.inboxTotal, WoW.inboxCounts = {}, nil, nil
WoW.inboxCalls = 0   -- GetInboxItem / GetInboxItemLink calls, for the cost checks

function GetInboxNumItems()
    if WoW.inboxCounts then return WoW.inboxCounts() end
    return #WoW.inbox, WoW.inboxTotal or #WoW.inbox
end
-- m.missing: the header isn't there yet (nothing returned); m.daysLeft =
-- false: no days left given; m.itemCount: a header count other than the slots.
function GetInboxHeaderInfo(i)
    local m = WoW.inbox[i]
    if not m or m.missing then return end
    local n = 0
    for _ in pairs(m.items or {}) do n = n + 1 end
    if m.itemCount ~= nil then n = m.itemCount end
    local daysLeft = m.daysLeft
    if daysLeft == nil then daysLeft = 29.5 elseif daysLeft == false then daysLeft = nil end
    -- A secret flag comes back as is; a plain one as the client's boolean.
    local function flag(v, default)
        if issecretvalue(v) then return v end
        if v == nil then return default end
        return v == true
    end
    local count = n
    if not issecretvalue(n) and n == 0 and m.itemCount == nil then count = nil end
    return 134937, nil, m.sender, m.subject, m.money or 0, m.cod or 0, daysLeft, count,
        flag(m.wasRead, false), flag(m.wasReturned, false), false, flag(m.canReply, true), flag(m.isGM, false)
end
-- name, itemID, texture, count, quality, canUse, isCurrency; an uncached
-- item's name is "" (session 2).
function GetInboxItem(i, a)
    WoW.inboxCalls = WoW.inboxCalls + 1
    local it = WoW.inbox[i] and WoW.inbox[i].items and WoW.inbox[i].items[a]
    if it then return it.name or "", it.id, 134, it.count or 1, 1, true, it.currency end
end
function GetInboxItemLink(i, a)
    WoW.inboxCalls = WoW.inboxCalls + 1
    local it = WoW.inbox[i] and WoW.inbox[i].items and WoW.inbox[i].items[a]
    if it then
        if it.link == false then return nil end
        if it.link ~= nil then return it.link end
        return "|Hitem:" .. it.id .. "::::::::16:1485|h[item " .. it.id .. "]|h"
    end
end

-- LibStub: the library's own loader reads _G.LibStub before creating it.
Kit.strict({ LibStub = true })
