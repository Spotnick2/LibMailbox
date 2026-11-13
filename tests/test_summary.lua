-- Summary and Expires: the rule both consumers share, over a saved snapshot's
-- mails (GlassMail) and a live scan's (AltStable's ScanMail, exactly).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local LM = loadLib()
local NOW = 1793000000

-- Saved mails (they carry `expires`): GlassMail's tests/test_summary.lua.
local function saved(over)
    local m = { expires = NOW + 86400, type = "player", money = 0, items = {} }
    for k, v in pairs(over or {}) do m[k] = v end
    return m
end
eq(LM.Summary({}, NOW), nil, "no mails: no summary")
eq(LM.Summary({ saved() }, NOW), nil, "a letter with nothing in it doesn't count")
eq(LM.Summary({ saved({ money = 500, expires = NOW - 1 }) }, NOW), nil, "an expired mail doesn't count")
eq(LM.Summary({ saved({ money = 500, expires = NOW }) }, NOW), nil, "  nor one expiring this second")
local s = LM.Summary({
    saved({ money = 500, expires = NOW + 3 * 86400 }),
    saved({ items = { { id = 2589, count = 5 } }, expires = NOW + 2 * 86400 }),
    saved({ subject = "hello" }),
    saved({ money = 100, items = { { id = 1, count = 1 } }, expires = NOW + 9 * 86400 }),
}, NOW)
eq(s.count, 3, "money only, items only, both: three count")
eq(s.money, 600, "  their money summed")
eq(s.soonest, NOW + 2 * 86400, "  the soonest expiry")
eq(LM.Summary(nil, NOW), nil, "no list: nil")
check(LM.Summary({ saved({ money = 5, items = {}, itemCount = 0 }) }, NOW) ~= nil,
    "a saved mail ignores a stray itemCount: its items and money decide")

-- Live mails, through ScanInbox: AltStable's ScanMail (Core.lua:2927) exactly.
local T0 = 100000
local function live(list)
    WoW.inbox = list
    return LM.Summary(LM.ScanInbox().mails, T0)
end
-- AltStable's own case (tests/test_comm.lua:1519): two worth counting, a plain letter.
local r = live({
    { sender = "A", subject = "gold", money = 5000, daysLeft = 3 },
    { sender = "B", subject = "ore", items = { [1] = { id = 2770, count = 5 } }, daysLeft = 7 },
    { sender = "C", subject = "hello", daysLeft = 1 },
})
eq(r.count, 2, "live: only mails with items or money count (a plain letter ignored)")
eq(r.soonest, math.floor((T0 + 3 * 86400) / 60) * 60, "  the soonest expiry, absolute, rounded to the minute")
eq(r.money, 5000, "  the money summed")
-- The boundaries.
local one = live({ { sender = "A", subject = "s", money = 1, daysLeft = 1 / 86400 } })
check(one ~= nil and one.count == 1, "one second left counts")
eq(one and one.soonest, 99960, "  its expiry rounded down, before now: never compared with now")
eq(live({ { sender = "A", subject = "s", money = 1, daysLeft = 0 } }), nil, "zero days left doesn't count")
eq(live({ { sender = "A", subject = "s", money = 1, daysLeft = -1 } }), nil, "  nor negative")
eq(live({ { sender = "A", subject = "s", money = 1, daysLeft = false } }), nil, "  nor absent")
check(LM.Summary({ { itemCount = 1, items = {}, money = 0, daysLeft = 2 } }, T0) ~= nil,
    "itemCount 1 with no attachments read: counts (the header decides)")
eq(LM.Summary({ { itemCount = 0, items = { { slot = 1 } }, money = 0, daysLeft = 2 } }, T0), nil,
    "itemCount 0 with an attachment listed: doesn't")
check(LM.Summary({ { money = 10, daysLeft = 2 } }, T0) ~= nil, "money with a nil itemCount counts")
eq(live({ { sender = "C", subject = "hello" }, { sender = "D", subject = "hi", money = 0 } }), nil,
    "only non-counting mail: nil (the caller clears its fields)")
eq(live({}), nil, "an empty inbox: nil")
-- A withheld mail counts for nothing.
eq(LM.Summary({ { index = 1, secret = true, resolved = false, items = {} } }, T0), nil, "a withheld mail: nil")
eq(LM.Summary({ { secret = true, money = 5, daysLeft = 2 } }, T0), nil, "  whatever else it carries")

-- Expires.
eq(LM.Expires(1, 0), 86400, "Expires: a day")
eq(LM.Expires(29.5, 30), 29.5 * 86400, "  rounded down to the minute")
eq(LM.Expires(0, 119), 60, "  119 s is 60")

done("test_summary")
