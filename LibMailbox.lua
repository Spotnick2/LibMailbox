-- LibMailbox-1.0: the WoW: Forever mailbox, read as plain values, as an
-- embedded LibStub library.
--
-- Lifted from GlassMail's Core/Scan.lua, Core/Summary.lua and Core/Names.lua
-- (GlassMail docs/PLAN.md, "M3: LibMailbox-1.0"); the summary rule is
-- AltStable's (Core.lua, ScanMail). The contract and the measured facts:
-- docs/DESIGN.md.
--
--   local LM = LibStub("LibMailbox-1.0")
--   if LM.Ready() then
--       local scan = LM.ScanInbox()                -- only while the mailbox is open
--       local sum = scan.headers and LM.Summary(scan.mails, time())
--   end
--
-- READ-ONLY. Nothing here changes the inbox, marks mail read (never
-- GetInboxText) or keeps state between calls: no frames, no events.
--
-- SECRETS FIRST. A value the client may withhold is tested with
-- issecretvalue before any other use (a secret can't even be compared), and
-- is never copied into a result.
--
-- UPGRADES. Several addons embed copies; LibStub keeps one table and the
-- newest copy's functions replace the older's on it. So a consumer holds the
-- table (`local LM = LibStub("LibMailbox-1.0")`) and looks each function up
-- when it calls, never a captured function. A newer copy that failed half-way
-- has already claimed its minor: LM.Ready() then says false, and a consumer
-- reads nothing. Within LibMailbox-1.0 the API only grows.
-- `lib.ready = MINOR` is the last line.

local MAJOR, MINOR = "LibMailbox-1.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end   -- an equal or newer copy is already loaded

-- True when this copy loaded whole and is the one LibStub hands out: a newer
-- copy that errored after claiming its minor leaves `ready` at the old one.
function lib.Ready()
    local _, minor = LibStub:GetLibrary(MAJOR, true)
    return lib.ready ~= nil and lib.ready == minor
end

local function isSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

local function anySecret(...)
    for i = 1, select("#", ...) do
        if isSecret((select(i, ...))) then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- Names
--------------------------------------------------------------------------------

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- The name as the player would type it (trimmed), or nil: secret, not a
-- string, or blank.
function lib.NameDisplay(name)
    if isSecret(name) or type(name) ~= "string" then return nil end
    local s = trim(name)
    if s == "" then return nil end
    return s
end

-- The comparison key: trimmed, inner spaces collapsed, lower-cased; nil as
-- for NameDisplay. A "-Realm" suffix is kept: such a name never merges with a
-- plain one (Forever names carry no realm; other realms are unmeasured).
function lib.NameKey(name)
    local s = lib.NameDisplay(name)
    if not s then return nil end
    return (s:gsub("%s+", " ")):lower()
end

--------------------------------------------------------------------------------
-- The inbox
--------------------------------------------------------------------------------

-- The six AH subjects, by global name: localized with the client. AH mail is
-- classified by these, never by its faction-specific sender.
local AH_SUBJECTS = {
    "AUCTION_EXPIRED_MAIL_SUBJECT", "AUCTION_INVOICE_MAIL_SUBJECT", "AUCTION_OUTBID_MAIL_SUBJECT",
    "AUCTION_REMOVED_MAIL_SUBJECT", "AUCTION_SOLD_MAIL_SUBJECT", "AUCTION_WON_MAIL_SUBJECT",
}

-- A format string as an anchored Lua pattern: %s, %d, %i and %1$s become
-- ".+", %% a literal %, every other magic character escaped.
local function templatePattern(fmt)
    local p = fmt:gsub("%%%%", "\2"):gsub("%%%d*%$?[sdi]", "\1")
    p = p:gsub("[%%%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
    p = p:gsub("\1", ".+"):gsub("\2", "%%%%")
    return "^" .. p .. "$"
end

local patterns   -- built once per copy, from the globals that exist
local function isAH(subject)
    if not patterns then
        patterns = {}
        for _, name in ipairs(AH_SUBJECTS) do
            local fmt = rawget(_G, name)
            if type(fmt) == "string" and fmt ~= "" then patterns[#patterns + 1] = templatePattern(fmt) end
        end
    end
    for _, p in ipairs(patterns) do
        if subject:find(p) then return true end
    end
    return false
end

-- Fields joined with a length prefix each, so a delimiter inside a subject or
-- a link can't make two different mails look the same.
local function encode(parts)
    local out = {}
    for i, v in ipairs(parts) do
        local s = tostring(v)
        out[i] = #s .. ":" .. s
    end
    return table.concat(out)
end

-- The fingerprint over what identifies a mail for this session: sender,
-- subject, money, COD, returned, and each occupied slot's number, link and
-- count. Not daysLeft (it drifts) nor wasRead (a take flips it). Opaque: a
-- session identifier, never saved.
function lib.Fingerprint(m)
    local parts = { m.sender, m.subject, m.money, m.cod, m.wasReturned and 1 or 0 }
    for _, it in ipairs(m.items) do
        parts[#parts + 1] = it.slot
        parts[#parts + 1] = it.link
        parts[#parts + 1] = it.count
    end
    return encode(parts)
end

local function attachments(i)
    local items, resolved = {}, true
    local max = rawget(_G, "ATTACHMENTS_MAX_RECEIVE") or 16
    for a = 1, max do
        local _, itemID, _, count, _, _, isCurrency = GetInboxItem(i, a)
        if anySecret(itemID, count, isCurrency) then return items, false end
        -- Occupied when it has an ID: an uncached item's name is "".
        if itemID ~= nil then
            local link = GetInboxItemLink(i, a)
            if isSecret(link) then return items, false end
            if link == nil then resolved = false end
            items[#items + 1] = { slot = a, itemID = itemID, link = link, count = count or 1,
                isCurrency = isCurrency == true }
        end
    end
    return items, resolved
end

-- One mail; nil when its header row isn't there. A withheld header (a secret
-- field) is { index, secret = true, resolved = false, items = {} }: no values.
-- `resolved` false (that, a secret attachment field, an attachment without a
-- link) means no fingerprint; the header values stay good.
local function readMail(i)
    local _, _, sender, subject, money, cod, daysLeft, itemCount, wasRead, wasReturned, _, canReply, isGM =
        GetInboxHeaderInfo(i)
    if anySecret(sender, subject, money, cod, daysLeft, itemCount, wasRead, wasReturned, canReply, isGM) then
        return { index = i, secret = true, resolved = false, items = {} }
    end
    if sender == nil and subject == nil and money == nil then return nil end
    local m = { index = i, daysLeft = daysLeft, wasRead = wasRead == true, wasReturned = wasReturned == true,
        canReply = canReply == true, isGM = isGM == true, itemCount = itemCount, items = {} }
    m.sender, m.subject, m.money, m.cod = sender or "", subject or "", money or 0, cod or 0
    local resolved
    if itemCount then m.items, resolved = attachments(i) else resolved = true end
    if m.isGM then m.type = "system"
    elseif isAH(m.subject) then m.type = "ah"
    elseif not m.canReply then m.type = "system"
    else m.type = "player" end
    m.resolved = resolved
    if resolved then m.fp = lib.Fingerprint(m) end
    return m
end

-- The loaded inbox: { loaded, total, mails, resolved, headers }.
-- `resolved`: every mail has a fingerprint. `headers`: the counts were
-- readable, every row up to `loaded` came back and none was withheld, so the
-- header values (money, daysLeft, itemCount) describe the whole loaded inbox.
-- Unreadable counts are { loaded = 0, total = 0, mails = {}, resolved = false,
-- headers = false }: unknown, never "empty".
function lib.ScanInbox()
    local loaded, total = GetInboxNumItems()
    if anySecret(loaded, total) then
        return { loaded = 0, total = 0, mails = {}, resolved = false, headers = false }
    end
    local scan = { loaded = loaded or 0, total = total or loaded or 0, mails = {}, resolved = true, headers = true }
    for i = 1, scan.loaded do
        local m = readMail(i)
        if m then
            scan.mails[#scan.mails + 1] = m
            if not m.resolved then scan.resolved = false end
            if m.secret then scan.headers = false end
        else
            scan.headers = false
        end
    end
    return scan
end

-- { [fp] = n } over the scan's resolved mails.
function lib.Count(scan)
    local n = {}
    for _, m in ipairs(scan.mails) do
        if m.fp then n[m.fp] = (n[m.fp] or 0) + 1 end
    end
    return n
end

-- The fingerprint the mail should have after taking its money ("money") or
-- slot k ("item", k): the same mail without it. The second return is true when
-- that empties a mail that had items: the server may then remove it, or keep
-- it, empty, when it has letter text. A money-only mail stays at money 0.
function lib.Residual(m, kind, slot)
    local after = { sender = m.sender, subject = m.subject, money = m.money, cod = m.cod,
        wasReturned = m.wasReturned, items = {} }
    for _, it in ipairs(m.items) do
        if not (kind == "item" and it.slot == slot) then after.items[#after.items + 1] = it end
    end
    if kind == "money" then after.money = 0 end
    return lib.Fingerprint(after), #m.items > 0 and #after.items == 0 and after.money == 0
end

--------------------------------------------------------------------------------
-- The summary: what a mailbox holds that is worth keeping
--------------------------------------------------------------------------------

-- An absolute expiry from daysLeft, rounded down to the minute: a later
-- re-scan reports the same moment through a smaller daysLeft, so it is stable.
function lib.Expires(daysLeft, now)
    return math.floor((now + daysLeft * 86400) / 60) * 60
end

-- { count, money, soonest } over the mails that hold something and have time
-- left, or nil when none does. Two shapes (docs/DESIGN.md):
-- - a saved mail (it has `expires`): items or money, and expires > now; its
--   expiry is `expires`;
-- - a live mail (a ScanInbox mail): the header decides, AltStable's rule:
--   itemCount or money, and daysLeft > 0 (absent: no); its expiry is
--   Expires(daysLeft, now), never compared with now.
-- A withheld mail counts for nothing.
function lib.Summary(mails, now)
    if type(mails) ~= "table" then return nil end
    local count, money, soonest = 0, 0, nil
    for _, m in ipairs(mails) do
        local expiry
        if type(m) ~= "table" or m.secret then
            expiry = nil
        elseif m.expires ~= nil then
            local holds = (m.items and #m.items > 0) or (m.money or 0) > 0
            if holds and m.expires > now then expiry = m.expires end
        else
            local holds = (m.itemCount and m.itemCount > 0) or (m.money and m.money > 0)
            if holds and m.daysLeft and m.daysLeft > 0 then expiry = lib.Expires(m.daysLeft, now) end
        end
        if expiry then
            count = count + 1
            money = money + (m.money or 0)
            if not soonest or expiry < soonest then soonest = expiry end
        end
    end
    if count == 0 then return nil end
    return { count = count, money = money, soonest = soonest }
end

-- Test seams, not part of the API: the pattern builder, and a reset of this
-- copy's cached patterns.
lib._test = { templatePattern = templatePattern, resetPatterns = function() patterns = nil end }

lib.ready = MINOR
