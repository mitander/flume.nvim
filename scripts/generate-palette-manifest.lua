vim.opt.runtimepath:prepend(vim.fn.getcwd())
local path = "docs/palette-manifest.md"
local content = require("flume.manifest").render()
local file = io.open(path, "rb")
local current = file and file:read("*a") or ""
if file then
    file:close()
end
if current ~= content then
    local output = assert(io.open(path, "wb"))
    assert(output:write(content))
    assert(output:close())
    print("Updated " .. path)
else
    print(path .. " is current")
end
vim.cmd("qa!")
