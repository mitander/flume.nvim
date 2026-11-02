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

    test("Linux sync reloads Ghostty with SIGUSR2 and reports adapter failures", function()
        local state = require("flume.state")
        local original_activate = state.activate
        local original_system = vim.fn.system
        local original_executable = vim.fn.executable
        local original_has = vim.fn.has
        local original_home = vim.env.HOME
        local original_tmux = vim.env.TMUX
        local calls, exit_code, pkill_available = {}, 0, true

        state.activate = function()
            return {}
        end
        vim.env.HOME = ""
        vim.env.TMUX = nil
        vim.fn.has = function(name)
            if name == "linux" then
                return 1
            end
            if name == "mac" then
                return 0
            end
            return original_has(name)
        end
        vim.fn.executable = function(name)
            return name == "pkill" and pkill_available and 1 or 0
        end
        vim.fn.system = function(command)
            calls[#calls + 1] = command
            -- Set the real shell status without signalling any host processes.
            return original_system({ "sh", "-c", "exit " .. exit_code })
        end

        local ok, err = xpcall(function()
            local sync = require("flume.sync")
            local result = sync.run({ schema = "mira", quiet = true })
            equal(result.ghostty_reloaded, true, "successful Linux reload")
            equal(#calls, 1, "Linux adapter call count")
            equal(table.concat(calls[1], ","), "pkill,-USR2,-x,ghostty", "Linux reload command")

            exit_code = 1
            result = sync.run({ schema = "mira", quiet = true })
            equal(result.ghostty_reloaded, false, "failed Linux reload reported success")
            equal(#calls, 2, "failed reload did not invoke adapter")

            pkill_available = false
            result = sync.run({ schema = "mira", quiet = true })
            equal(result.ghostty_reloaded, false, "missing pkill reported success")
            equal(#calls, 2, "missing pkill invoked adapter")
        end, debug.traceback)

        state.activate = original_activate
        vim.fn.system = original_system
        vim.fn.executable = original_executable
        vim.fn.has = original_has
        vim.env.HOME = original_home
        vim.env.TMUX = original_tmux
        if not ok then
            error(err)
        end
    end)

    test("sync feedback names only installed integrations needing a reload", function()
        local state = require("flume.state")
        local apps = require("flume.integrations").apps
        local original_activate, original_current = state.activate, state.get_current
        local original_executable, original_notify = vim.fn.executable, vim.notify
        local original_home, original_tmux = vim.env.HOME, vim.env.TMUX
        local root = vim.fn.tempname()
        local destinations = {}
        local message
        vim.fn.mkdir(root .. "/current", "p")
        state.activate = function()
            return {}
        end
        state.get_current = function()
            return root .. "/current"
        end
        vim.fn.executable = function()
            return 0
        end
        vim.notify = function(value)
            message = value
        end
        vim.env.HOME, vim.env.TMUX = root, nil
        for _, name in ipairs({ "ghostty", "tmux", "pi" }) do
            destinations[name] = apps[name].dest
            apps[name].dest = root .. "/" .. name
        end

        local ok, err = xpcall(function()
            local sync = require("flume.sync")
            sync.run({ schema = "opal" })
            equal(message, "Flume schema opal synchronized", "unconfigured apps produce no reload noise")

            local uv = vim.uv or vim.loop
            vim.fn.writefile({ "unrelated theme" }, root .. "/personal")
            assert(uv.fs_symlink(root .. "/personal", apps.ghostty.dest))
            sync.run({ schema = "opal" })
            equal(message, "Flume schema opal synchronized", "foreign theme links produce no reload noise")
            assert(uv.fs_unlink(apps.ghostty.dest))

            vim.fn.writefile({ "theme" }, root .. "/current/ghostty")
            assert(uv.fs_symlink(root .. "/current/ghostty", apps.ghostty.dest))
            sync.run({ schema = "opal" })
            equal(
                message,
                "Flume schema opal synchronized\nGhostty: reload configuration manually.",
                "installed adapter failure retains an actionable hint"
            )
            message = nil
            sync.run({ schema = "opal", quiet = true })
            equal(message, nil, "quiet sync stays silent")
        end, debug.traceback)

        for name, destination in pairs(destinations) do
            apps[name].dest = destination
        end
        state.activate, state.get_current = original_activate, original_current
        vim.fn.executable, vim.notify = original_executable, original_notify
        vim.env.HOME, vim.env.TMUX = original_home, original_tmux
        vim.fn.delete(root, "rf")
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
        state.get_legacy_current = function()
            return root .. "/legacy"
        end
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
            if name == "mac" then
                return 1
            end
            if name == "linux" then
                return 0
            end
            return original_has(name)
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
                local export =
                    vim.json.decode(table.concat(vim.fn.readfile(state.get_current() .. "/palette.json"), "\n"))
                equal(export.schema, schema, "export did not switch")
                equal(
                    export.colors.accent,
                    require("flume.palette")[schema].accent,
                    "editor override leaked into export"
                )
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
                if destination == state.get_current() then
                    return nil, "injected publication failure"
                end
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
        if not ok then
            error(err)
        end
    end)

    test("sync refreshes source and exports only in development mode", function()
        local root = require("flume.extras").get_plugin_dir()
        local palette_path = root .. "/lua/flume/palette.lua"
        local compiler_path = root .. "/lua/flume/compiler.lua"
        local palette_source = vim.fn.readfile(palette_path)
        local compiler_source = vim.fn.readfile(compiler_path)
        local original_data, original_home = vim.env.FLUME_DATA_DIR, vim.env.HOME
        local original_executable, original_notify = vim.fn.executable, vim.notify
        local data = vim.fn.tempname()
        vim.env.FLUME_DATA_DIR, vim.env.HOME = data, data
        vim.fn.executable = function()
            return 0
        end
        local notices = {}
        vim.notify = function(message)
            notices[#notices + 1] = message
        end
        local function read(path)
            return table.concat(vim.fn.readfile(path), "\n")
        end

        local ok, err = xpcall(function()
            local flume = require("flume")
            flume.setup({ schema = "dusk", watch_sync = false })
            require("flume.compiler") -- Cache both modules before the source edits.
            local changed_palette =
                table.concat(palette_source, "\n"):gsub('accent = "#7dacbb"', 'accent = "#abcdef"', 1)
            vim.fn.writefile(vim.split(changed_palette, "\n", { plain = true }), palette_path)
            local changed_compiler =
                table.concat(compiler_source, "\n"):gsub("# Flume Theme for Ghostty", "# Edited Ghostty exporter", 1)
            vim.fn.writefile(vim.split(changed_compiler, "\n", { plain = true }), compiler_path)
            local artifact = read(root .. "/extras/ghostty/flume-dusk")

            vim.cmd("FlumeSync")
            equal(require("flume"), flume, "normal sync reloaded source")
            equal(read(root .. "/extras/ghostty/flume-dusk"), artifact, "normal sync compiled artifacts")
            truthy(flume.colors.accent ~= "#abcdef", "normal sync adopted source edit")

            flume.setup({ schema = "dusk", dev = true, watch_sync = false, overrides = { text = "#123456" } })
            vim.cmd("FlumeSync")
            flume = require("flume")
            equal(flume.colors.accent, "#abcdef", "dev sync missed fresh palette")
            equal(flume.colors.text, "#123456", "dev sync lost editor options")
            local export = vim.json.decode(read(data .. "/current/palette.json"))
            equal(export.colors.accent, "#abcdef", "dev sync published stale palette")
            truthy(export.colors.text ~= "#123456", "editor override leaked into export")
            truthy(
                read(data .. "/current/ghostty"):find("# Edited Ghostty exporter", 1, true),
                "dev sync used cached exporter"
            )
            equal(flume.config.dev, true, "dev sync lost development mode")
            truthy(notices[#notices]:find("synchronized", 1, true), "missing sync confirmation")
            truthy(not notices[#notices]:find("Ghostty", 1, true), "uninstalled app produced reload noise")

            vim.cmd("FlumeSync mira")
            equal(require("flume").config.schema, "mira", "explicit dev switch ignored")
            equal(require("flume.state").get_schema(), "mira", "explicit dev switch not published")

            -- Model a schema added in source but absent from the old module cache.
            require("flume.palette").schemas.mesa = nil
            vim.cmd("FlumeSync mesa")
            equal(require("flume.state").get_schema(), "mesa", "dev sync validated against stale schemas")

            -- Reload failure must not compile, publish, or request app reloads.
            local active = (vim.uv or vim.loop).fs_readlink(data .. "/current")
            vim.fn.writefile({ "local = syntax error" }, palette_path)
            vim.cmd("FlumeSync")
            equal((vim.uv or vim.loop).fs_readlink(data .. "/current"), active, "failed reload published state")
            truthy(notices[#notices]:find("reload failed", 1, true), "reload failure not reported")
            equal(require("flume").config.schema, "mesa", "failed reload changed choice")

            vim.fn.writefile(palette_source, palette_path)
            package.preload["flume.compiler"] = function()
                return {
                    compile_all = function()
                        error("injected compile failure")
                    end,
                }
            end
            equal(pcall(vim.cmd, "FlumeSync dusk"), false, "failed compilation reported success")
            equal((vim.uv or vim.loop).fs_readlink(data .. "/current"), active, "failed compilation published state")
            package.preload["flume.compiler"] = nil
            vim.cmd("FlumeSync dusk")
            equal(require("flume.state").get_schema(), "dusk", "sync did not recover")
        end, debug.traceback)

        package.preload["flume.compiler"] = nil
        vim.fn.writefile(palette_source, palette_path)
        vim.fn.writefile(compiler_source, compiler_path)
        require("flume").reload({ quiet = true })
        require("flume.compiler").compile_all({ activate = false })
        vim.fn.executable, vim.notify = original_executable, original_notify
        vim.env.FLUME_DATA_DIR, vim.env.HOME = original_data, original_home
        vim.fn.delete(data, "rf")
        require("flume").setup({ watch_sync = false })
        if not ok then
            error(err)
        end
    end)

    test("cross-process sync refreshes rendered palette colors without losing local options", function()
        local uv = vim.uv or vim.loop
        local flume = require("flume")
        local root = require("flume.extras").get_plugin_dir()
        local palette_path = root .. "/lua/flume/palette.lua"
        local tools_path = root .. "/extras/fish/flume-tools.fish"
        local original_palette, original_tools = vim.fn.readfile(palette_path), vim.fn.readfile(tools_path)
        local original_data, original_notify = vim.env.FLUME_DATA_DIR, vim.notify
        local original_loader = package.preload["flume.palette"]
        local original_highlights = flume.set_highlights
        local errors = {}
        vim.notify = function(message, level)
            if level == vim.log.levels.ERROR then
                errors[#errors + 1] = message
            end
        end
        local legacy = root .. "/extras/current"
        local original_legacy = uv.fs_readlink(legacy)
        local data = vim.fn.tempname()
        vim.fn.mkdir(data .. "/home", "p")
        vim.env.FLUME_DATA_DIR = data .. "/state"
        local source = table.concat(original_palette, "\n")
        local events = 0
        local group = vim.api.nvim_create_augroup("FlumeCrossProcessProbe", { clear = true })
        vim.api.nvim_create_autocmd("ColorScheme", {
            group = group,
            callback = function()
                events = events + 1
            end,
        })

        -- The publisher has its own Lua cache. Disable host reload adapters even
        -- after development sync reloads its modules, and keep Pi's home private.
        local publisher = data .. "/publish.lua"
        vim.fn.writefile({
            "vim.opt.runtimepath:prepend(vim.fn.getcwd())",
            "vim.fn.executable = function() return 0 end",
            "local ok, err = xpcall(function()",
            "  local schema = vim.env.FLUME_TEST_SCHEMA",
            '  require("flume").setup({ schema = schema, dev = true, watch_sync = false })',
            '  vim.cmd("FlumeSync " .. schema)',
            "end, debug.traceback)",
            'if not ok then vim.api.nvim_err_writeln(err); vim.cmd("cquit 1") end',
        }, publisher)
        local function publish(schema)
            local output = vim.fn.system({
                "env",
                "HOME=" .. data .. "/home",
                "FLUME_DATA_DIR=" .. data .. "/state",
                "FLUME_TEST_SCHEMA=" .. schema,
                vim.v.progpath,
                "--headless",
                "--clean",
                "-c",
                "lua dofile(" .. vim.fn.string(publisher) .. ")",
                "-c",
                "qa!",
            })
            equal(vim.v.shell_error, 0, "publisher failed: " .. output)
        end
        local function change_color(schema, role, color)
            local start = assert(source:find("M." .. schema .. " = ", 1, true))
            local changed, replacements =
                source:sub(start):gsub("(\n    " .. role .. ' = )"#%x%x%x%x%x%x"', '%1"' .. color .. '"', 1)
            equal(replacements, 1, "fixture must edit the selected canonical role")
            source = source:sub(1, start - 1) .. changed
            vim.fn.writefile(vim.split(source, "\n", { plain = true }), palette_path)
        end
        local function await_background(background)
            truthy(
                vim.wait(2000, function()
                    return vim.api.nvim_get_hl(0, { name = "Normal" }).bg == background
                end, 10),
                "receiver did not repaint from the publisher's changed palette"
            )
        end

        local ok, err = xpcall(function()
            if original_legacy then
                assert(uv.fs_unlink(legacy))
            end
            require("flume.state").activate("mira")
            flume.setup({
                schema = "mira",
                follow_sync = false,
                overrides = { syntax_property = "#123456" },
                schema_overrides = { mira = { syntax_function = "#aabbcc" } },
                styles = { keywords = { italic = true } },
                highlights = { FlumeSyncProbe = { fg = "#fedcba" } },
            })
            vim.cmd.colorscheme("flume")
            local editor_name = vim.g.colors_name
            local old_set = uv.fs_readlink(data .. "/state/current")

            change_color("mira", "bg", "#202b35")
            change_color("mira", "syntax_string", "#b9c5e2")
            change_color("mira", "red", "#d6a7bf")
            publish("mira")
            truthy(uv.fs_readlink(data .. "/state/current") ~= old_set, "publisher did not create a new activation")
            local exported = vim.json.decode(table.concat(vim.fn.readfile(data .. "/state/current/palette.json"), "\n"))
            equal(exported.colors.bg, "#202b35", "publisher exported stale colors")
            await_background(0x202b35)
            equal(vim.api.nvim_get_hl(0, { name = "String" }).fg, 0xb9c5e2, "receiver kept stale syntax ink")
            equal(vim.g.terminal_color_1, "#d6a7bf", "receiver kept stale terminal ink")
            equal(require("flume"), flume, "following sync unnecessarily reloaded the whole plugin")
            equal(vim.g.colors_name, editor_name, "same-schema refresh replaced the editor entry point")
            equal(vim.api.nvim_get_hl(0, { name = "@variable.member" }).fg, 0x123456, "global override was lost")
            equal(vim.api.nvim_get_hl(0, { name = "Function" }).fg, 0xaabbcc, "schema override was lost")
            equal(vim.api.nvim_get_hl(0, { name = "Keyword" }).italic, true, "syntax style was lost")
            equal(vim.api.nvim_get_hl(0, { name = "FlumeSyncProbe" }).fg, 0xfedcba, "exact highlight was lost")
            equal(flume.config.follow_sync, false, "following sync changed the startup preference")
            equal(flume.config.dev, false, "receiving fresh colors must not require development mode")

            -- A different schema must also come from fresh source, not the
            -- palette table loaded by the receiver's preceding activation.
            change_color("opal", "bg", "#eee7f4")
            publish("opal")
            await_background(0xeee7f4)
            equal(flume.config.schema, "opal", "receiver did not follow the schema switch")
            equal(vim.g.colors_name, "flume-opal", "schema switch kept the old entry point")
            equal(vim.api.nvim_get_hl(0, { name = "@variable.member" }).fg, 0x123456, "switch lost local options")

            local previous_events = events
            publish("opal")
            vim.wait(200, function()
                return false
            end, 10)
            equal(events, previous_events, "identical publication repainted the receiver")

            local previous_set = uv.fs_readlink(data .. "/state/current")
            vim.fn.writefile({ "# Cross-process static-artifact change" }, tools_path, "a")
            publish("opal")
            truthy(
                uv.fs_readlink(data .. "/state/current") ~= previous_set,
                "static artifact did not change activation"
            )
            vim.wait(200, function()
                return false
            end, 10)
            equal(events, previous_events, "unchanged palette colors repainted after a static-artifact update")

            local working_palette = require("flume.palette")
            package.preload["flume.palette"] = function()
                error("injected palette read failure")
            end
            change_color("opal", "bg", "#e9e3ef")
            publish("opal")
            local failed_set = uv.fs_readlink(data .. "/state/current")
            truthy(
                vim.wait(2000, function()
                    return #errors == 1
                end, 10),
                "source failure was not reported"
            )
            truthy(errors[1]:find("injected palette read failure", 1, true), "source failure lost its cause")
            equal(require("flume.palette"), working_palette, "source failure discarded the working palette cache")
            equal(vim.api.nvim_get_hl(0, { name = "Normal" }).bg, 0xeee7f4, "source failure repainted the editor")
            equal(events, previous_events, "source failure emitted a colorscheme change")

            package.preload["flume.palette"] = original_loader
            publish("opal")
            equal(uv.fs_readlink(data .. "/state/current"), failed_set, "retry unexpectedly needed a different set")
            await_background(0xe9e3ef)

            working_palette = require("flume.palette")
            flume.set_highlights = function(namespace, colors, config)
                original_highlights(namespace, colors, config)
                if colors.bg == "#e5dfeb" then
                    error("injected palette application failure")
                end
            end
            change_color("opal", "bg", "#e5dfeb")
            publish("opal")
            failed_set = uv.fs_readlink(data .. "/state/current")
            truthy(
                vim.wait(2000, function()
                    return #errors == 2
                end, 10),
                "application failure was not reported"
            )
            truthy(
                errors[2]:find("injected palette application failure", 1, true),
                "application failure lost its cause"
            )
            equal(require("flume.palette"), working_palette, "application failure discarded the working palette cache")
            equal(flume.colors.bg, "#e9e3ef", "application failure retained failed color data")
            equal(
                vim.api.nvim_get_hl(0, { name = "Normal" }).bg,
                0xe9e3ef,
                "application failure left partial highlights"
            )
            equal(vim.api.nvim_get_hl(0, { name = "@variable.member" }).fg, 0x123456, "rollback lost local options")

            flume.set_highlights = original_highlights
            publish("opal")
            equal(uv.fs_readlink(data .. "/state/current"), failed_set, "application retry changed the published set")
            await_background(0xe5dfeb)

            flume.setup({ schema = "opal", watch_sync = false })
            publish("mira")
            vim.wait(200, function()
                return false
            end, 10)
            equal(flume.config.schema, "opal", "disabled receiver followed publication")
            equal(vim.api.nvim_get_hl(0, { name = "Normal" }).bg, 0xe5dfeb, "disabled receiver repainted")

            flume.setup({ schema = "opal" })
            vim.cmd.colorscheme("habamax")
            local foreign_background = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
            publish("opal")
            vim.wait(200, function()
                return false
            end, 10)
            equal(vim.g.colors_name, "habamax", "publication replaced a foreign colorscheme")
            equal(vim.api.nvim_get_hl(0, { name = "Normal" }).bg, foreign_background, "foreign theme repainted")
        end, debug.traceback)

        require("flume.watch").stop()
        vim.api.nvim_del_augroup_by_id(group)
        package.preload["flume.palette"] = original_loader
        flume.set_highlights = original_highlights
        vim.notify = original_notify
        vim.fn.writefile(original_palette, palette_path)
        vim.fn.writefile(original_tools, tools_path)
        require("flume").reload({ quiet = true })
        require("flume.compiler").compile_all({ activate = false })
        uv.fs_unlink(legacy)
        if original_legacy then
            assert(uv.fs_symlink(original_legacy, legacy, { dir = true, junction = false }))
        end
        vim.env.FLUME_DATA_DIR = original_data
        vim.fn.delete(data, "rf")
        require("flume").setup({ watch_sync = false })
        if not ok then
            error(err)
        end
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
        local reload_error_count = 0

        vim.notify = function(_, level)
            if level == vim.log.levels.ERROR then
                reload_error_count = reload_error_count + 1
            end
        end

        local ok, err = xpcall(function()
            for _, module in ipairs({ "flume", "flume.palette", "flume.dev", "flume.commands" }) do
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
            equal(reload_error_count, 4, "reload failures were not reported")
        end, debug.traceback)

        package.preload["flume"] = nil
        package.preload["flume.palette"] = nil
        package.preload["flume.dev"] = nil
        package.preload["flume.commands"] = nil
        vim.notify = original_notify
        require("flume").setup({ watch_sync = false })
        if not ok then
            error(err)
        end
    end)

    test("named lualine theme follows palettes and runtime overrides", function()
        for _, schema in ipairs(require("flume.palette").schema_order) do
            require("flume").setup({ schema = schema, watch_sync = false, overrides = { accent = "#abcdef" } })
            local colors = require("flume").colors
            local theme = dofile("lua/lualine/themes/flume.lua")

            for _, mode in ipairs({ "normal", "insert", "visual", "replace", "command", "terminal" }) do
                equal(theme[mode].c.fg, colors.text, schema .. " " .. mode .. " text")
                equal(theme[mode].c.bg, colors.surface_alt, schema .. " " .. mode .. " surface")
            end
            equal(theme.normal.a.fg, "#abcdef", "lualine ignored override")
            equal(theme.inactive.c.bg, colors.surface, "inactive surface")
            for _, section in ipairs({ "a", "b", "c" }) do
                equal(theme.inactive[section].fg, colors.muted, "inactive statusline content uses readable muted ink")
            end

            local highlight = vim.api.nvim_get_hl(0, { name = "NvimTreeStatusLine", link = false })
            equal(highlight.fg, tonumber(colors.text:sub(2), 16), "tree statusline text")
            equal(highlight.bg, tonumber(colors.surface_alt:sub(2), 16), "tree statusline surface")
            equal(highlight.bold, true, "tree statusline weight")
        end
        require("flume").setup({})
    end)
end

return M
