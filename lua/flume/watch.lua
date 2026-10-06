local M = {}

local uv = vim.uv or vim.loop
local watcher = nil
local debounce = nil
local generation = 0
local active_set = nil

local state = require("flume.state")

local function apply_active_schema()
    -- A callback can already be scheduled when setup() disables the watcher.
    if not watcher then
        return
    end
    if not require("flume").is_active() then
        M.stop()
        return
    end
    local current_set = uv.fs_readlink(state.get_current())
    if not current_set or current_set == active_set then
        return
    end
    local resolved = require("flume").get_active_schema()
    if not resolved then
        return
    end

    active_set = current_set
    local flume = require("flume")
    if not flume.config.watch_sync or flume.config.schema == resolved then
        return
    end

    flume.apply(resolved, nil)
end

function M.stop()
    generation = generation + 1
    active_set = nil
    pcall(vim.api.nvim_del_augroup_by_name, "FlumeSyncWatch")
    if debounce then
        debounce:stop()
        if not debounce:is_closing() then
            debounce:close()
        end
        debounce = nil
    end
    if watcher then
        watcher:stop()
        if not watcher:is_closing() then
            watcher:close()
        end
        watcher = nil
    end
end

function M.start()
    M.stop()

    local extras = state.get_dir()
    local created = pcall(vim.fn.mkdir, extras, "p")
    if not created or not uv.fs_stat(extras) then
        return false
    end

    watcher = uv.new_fs_event()
    debounce = uv.new_timer()
    if not watcher or not debounce then
        M.stop()
        return false
    end

    active_set = uv.fs_readlink(extras .. "/current")
    local started_generation = generation
    local started = watcher:start(extras, {}, function(error_message)
        if generation ~= started_generation or error_message or not debounce or debounce:is_closing() then
            return
        end
        debounce:stop()
        debounce:start(50, 0, function()
            vim.schedule(function()
                if generation == started_generation then
                    apply_active_schema()
                end
            end)
        end)
    end)
    if not started then
        M.stop()
        return false
    end

    local group = vim.api.nvim_create_augroup("FlumeSyncWatch", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = function()
            if not require("flume").is_active() then
                M.stop()
            end
        end,
    })
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        once = true,
        callback = M.stop,
    })
    return true
end

return M
