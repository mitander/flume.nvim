local M = {}

function M.register(test, equal, truthy)
    test("shared state survives checkout replacement and legacy includes follow", function()
        local extras = require("flume.extras")
        local original_dir = extras.get_plugin_dir
        local original_data = vim.env.FLUME_DATA_DIR
        local root = vim.fn.tempname()
        local checkout = root .. "/plugin"
        local data = root .. "/data"
        local uv = vim.uv or vim.loop
        local ok, err = xpcall(function()
            vim.fn.mkdir(checkout .. "/extras/old", "p")
            vim.fn.writefile({ "opal" }, checkout .. "/extras/old/schema")
            assert(uv.fs_symlink(".current-set-opal-0123456789abcdef", checkout .. "/extras/current"))
            assert(uv.fs_rename(checkout .. "/extras/old", checkout .. "/extras/.current-set-opal-0123456789abcdef"))
            for _, integration in ipairs(extras.integrations) do
                for _, schema in ipairs(require("flume.palette").schema_order) do
                    local source = integration.source:format("-" .. schema)
                    vim.fn.mkdir(vim.fn.fnamemodify(checkout .. "/" .. source, ":h"), "p")
                    vim.fn.writefile(vim.fn.readfile(original_dir() .. "/" .. source, "b"), checkout .. "/" .. source, "b")
                end
            end
            extras.get_plugin_dir = function() return checkout end
            vim.env.FLUME_DATA_DIR = data
            local state = require("flume.state")
            equal(state.get_schema(), "opal", "legacy startup migration")
            require("flume.compiler").activate("mira")
            equal(state.get_schema(), "mira", "shared marker")
            equal(uv.fs_readlink(checkout .. "/extras/current"), data .. "/current", "legacy forwarding")
            equal(vim.fn.readfile(checkout .. "/extras/current/schema")[1], "mira", "legacy consumer")
            equal(vim.fn.readfile(checkout .. "/extras/.current-set-opal-0123456789abcdef/schema")[1], "opal", "old data retained")
            local exported = vim.json.decode(table.concat(vim.fn.readfile(data .. "/current/palette.json"), "\n"))
            equal(exported.schema, "mira", "semantic export in active set")
            equal(exported.colors.bg, require("flume.palette").mira.bg, "semantic active colors")
            local app = extras.get_apps().ghostty
            local destination = app.dest
            app.dest = root .. "/ghostty"
            extras.install("ghostty")
            app.dest = destination
            equal(uv.fs_readlink(root .. "/ghostty"), data .. "/current/ghostty", "installer checkout independence")
            vim.fn.delete(checkout, "rf")
            equal(state.get_schema(), "mira", "plugin uninstall removed shared choice")
            truthy(vim.fn.filereadable(root .. "/ghostty") == 1, "plugin uninstall broke installed theme")
            -- An invalid marker in the new owner must not revive legacy state.
            vim.fn.writefile({ "unknown" }, data .. "/current/schema")
            equal(state.get_schema(), nil, "invalid new state fallback")
        end, debug.traceback)
        extras.get_plugin_dir = original_dir
        vim.env.FLUME_DATA_DIR = original_data
        vim.fn.delete(root, "rf")
        if not ok then error(err) end
    end)

    test("compatibility failures preserve shared activation and user paths", function()
        local state = require("flume.state")
        local original_legacy = state.get_legacy_current
        local original_data = vim.env.FLUME_DATA_DIR
        local original_notify = vim.notify
        local root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        state.get_legacy_current = function() return root .. "/legacy" end
        vim.env.FLUME_DATA_DIR = root .. "/data"
        local warnings = 0
        vim.notify = function(_, level)
            if level == vim.log.levels.WARN then warnings = warnings + 1 end
        end
        local ok, err = xpcall(function()
            vim.fn.writefile({ "user data" }, root .. "/legacy")
            require("flume.compiler").activate("opal")
            equal(state.get_schema(), "opal", "compatibility failure prevented sync")
            equal(vim.fn.readfile(root .. "/legacy")[1], "user data", "user path replaced")
            equal(warnings, 1, "missing compatibility warning")
            local uv = vim.uv or vim.loop
            local rename = uv.fs_rename
            uv.fs_rename = function(source, destination, ...)
                if destination == state.get_current() then return nil, "injected swap failure" end
                return rename(source, destination, ...)
            end
            local activated = pcall(require("flume.compiler").activate, "mesa")
            uv.fs_rename = rename
            equal(activated, false, "failed publication reported success")
            equal(state.get_schema(), "opal", "failed publication changed active choice")
        end, debug.traceback)
        state.get_legacy_current = original_legacy
        vim.env.FLUME_DATA_DIR = original_data
        vim.notify = original_notify
        vim.fn.delete(root, "rf")
        if not ok then error(err) end
    end)

    test("legacy forwarding serializes ownership checks and rejects path-like targets", function()
        local state = require("flume.state")
        local uv = vim.uv or vim.loop
        local original_legacy = state.get_legacy_current
        local original_data = vim.env.FLUME_DATA_DIR
        local symlink = uv.fs_symlink
        local root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        state.get_legacy_current = function() return root .. "/legacy" end
        vim.env.FLUME_DATA_DIR = root .. "/first"
        local ok, err = xpcall(function()
            assert(symlink(".current-set-opal-0123456789abcdef/../../user", root .. "/legacy"))
            equal(state.forward_legacy(), false, "path-like target was recognized")
            equal(uv.fs_readlink(root .. "/legacy"), ".current-set-opal-0123456789abcdef/../../user", "unknown link changed")
            uv.fs_unlink(root .. "/legacy")
            assert(symlink(".current-set-opal-0123456789abcdef", root .. "/legacy"))
            local second_result
            uv.fs_symlink = function(target, destination, ...)
                if destination:find("legacy.flume-", 1, true) then
                    vim.env.FLUME_DATA_DIR = root .. "/second"
                    second_result = state.forward_legacy()
                    vim.env.FLUME_DATA_DIR = root .. "/first"
                end
                return symlink(target, destination, ...)
            end
            truthy(state.forward_legacy(), "first forwarding failed")
            equal(second_result, false, "second activation bypassed forwarding lock")
            equal(uv.fs_readlink(root .. "/legacy"), root .. "/first/current", "wrong owner forwarded")
            uv.fs_symlink = symlink
            equal(state.forward_legacy(), true, "released lock was not reusable")
            uv.fs_unlink(root .. "/legacy")
            assert(symlink(".current-set-opal-0123456789abcdef", root .. "/legacy"))
            uv.fs_symlink = function(target, destination, ...)
                local result, error_message = symlink(target, destination, ...)
                if destination:find("legacy.flume-", 1, true) then
                    uv.fs_unlink(root .. "/legacy")
                    vim.fn.writefile({ "new user file" }, root .. "/legacy")
                end
                return result, error_message
            end
            equal(state.forward_legacy(), false, "changed path was overwritten")
            equal(vim.fn.readfile(root .. "/legacy")[1], "new user file", "racing user file changed")
        end, debug.traceback)
        uv.fs_symlink = symlink
        state.get_legacy_current = original_legacy
        vim.env.FLUME_DATA_DIR = original_data
        vim.fn.delete(root, "rf")
        if not ok then error(err) end
    end)
end

return M
