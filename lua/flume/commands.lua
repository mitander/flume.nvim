local M = {}

local function clear_flume_modules()
    local watch = package.loaded["flume.watch"]
    if type(watch) == "table" then
        pcall(watch.stop)
    end
    local dev = package.loaded["flume.dev"]
    if type(dev) == "table" then
        pcall(dev.stop)
    end
    -- A broken edited stop() must not prevent cache rollback.
    pcall(vim.api.nvim_del_augroup_by_name, "FlumeDevReload")
    for name in pairs(package.loaded) do
        if name == "flume" or name:match("^flume%.") then
            package.loaded[name] = nil
        end
    end
end

function M.reload(flume, opts)
    opts = opts or {}
    local config = vim.deepcopy(flume.config)
    local colors_name = config.colorscheme or require("flume.palette").get(config.schema).colorscheme
    local colorscheme_emitted = false
    local probe = vim.api.nvim_create_augroup("FlumeReloadProbe", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = probe,
        pattern = colors_name,
        once = true,
        callback = function()
            colorscheme_emitted = true
        end,
    })

    local previous = {}
    for name, module in pairs(package.loaded) do
        if name == "flume" or name:match("^flume%.") then
            previous[name] = module
        end
    end
    -- Reload the editor's choice, not the startup fallback or global choice.
    local follow_sync = config.follow_sync
    config.follow_sync = false
    local ok, err = xpcall(function()
        clear_flume_modules()
        local reloaded = require("flume")
        reloaded.setup(config)
        reloaded.config.follow_sync = follow_sync
    end, debug.traceback)
    local restored, restore_error
    local foreign_theme = false
    if not ok then
        -- Recover source caches, but do not repaint over a theme selected by a callback.
        foreign_theme = vim.g.colors_name ~= nil and vim.g.colors_name ~= colors_name
        clear_flume_modules()
        for name, module in pairs(previous) do
            package.loaded[name] = module
        end
        if not foreign_theme then
            restored, restore_error = xpcall(function()
                flume.setup(config)
            end, debug.traceback)
        else
            -- Fresh setup registered callbacks that still close over its discarded module.
            M.register(flume)
        end
        flume.config.follow_sync = follow_sync
    end
    pcall(vim.api.nvim_del_augroup_by_id, probe)
    if not ok then
        local message
        if foreign_theme then
            message = "Flume reload failed; active colorscheme preserved:\n"
        else
            message = restored and "Flume reload failed; previous theme restored:\n" or "Flume reload failed:\n"
        end
        message = message .. tostring(err)
        if not foreign_theme and not restored then
            message = message .. "\nPrevious theme could not be reapplied:\n" .. tostring(restore_error)
        end
        vim.notify(message, vim.log.levels.ERROR)
        return false
    end

    -- Older Neovim versions may emit ColorScheme while resetting syntax.
    if not colorscheme_emitted then
        vim.api.nvim_exec_autocmds("ColorScheme", { pattern = colors_name, modeline = false })
    end
    if not opts.quiet then
        vim.notify("Flume theme reloaded", vim.log.levels.INFO)
    end
    return true
end

function M.sync(flume, schema)
    if flume.config.dev then
        -- Use fresh editor and exporter code, but never publish after a failed reload.
        if not flume.reload({ quiet = true }) then
            return false
        end
        flume = require("flume")
    end

    local colorscheme = schema == nil and flume.config.colorscheme or nil
    schema = schema or flume.config.schema
    require("flume.palette").get(schema)
    if flume.config.dev then
        require("flume.compiler").compile_all({ activate = false })
    end
    local result = require("flume.sync").run({ schema = schema })
    flume.apply(schema, colorscheme)
    return result
end

function M.register(flume)
    vim.api.nvim_create_user_command("FlumeReload", flume.reload, {})
    vim.api.nvim_create_user_command("FlumeCompile", function()
        -- Compile fresh source without replacing the palette cache that describes
        -- the displayed theme and serves as the watcher's equality baseline.
        local palette = package.loaded["flume.palette"]
        local compiler = package.loaded["flume.compiler"]
        package.loaded["flume.palette"] = nil
        package.loaded["flume.compiler"] = nil
        local ok, err = xpcall(function()
            require("flume.compiler").compile_all({ activate = false })
        end, debug.traceback)
        package.loaded["flume.palette"] = palette
        package.loaded["flume.compiler"] = compiler
        if not ok then
            error(err)
        end
    end, {})
    vim.api.nvim_create_user_command("FlumeSync", function(opts)
        flume.sync(opts.args ~= "" and opts.args or nil)
    end, {
        nargs = "?",
        complete = function()
            return require("flume.palette").schema_order
        end,
    })
    vim.api.nvim_create_user_command("FlumeInstallExtras", function(opts)
        local arg = opts.args
        if arg == "" then
            require("flume.extras").install_all()
        else
            require("flume.extras").install(arg)
        end
    end, {
        nargs = "?",
        complete = function()
            return vim.tbl_keys(require("flume.extras").get_apps())
        end,
    })
    vim.api.nvim_create_user_command("FlumeExtras", function()
        require("flume.extras").show_instructions()
    end, {})
end

return M
