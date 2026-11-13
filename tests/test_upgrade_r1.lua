-- The real r1, frozen (tests/fixtures/LibMailbox-r1.lua, `git show r1:LibMailbox.lua`,
-- stored byte for byte: .gitattributes marks the fixtures -text), against the
-- current file. test_upgrade.lua proves the mechanics with synthetic copies;
-- this proves them against what players already have embedded.
-- - r1 first, then the current file (an addon with the newer copy loading
--   later): one table, Ready, and what r1 handed out still works: an adapter
--   made under r1, a scan r1 returned through the current Summary and Residual,
--   and the same fingerprints (a consumer's remembered target must still
--   match after the upgrade). While the current MINOR is 1, LibStub skips the
--   equal copy and r1's functions stay; once it is newer, every API function
--   is the current file's.
-- - the current file first, then r1: nothing changes.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local FIXTURE = "tests/fixtures/LibMailbox-r1.lua"
local API = { "Ready", "ScanInbox", "Fingerprint", "Count", "Residual", "Summary", "Expires", "NameKey", "NameDisplay" }

-- The fixture is frozen: its length and Adler-32 as tagged. Never edit it; a
-- later release adds its own fixture beside it.
local src = readFile(FIXTURE)
local a, b = 1, 0
for i = 1, #src do
    a = (a + src:byte(i)) % 65521
    b = (b + a) % 65521
end
eq(#src, 11727, "the r1 fixture is the tagged file: its length")
eq(b * 65536 + a, 673135316, "  and its Adler-32")
check(src:find('local MAJOR, MINOR = "LibMailbox%-1%.0", 1\n', 1) ~= nil, "  it declares MINOR 1")

local current = tonumber(readFile("LibMailbox.lua"):match('local MAJOR, MINOR = "LibMailbox%-1%.0", (%d+)'))
check(current and current >= 1, "the current file's MINOR is read")

local function loadR1()
    local chunk = assert(loadstring(src, "=LibMailbox-r1"))
    return pcall(chunk)
end
local function forget()
    LibStub.libs["LibMailbox-1.0"], LibStub.minors["LibMailbox-1.0"] = nil, nil
end
local function functions(LM)
    local t = {}
    for _, name in ipairs(API) do t[name] = LM[name] end
    return t
end
local function same(t, LM)
    for _, name in ipairs(API) do
        if LM[name] ~= t[name] then return false end
    end
    return true
end
local function none(t, LM)
    for _, name in ipairs(API) do
        if LM[name] == t[name] then return false end
    end
    return true
end

WoW.inbox = {
    { sender = "A", subject = "gold", money = 5, daysLeft = 2, items = { [1] = { id = 2770, count = 5 } } },
    { sender = "B", subject = "ore", daysLeft = 20, items = { [2] = { id = 2771, count = 3 } } },
}

-- r1, then the current file. LibStub first, as the XML loads it.
for _, file in ipairs(xmlScripts()) do
    if file ~= "LibMailbox.lua" then dofile(file) end
end
check(loadR1(), "r1 loads")
local LM = LibStub("LibMailbox-1.0")
eq(LM.ready, 1, "  ready = 1")
check(LM.Ready(), "  Ready")
for _, name in ipairs(API) do check(type(LM[name]) == "function", "  r1 has " .. name) end
local r1 = functions(LM)
local adapter = function() return LM.ScanInbox() end   -- a consumer's, made under r1
local old = LM.ScanInbox()
check(old.resolved and #old.mails == 2, "  r1 reads the inbox whole")

check(loadLib() == LM, "the current file over r1: the table keeps its identity")
eq(LM.ready, current, "  ready = the current MINOR")
check(LM.Ready(), "  Ready")
if current > 1 then
    check(none(r1, LM), "  every API function is the current file's")
else
    check(same(r1, LM), "  an equal MINOR: LibStub skipped it, r1's functions stay")
end
local now = adapter()
check(now.resolved and #now.mails == 2, "an adapter made under r1 reads the inbox")
for i = 1, 2 do
    check(type(old.mails[i].fp) == "string" and old.mails[i].fp == now.mails[i].fp,
        "  mail " .. i .. ": r1's fingerprint still matches")
end
eq(LM.Count(now)[old.mails[1].fp], 1, "  and Count finds it")
local sum = LM.Summary(old.mails, 1793000000)
check(sum and sum.count == 2 and sum.money == 5, "a scan r1 returned goes through the current Summary")
local fp, gone = LM.Residual(old.mails[1], "item", 1)
check(type(fp) == "string" and gone == false, "  and the current Residual")

-- The current file, then r1: nothing changes.
forget()
local LM2 = loadLib()
check(LM2 ~= LM and LM2.Ready(), "the current file alone, in a fresh LibStub entry")
local mine = functions(LM2)
check(loadR1(), "r1 after it loads without error")
check(LibStub("LibMailbox-1.0") == LM2, "  the table is the same")
check(same(mine, LM2), "  every function is still the current file's")
eq(LM2.ready, current, "  ready stays the current MINOR")
check(LM2.Ready(), "  Ready")

done("test_upgrade_r1")
