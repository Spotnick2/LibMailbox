-- harness.lua: the library loader. dofile it after wow_stubs.lua. check / eq /
-- done are WowTestKit's (tests/kit.lua). Run from the repo root.

function readFile(path)
    local f = assert(io.open(path, "rb"), "cannot open " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

-- The Lua files LibMailbox-1.0.xml loads, in order: the tests load exactly
-- what the client loads.
function xmlScripts()
    local xml = readFile("LibMailbox-1.0.xml"):gsub("<!%-%-.-%-%->", "")   -- listed in a comment is not loaded
    local files = {}
    for file in xml:gmatch('<Script%s+file="([^"]+)"') do files[#files + 1] = (file:gsub("\\", "/")) end
    assert(#files > 0, "LibMailbox-1.0.xml lists no Script files")
    return files
end

-- Load the library as the client does (every file the XML lists) and return
-- it from LibStub.
function loadLib()
    for _, file in ipairs(xmlScripts()) do dofile(file) end
    return LibStub("LibMailbox-1.0")
end

-- LibMailbox.lua's source with `edit` applied (a function of the text), run as
-- another embedded copy would be; returns what running it returned or raised.
function loadCopy(edit)
    local src = edit(readFile("LibMailbox.lua"))
    local chunk = assert(loadstring(src, "=copy"))
    return pcall(chunk)
end
