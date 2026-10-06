local M = {}

function M.register(test, equal, truthy)
    test("startup sync preference reads runtime state without replacing fixed schemas", function()
        local extras = require("flume.extras")
        local original_dir = extras.get_plugin_dir
        local original_data = vim.env.FLUME_DATA_DIR
        local root = vim.fn.tempname()
        vim.env.FLUME_DATA_DIR = root .. "/extras"
        vim.fn.mkdir(root .. "/extras/current", "p")
        extras.get_plugin_dir = function()
            return root
        end
        local ok, err = xpcall(function()
            local flume = require("flume")
            flume.setup({ schema = "mesa", follow_sync = true, watch_sync = false })
            equal(flume.config.schema, "mesa", "missing state fallback")
            equal(flume.get_active_schema(), nil, "missing marker")
            vim.fn.writefile({ "mira" }, root .. "/extras/current/schema")
            flume.setup({ schema = "mesa", follow_sync = true, watch_sync = false })
            equal(flume.config.schema, "mira", "remembered runtime choice")
            equal(vim.g.colors_name, "flume-mira")
            equal(vim.fn.readfile(root .. "/extras/current/schema")[1], "mira", "startup wrote runtime state")
            flume.setup({ schema = "mesa", watch_sync = false })
            equal(flume.config.schema, "mesa", "explicit fixed schema")
            for _, invalid in ipairs({ "unknown", "", "mira trailing-data" }) do
                vim.fn.writefile({ invalid }, root .. "/extras/current/schema")
                equal(flume.get_active_schema(), nil, "invalid marker")
                flume.setup({ schema = "mesa", follow_sync = true, watch_sync = false })
                equal(flume.config.schema, "mesa", "invalid state fallback")
            end
        end, debug.traceback)
        extras.get_plugin_dir = original_dir
        vim.env.FLUME_DATA_DIR = original_data
        vim.fn.delete(root, "rf")
        require("flume").setup({ watch_sync = false })
        if not ok then
            error(err)
        end
    end)

    test("real sync command publishes before reload adapters and editor notification", function()
        local flume = require("flume")
        local state = require("flume.state")
        local original_legacy = state.get_legacy_current
        local original_data = vim.env.FLUME_DATA_DIR
        local original_home = vim.env.HOME
        local original_tmux = vim.env.TMUX
        local original_system = vim.fn.system
        local original_executable = vim.fn.executable
        local original_has = vim.fn.has
        local original_notify = vim.notify
        local root = vim.fn.tempname()
        state.get_legacy_current = function() return root .. "/legacy" end
        vim.env.FLUME_DATA_DIR = root .. "/data"
        vim.env.HOME = root
        vim.env.TMUX = "test-session"
        flume.setup({ schema = "dusk", watch_sync = false, overrides = { accent = "#abcdef" } })
        local requested, previous
        local calls, events, notices = {}, 0, 0
        local group = vim.api.nvim_create_augroup("FlumeRealSyncTest", { clear = true })
        vim.api.nvim_create_autocmd("ColorScheme", {
            group = group,
            callback = function()
                events = events + 1
                equal(state.get_schema(), requested, "notification preceded publication")
                equal(flume.config.schema, requested, "notification preceded editor application")
                equal(flume.colors.accent, "#abcdef", "transition lost overrides")
                truthy(flume.is_active(), "notification has wrong editor identity")
                equal(table.concat(calls, ","), "osascript,tmux", "notification preceded reload adapters")
            end,
        })
        vim.fn.executable = function(name)
            return (name == "osascript" or name == "tmux") and 1 or 0
        end
        vim.fn.has = function(name)
            return name == "mac" and 1 or original_has(name)
        end
        vim.fn.system = function(command)
            equal(state.get_schema(), requested, "reload adapter preceded publication")
            equal(flume.config.schema, previous, "reload adapter ran after editor application")
            calls[#calls + 1] = command[1]
            -- A failed Ghostty reload must not prevent the next adapter or editor application.
            return command[1] == "osascript" and "not a reload count" or ""
        end
        vim.notify = function(message, level)
            if level == vim.log.levels.INFO then
                notices = notices + 1
                truthy(message:find("synchronized", 1, true), "unexpected success notice")
            end
        end
        local ok, err = xpcall(function()
            for _, schema in ipairs({ "opal", "mira", "mesa", "dusk" }) do
                requested, previous = schema, flume.config.schema
                calls = {}
                vim.cmd("FlumeSync " .. schema)
                equal(flume.config.schema, schema, "real command did not apply palette")
                local export = vim.json.decode(table.concat(vim.fn.readfile(state.get_current() .. "/palette.json"), "\n"))
                equal(export.schema, schema, "export did not switch")
                equal(export.colors.accent, require("flume.palette")[schema].accent, "editor override leaked into export")
            end
            equal(events, 4, "command notification count")
            equal(notices, 4, "synchronization success count")
            requested, previous = "opal", flume.config.schema
            calls = {}
            local result = require("flume.sync").run({ schema = requested, quiet = true })
            equal(result.ghostty_reloaded, false, "failed reload reported success")
            equal(result.pi_notified, false, "missing Pi link reported success")
            equal(flume.config.schema, previous, "sync implementation applied editor itself")
            equal(events, 4, "sync implementation emitted editor notification")

            -- Publication failure must leave both choices intact and skip reload adapters.
            requested, previous = "mesa", flume.config.schema
            calls = {}
            local uv = vim.uv or vim.loop
            local rename = uv.fs_rename
            uv.fs_rename = function(source, destination, ...)
                if destination == state.get_current() then return nil, "injected publication failure" end
                return rename(source, destination, ...)
            end
            local synchronized = pcall(vim.cmd, "FlumeSync " .. requested)
            uv.fs_rename = rename
            equal(synchronized, false, "failed publication reported success")
            equal(state.get_schema(), "opal", "failed publication changed shared choice")
            equal(flume.config.schema, previous, "failed publication changed editor choice")
            equal(#calls, 0, "failed publication invoked reload adapters")
            equal(events, 4, "failed publication notified editor")
            equal(notices, 4, "failed publication reported synchronization")
        end, debug.traceback)
        vim.api.nvim_del_augroup_by_id(group)
        vim.fn.system = original_system
        vim.fn.executable = original_executable
        vim.fn.has = original_has
        vim.notify = original_notify
        state.get_legacy_current = original_legacy
        vim.env.FLUME_DATA_DIR = original_data
        vim.env.HOME = original_home
        vim.env.TMUX = original_tmux
        vim.fn.delete(root, "rf")
        flume.setup({ watch_sync = false })
        if not ok then error(err) end
    end)

    test("development reload clears source caches and preserves the editor choice", function()
        local extras = require("flume.extras")
        local original_dir = extras.get_plugin_dir
        local original_data = vim.env.FLUME_DATA_DIR
        local root = vim.fn.tempname()
        vim.env.FLUME_DATA_DIR = root .. "/extras"
        vim.fn.mkdir(root .. "/extras/current", "p")
        vim.fn.writefile({ "opal" }, root .. "/extras/current/schema")
        extras.get_plugin_dir = function()
            return root
        end
        local ok, err = xpcall(function()
            require("flume").setup({ schema = "mesa", follow_sync = true, dev = true, watch_sync = false })
            require("flume").load("mira")
            local old_palette = require("flume.palette")
            old_palette.mira.text = "#abcdef"
            local old_flume = require("flume")
            vim.api.nvim_exec_autocmds(
                "BufWritePost",
                { pattern = root .. "/lua/flume/languages/rust.lua", modeline = false }
            )
            local flume = require("flume")
            truthy(flume ~= old_flume, "source module was not reloaded")
            truthy(require("flume.palette") ~= old_palette, "palette cache survived")
            equal(flume.config.schema, "mira", "reload adopted global startup choice")
            equal(flume.config.follow_sync, true, "reload dropped startup preference")
            equal(flume.config.dev, true, "reload dropped developer preference")
            truthy(flume.colors.text ~= "#abcdef", "stale source color survived")
            equal(#vim.api.nvim_get_autocmds({ group = "FlumeDevReload" }), 1, "duplicate reload hooks")
            vim.api.nvim_exec_autocmds("BufWritePost", { pattern = root .. "/other.lua", modeline = false })
            equal(require("flume"), flume, "unrelated source triggered reload")
            vim.cmd.colorscheme("habamax")
            local live_root = require("flume.extras").get_plugin_dir()
            vim.api.nvim_exec_autocmds(
                "BufWritePost",
                { pattern = live_root .. "/lua/flume/palette.lua", modeline = false }
            )
            equal(vim.g.colors_name, "habamax", "development hook replaced another colorscheme")
            flume.setup({ schema = "mira", watch_sync = false })
            equal(pcall(vim.api.nvim_get_autocmds, { group = "FlumeDevReload" }), false, "disabled hook survived")
        end, debug.traceback)
        -- Reload created a fresh extras module; the captured module may be stale.
        extras.get_plugin_dir = original_dir
        vim.env.FLUME_DATA_DIR = original_data
        package.loaded["flume.extras"] = nil
        vim.fn.delete(root, "rf")
        require("flume").setup({ watch_sync = false })
        if not ok then
            error(err)
        end
    end)

    test("failed development reload restores caches and recovers on the next save", function()
        local original_notify = vim.notify
        local errors = 0
        vim.notify = function(_, level)
            if level == vim.log.levels.ERROR then
                errors = errors + 1
            end
        end
        local ok, err = xpcall(function()
            for _, module in ipairs({ "flume", "flume.palette", "flume.dev" }) do
                local flume = require("flume")
                flume.setup({ schema = "mira", dev = true, watch_sync = false, overrides = { accent = "#abcdef" } })
                local path = require("flume.extras").get_plugin_dir() .. "/lua/flume/palette.lua"
                package.preload[module] = function()
                    if module == "flume.dev" then
                        local broken = {
                            stop = function()
                                error("broken edited stop")
                            end,
                        }
                        broken.start = function()
                            broken.stop()
                        end
                        return broken
                    end
                    local _, syntax_error = loadstring("local = syntax error")
                    error(syntax_error)
                end
                vim.api.nvim_exec_autocmds("BufWritePost", { pattern = path, modeline = false })
                equal(require("flume"), flume, "failed reload discarded working source")
                equal(flume.config.schema, "mira", "failed reload lost editor choice")
                equal(flume.colors.accent, "#abcdef", "failed reload lost overrides")
                equal(#vim.api.nvim_get_autocmds({ group = "FlumeDevReload" }), 1, "recovery save hook is missing")
                package.preload[module] = nil
                vim.api.nvim_exec_autocmds("BufWritePost", { pattern = path, modeline = false })
                truthy(require("flume") ~= flume, "corrected source did not reload")
                equal(require("flume").config.schema, "mira", "recovered reload lost schema")
            end
            equal(errors, 3, "reload failures were not reported")
        end, debug.traceback)
        package.preload["flume"] = nil
        package.preload["flume.palette"] = nil
        package.preload["flume.dev"] = nil
        vim.notify = original_notify
        require("flume").setup({ watch_sync = false })
        if not ok then
            error(err)
        end
    end)

    test("named lualine theme follows palettes and runtime overrides", function()
        for _, schema in ipairs(require("flume.palette").schema_order) do
            require("flume").setup({ schema = schema, watch_sync = false, overrides = { accent = "#abcdef" } })
            local c = require("flume").colors
            local theme = dofile("lua/lualine/themes/flume.lua")
            for _, mode in ipairs({ "normal", "insert", "visual", "replace", "command", "terminal" }) do
                equal(theme[mode].c.fg, c.text, schema .. " " .. mode .. " text")
                equal(theme[mode].c.bg, c.surface_alt, schema .. " " .. mode .. " surface")
            end
            equal(theme.normal.a.fg, "#abcdef", "lualine ignored override")
            equal(theme.inactive.c.bg, c.surface, "inactive surface")
            local highlight = vim.api.nvim_get_hl(0, { name = "NvimTreeStatusLine", link = false })
            equal(highlight.fg, tonumber(c.text:sub(2), 16), "tree statusline text")
            equal(highlight.bg, tonumber(c.surface_alt:sub(2), 16), "tree statusline surface")
            equal(highlight.bold, true, "tree statusline weight")
        end
        require("flume").setup({})
    end)
end

return M
