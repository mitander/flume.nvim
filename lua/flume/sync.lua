local M = {}

local function reload_ghostty()
    if vim.fn.has("mac") ~= 1 or vim.fn.executable("osascript") ~= 1 then
        return false
    end
    local script = [[
tell application "Ghostty"
    if not running then return 0
    set reloadCount to 0
    repeat with ghosttyWindow in windows
        repeat with ghosttyTerminal in terminals of ghosttyWindow
            if perform action "reload_config" on ghosttyTerminal then
                set reloadCount to reloadCount + 1
            end if
        end repeat
    end repeat
    return reloadCount
end tell
]]
    local output = vim.fn.system({ "osascript", "-e", script })
    return vim.v.shell_error == 0 and tonumber(vim.trim(output)) ~= nil
end

local function reload_tmux()
    if vim.fn.executable("tmux") ~= 1 or vim.env.TMUX == nil then
        return false
    end
    vim.fn.system({ "tmux", "source-file", vim.fn.expand("~/.tmux.conf") })
    return vim.v.shell_error == 0
end

-- Pi watches its theme directory, not the nested extras/current symlink target.
-- Atomically replacing the equivalent top-level symlink emits the filename event
-- Pi needs to hot-reload the newly activated palette.
local function notify_pi()
    local uv = vim.uv or vim.loop
    local path = vim.fn.expand("~/.pi/agent/themes/flume.json")
    if vim.fn.getftype(path) ~= "link" then
        return false
    end

    local target = uv.fs_readlink(path)
    if not target then
        return false
    end

    local staged = path .. ".flume-sync-" .. tostring(uv.hrtime())
    local linked = uv.fs_symlink(target, staged, { dir = false, junction = false })
    if not linked then
        return false
    end
    local replaced = uv.fs_rename(staged, path)
    if not replaced then
        uv.fs_unlink(staged)
        return false
    end
    return true
end

function M.run(opts)
    opts = opts or {}
    local requested = opts.schema or require("flume").config.schema or "dusk"
    local schema = require("flume.palette").resolve(requested)
    local result = require("flume.compiler").activate(schema)
    local count = 0
    for _, changed in pairs(result) do
        if changed then
            count = count + 1
        end
    end
    result.schema = schema
    result.count = count
    result.any = count > 0
    if opts.notify == false then
        result.ghostty_reloaded = false
        result.tmux_reloaded = false
        result.pi_notified = false
    else
        result.ghostty_reloaded = reload_ghostty()
        result.tmux_reloaded = reload_tmux()
        result.pi_notified = notify_pi()
    end

    if not opts.quiet then
        local message = "Flume schema " .. schema .. " synchronized"
        if result.any then
            message = message .. string.format(" (%d files updated)", result.count)
        end
        vim.notify(message, vim.log.levels.INFO)
    end

    return result
end

return M
