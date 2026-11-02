local M = {}

local uv = vim.uv or vim.loop
local watcher = nil
local debounce = nil
local generation = 0
local active_set = nil

local state = require("flume.state")

local function refresh_palette(flume, current_set)
    local previous_palette = require("flume.palette")
    local previous_config = vim.deepcopy(flume.config)
    local previous_name = vim.g.colors_name
    local started_generation = generation
    local applying = false

    -- A publication can change RGB values without changing the schema name.
    -- Refresh only canonical palette data, not the plugin or editor-local options.
    package.loaded["flume.palette"] = nil
    local ok, refreshed = xpcall(function()
        local palette = require("flume.palette")
        local resolved = flume.get_active_schema()
        if not resolved or uv.fs_readlink(state.get_current()) ~= current_set then
            return false
        end
        if
            resolved == previous_config.schema and vim.deep_equal(palette.get(resolved), previous_palette.get(resolved))
        then
            return true
        end

        local colorscheme = resolved == previous_config.schema and previous_config.colorscheme or nil
        applying = true
        flume.apply(resolved, colorscheme)
        return true
    end, debug.traceback)

    -- Non-nested ColorScheme handlers can suppress the foreign theme's event,
    -- leaving generation unchanged. A nil or previous name can be partial load.
    if
        applying
        and generation == started_generation
        and vim.g.colors_name ~= nil
        and vim.g.colors_name ~= previous_name
        and not flume.is_active()
    then
        M.stop()
    end
    if ok and refreshed then
        return true
    end

    -- A newer setup or foreign theme owns the editor after a reentrant event.
    if generation == started_generation then
        package.loaded["flume.palette"] = previous_palette
        if applying then
            flume.config = previous_config
            local restored, restore_error = pcall(flume.apply)
            if not restored then
                refreshed = tostring(refreshed)
                    .. "\nPrevious palette could not be reapplied: "
                    .. tostring(restore_error)
            end
        end
    end
    if not ok then
        vim.notify("Flume sync refresh failed:\n" .. tostring(refreshed), vim.log.levels.ERROR)
    end
    return false
end

local function apply_active_schema()
    -- A callback can already be scheduled when setup() disables the watcher.
    if not watcher then
        return
    end
    local flume = require("flume")
    if not flume.is_active() then
        M.stop()
        return
    end
    local current_set = uv.fs_readlink(state.get_current())
    if not flume.config.watch_sync or not current_set or current_set == active_set then
        return
    end

    local started_generation = generation
    if refresh_palette(flume, current_set) and generation == started_generation then
        -- Failed refreshes remain retryable when the same set is published again.
        active_set = current_set
    end
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

    -- Reconcile changes made while the native event backend starts observing.
    -- The seeded active_set preserves follow_sync=false for an unchanged activation.
    vim.schedule(function()
        if generation == started_generation then
            apply_active_schema()
        end
    end)

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
