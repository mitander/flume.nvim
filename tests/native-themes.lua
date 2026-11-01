-- Run only inside a workspace prepared by scripts/native-themes.
local root = assert(vim.env.FLUME_NATIVE_ROOT)
local schema = assert(vim.env.FLUME_NATIVE_SCHEMA)
vim.opt.runtimepath:prepend(root .. "/plugin")

-- Only Pi's filesystem notification is exercised. Never signal Ghostty, source
-- a user's Tmux config or launch external reload commands from this trial.
local executable = vim.fn.executable
vim.fn.executable = function(name)
    if name == "osascript" or name == "pkill" or name == "tmux" then
        return 0
    end
    return executable(name)
end
vim.fn.system = function()
    error("External reload commands are disabled in native-theme trials")
end
vim.notify = function() end

local flume = require("flume")
flume.setup({ schema = schema, watch_sync = false, follow_sync = false, dev = false })
assert(require("flume.extras").get_plugin_dir() == root .. "/plugin", "trial loaded the wrong checkout")
assert(require("flume.state").get_dir() == root .. "/data", "trial selected the wrong shared state")
local installed = require("flume.extras").install("pi")
assert(installed.status == "linked" or installed.status == "already_linked", installed.message)
local result = require("flume.sync").run({ schema = schema, quiet = true })
assert(not result.ghostty_reloaded and not result.tmux_reloaded, "trial requested an external reload")
assert(result.pi_notified, "trial did not notify its private Pi theme link")
assert(require("flume.state").get_schema() == schema, "trial did not publish the requested palette")
vim.cmd("qa!")
