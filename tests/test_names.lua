-- NameKey and NameDisplay: how a mail address is compared and shown (from
-- GlassMail's tests/test_names.lua).
dofile("tests/wow_stubs.lua")
dofile("tests/harness.lua")

local LM = loadLib()

eq(LM.NameKey("Kaleid Sumner"), "kaleid sumner", "lower-cased")
eq(LM.NameKey("  Kaleid   Sumner \t"), "kaleid sumner", "trimmed, inner spaces collapsed")
eq(LM.NameKey("KALEID SUMNER"), LM.NameKey("kaleid sumner"), "case doesn't matter")
eq(LM.NameKey("Kaleid Sumner-Doomhowl"), "kaleid sumner-doomhowl", "a realm suffix is kept")
check(LM.NameKey("Kaleid Sumner-Doomhowl") ~= LM.NameKey("Kaleid Sumner"), "  so it never merges with the plain name")
eq(LM.NameKey(WoW.Secret("name")), nil, "a secret name is never keyed")
eq(LM.NameKey(""), nil, "a blank name has no key")
eq(LM.NameKey("   "), nil, "  nor one of spaces")
eq(LM.NameKey(42), nil, "  nor a non-string")

eq(LM.NameDisplay("  Kaleid Sumner "), "Kaleid Sumner", "the display form is trimmed, case kept")
eq(LM.NameDisplay(WoW.Secret("name")), nil, "a secret name has no display form")

done("test_names")
