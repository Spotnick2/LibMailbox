-- Several addons embed copies of LibMailbox-1.0 and LibStub keeps the newest.
-- EMBEDDED-LIBRARIES.md's first-release pattern: a synthetic newer copy (the
-- real r1 file is frozen as a fixture once tagged, for later upgrades).
-- Proven here: a newer copy's functions replace the older's on the same
-- table, which a held reference and a consumer's adapter both reach; an
-- older or equal copy changes nothing; a newer copy that fails half-way makes
-- Ready() false.
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local function header(minor)
    return function(src)
        local out, n = src:gsub('local MAJOR, MINOR = "LibMailbox%-1%.0", 1', 'local MAJOR, MINOR = "LibMailbox-1.0", ' .. minor)
        assert(n == 1, "the MINOR line moved")
        return out
    end
end
-- A copy whose ScanInbox and Summary mark their results with `tag`.
local function tagged(minor, tag)
    return function(src)
        local out = header(minor)(src)
        local n1, n2
        out, n1 = out:gsub("resolved = true, headers = true }", "resolved = true, headers = true, tag = " .. ("%q"):format(tag) .. " }")
        out, n2 = out:gsub("return { count = count, money = money, soonest = soonest }",
            "return { count = count, money = money, soonest = soonest, tag = " .. ("%q"):format(tag) .. " }")
        assert(n1 == 1 and n2 == 1, "the tagged lines moved")
        return out
    end
end

WoW.inbox = { { sender = "A", subject = "gold", money = 5, daysLeft = 2, items = { [1] = { id = 2770, count = 5 } } } }

local LM = loadLib()
local adapter = function() return LM.ScanInbox() end   -- a consumer's, made before any upgrade
local oldScan = LM.ScanInbox()
eq(LM.ready, 1, "r1 loaded: ready = 1")
check(LM.Ready(), "  Ready")

-- A newer copy.
local ok = loadCopy(tagged(2, "v2"))
check(ok, "a newer copy loads")
check(LibStub("LibMailbox-1.0") == LM, "the library table keeps its identity")
eq(LM.ready, 2, "  ready = 2")
check(LM.Ready(), "  Ready")
eq(LM.ScanInbox().tag, "v2", "a held reference reaches the newer ScanInbox")
eq(adapter().tag, "v2", "  and so does an adapter made before the upgrade")
local sum = LM.Summary(oldScan.mails, 100000)
eq(sum and sum.tag, "v2", "a scan the older copy returned goes through the newer Summary")
local fp, gone = LM.Residual(oldScan.mails[1], "item", 1)
check(type(fp) == "string" and gone == false, "  and the newer Residual")

-- An older copy, then an equal one: nothing changes.
check(loadCopy(tagged(1, "old")), "an older copy loads without error")
eq(LM.ScanInbox().tag, "v2", "  and changes nothing")
check(loadCopy(tagged(2, "equal")), "an equal copy loads without error")
eq(LM.ScanInbox().tag, "v2", "  and changes nothing")
eq(LM.ready, 2, "  ready stays 2")

-- A newer copy that errors after replacing some functions.
local okHalf = loadCopy(function(src)
    local out = tagged(3, "half")(src)
    local n
    out, n = out:gsub("\nlib%.ready = MINOR", '\nerror("half-loaded")\nlib.ready = MINOR')
    assert(n == 1, "the ready line moved")
    return out
end)
check(not okHalf, "a copy that errors half-way fails to load")
eq(select(2, LibStub:GetLibrary("LibMailbox-1.0")), 3, "  after LibStub handed it the minor")
eq(LM.ready, 2, "  ready still the old one")
check(not LM.Ready(), "  so Ready is false: consumers read nothing")

done("test_upgrade")
