local M = {}

function M.register(test, equal, truthy)
    local function notifications(fn)
        local original = vim.notify
        local messages = {}
        vim.notify = function(message, level)
            messages[#messages + 1] = { message = message, level = level }
        end
        local ok, err = xpcall(function()
            fn(messages)
        end, debug.traceback)
        vim.notify = original
        assert(ok, err)
    end

    test("legacy colorscheme keeps the selected palette and warns once across reloads", function()
        notifications(function(messages)
            local flume = require("flume")
            local state = require("flume.state").get_schema()
            for _, schema in ipairs({ "dusk", "opal", "mira", "mesa" }) do
                flume.setup({ schema = schema, watch_sync = false, overrides = { syntax_comment = "#abcdef" } })
                local events = 0
                local group = vim.api.nvim_create_augroup("FlumeLegacyEntryTest", { clear = true })
                vim.api.nvim_create_autocmd("ColorScheme", {
                    group = group,
                    callback = function()
                        events = events + 1
                    end,
                })
                local ok, err = pcall(vim.cmd.colorscheme, "flume")
                vim.api.nvim_del_augroup_by_id(group)
                truthy(ok, err)
                equal(events, 1, "legacy entry must not emit a second ColorScheme event")
                equal(vim.g.colors_name, "flume-" .. schema, "canonical editor identity")
                equal(flume.config.schema, schema, "legacy entry reset the palette")
                equal(vim.api.nvim_get_hl(0, { name = "Comment", link = false }).fg, 0xabcdef)
                truthy(flume.is_active(), "watcher cannot recognize the legacy entry")
            end
            truthy(flume.reload({ quiet = true }), "reload failed")
            vim.cmd.colorscheme("flume")
            equal(#messages, 1, "legacy entry warning repeated after reload")
            equal(messages[1].level, vim.log.levels.WARN)
            truthy(messages[1].message:find(":help flume%-migration"), "missing migration guidance")
            equal(require("flume.state").get_schema(), state, "legacy entry published shared themes")
            -- Old exact-name pickers can discover the compatibility entry too.
            truthy(vim.tbl_contains(vim.fn.getcompletion("flume", "color"), "flume"))
        end)
    end)

    test("compatibility palette selectors normalize without changing caller options", function()
        notifications(function(messages)
            local flume = require("flume")
            for _, key in ipairs({ "style", "variant" }) do
                for _, schema in ipairs({ "dusk", "opal", "mira", "mesa" }) do
                    local opts = { [key] = schema, watch_sync = false, styles = { comments = { italic = true } } }
                    flume.setup(opts)
                    equal(flume.config.schema, schema)
                    equal(vim.g.colors_name, "flume-" .. schema)
                    equal(flume.config[key], nil, "legacy selector survived normalization")
                    equal(opts[key], schema, "caller options were modified")
                    truthy(vim.api.nvim_get_hl(0, { name = "@comment", link = false }).italic)
                end
            end
            equal(#messages, 2, "expected one actionable warning per compatibility spelling")
            flume.setup({ schema = "mira", style = "mira", variant = "mira", watch_sync = false })
            equal(#messages, 2, "matching selectors repeated warnings")
            truthy(flume.reload({ quiet = true }))
            equal(#messages, 2, "reload repeated compatibility warnings")
        end)
    end)

    test("ambiguous and invalid selectors fail before changing the editor", function()
        local flume = require("flume")
        flume.setup({ schema = "opal", watch_sync = false })
        for _, opts in ipairs({
            { schema = "opal", style = "mira" },
            { style = "mira", variant = "mesa" },
            { style = "unknown" },
            { variant = "mist" },
            { style = false },
            { variant = {} },
        }) do
            local before = flume.config
            local ok = pcall(flume.setup, opts)
            equal(ok, false, "invalid selectors were silently accepted")
            equal(flume.config, before, "failed setup replaced the current options")
            equal(vim.g.colors_name, "flume-opal", "failed setup changed the editor")
        end
    end)
end

return M
