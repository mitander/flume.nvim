local M = {}

local function panes()
    local result = {}
    for _, window in ipairs(vim.api.nvim_list_wins()) do
        local buffer = vim.api.nvim_win_get_buf(window)
        local name = vim.api.nvim_buf_get_name(buffer)
        if name == "flume-tweak://roles" then
            result.roles, result.roles_buffer = window, buffer
        elseif name:match("^flume%-tweak://sample/") then
            result.sample, result.sample_buffer = window, buffer
        elseif name == "flume-tweak://states" then
            result.states = window
        end
    end
    return result
end

local function press(key)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "xt", false)
end

function M.register(test, equal, truthy)
    test("namespace highlight rendering preserves global theme and callback ordering", function()
        local flume = require("flume")
        local ns = vim.api.nvim_create_namespace("FlumeTweakRenderingTest")
        flume.setup({ schema = "dusk", watch_sync = false })
        local original = vim.deepcopy(flume.config)
        local colors = vim.deepcopy(flume.colors)
        local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
        local terminal = vim.g.terminal_color_1
        local background = vim.o.background
        local palette = require("flume.palette").opal
        local observed
        flume.set_highlights(ns, palette, {
            styles = { comments = { italic = true } },
            highlights = {
                TweakCallbackProbe = function(c)
                    observed = vim.api.nvim_get_hl(ns, { name = "Function", link = false }).fg
                    return { fg = c.syntax_type }
                end,
            },
        })
        equal(observed, tonumber(palette.syntax_function:sub(2), 16), "callbacks see completed base highlights")
        equal(vim.api.nvim_get_hl(ns, { name = "Comment" }).italic, true, "namespace retains styles")
        truthy(vim.deep_equal(original, flume.config), "namespace changed editor config")
        truthy(vim.deep_equal(colors, flume.colors), "namespace changed resolved editor colors")
        truthy(
            vim.deep_equal(normal, vim.api.nvim_get_hl(0, { name = "Normal", link = false })),
            "global Normal changed"
        )
        equal(vim.g.terminal_color_1, terminal, "terminal ink changed")
        equal(vim.o.background, background, "background option changed")
    end)

    test("parser-free FlumeTweak preserves the complete global highlight map", function()
        dofile("plugin/flume.lua")
        require("flume").setup({ schema = "dusk", watch_sync = false })
        local query_files = vim.treesitter.query.get_files
        vim.treesitter.query.get_files = function()
            return {}
        end
        local before = vim.api.nvim_get_hl(0, {})
        local ok, err = xpcall(function()
            vim.cmd("FlumeTweak")
            for _ in ipairs(require("flume.tweak_samples")) do
                local windows = panes()
                equal(
                    vim.api.nvim_buf_get_lines(windows.roles_buffer, 4, 5, false)[1],
                    "Plain text (no parser/query)",
                    "missing parsers are explicit"
                )
                press("s")
            end
            press("q")
            truthy(
                vim.deep_equal(before, vim.api.nvim_get_hl(0, {})),
                "parser-free preview changed the global highlight map"
            )
        end, debug.traceback)
        vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name or "default" })
        vim.treesitter.query.get_files = query_files
        if not ok then
            error(err)
        end
    end)

    test("FlumeTweak edits only its windows and copies mergeable per-palette drafts", function()
        dofile("plugin/flume.lua")
        local flume = require("flume")
        flume.setup({
            schema = "mira",
            watch_sync = false,
            dev = false,
            overrides = { syntax_function = "#abcdef" },
            highlights = { Function = { fg = "#112233" } },
        })
        local config = vim.deepcopy(flume.config)
        local colors = vim.deepcopy(flume.colors)
        local global_function = vim.api.nvim_get_hl(0, { name = "Function", link = false })
        local background, colors_name = vim.o.background, vim.g.colors_name
        local previous = vim.api.nvim_get_current_buf()
        local origin = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_set_current_buf(origin)
        vim.api.nvim_buf_set_lines(origin, 0, -1, false, { "untouched user work" })
        local origin_window = vim.api.nvim_get_current_win()
        local window_options = {}
        for _, option in ipairs({ "diff", "scrollbind", "cursorbind", "winfixwidth" }) do
            window_options[option] = vim.wo[origin_window][option]
            vim.wo[origin_window][option] = true
        end
        local ns = vim.api.nvim_create_namespace("FlumeTweak")
        local old_input, old_select, old_notify = vim.ui.input, vim.ui.select, vim.notify
        local old_activate = require("flume.state").activate
        local input, selection, notifications
        notifications = {}
        vim.ui.input = function(_, done)
            input = done
        end
        vim.ui.select = function(_, _, done)
            selection = done
        end
        vim.notify = function(message)
            notifications[#notifications + 1] = message
        end
        require("flume.state").activate = function()
            error("preview must not publish shared themes")
        end
        local filetype_events = 0
        local group = vim.api.nvim_create_augroup("FlumeTweakFiletypeTest", { clear = true })
        vim.api.nvim_create_autocmd("FileType", {
            group = group,
            callback = function()
                filetype_events = filetype_events + 1
            end,
        })
        local ok, err = xpcall(function()
            vim.cmd("FlumeTweak dusk")
            local windows = panes()
            truthy(windows.roles and windows.sample and windows.states, "all preview panes opened")
            for _, window in ipairs({ windows.roles, windows.sample, windows.states }) do
                equal(vim.wo[window].diff, false, "preview does not inherit diff mode")
                equal(vim.wo[window].scrollbind, false, "preview does not inherit scroll binding")
                equal(vim.wo[window].cursorbind, false, "preview does not inherit cursor binding")
                equal(vim.wo[window].winfixwidth, false, "preview owns its layout")
            end
            equal(vim.api.nvim_get_current_win(), windows.roles, "role controls focused")
            equal(
                vim.api.nvim_get_hl(ns, { name = "Function", link = false }).fg,
                0xabcdef,
                "role override resolved without exact group override"
            )
            local tab = vim.api.nvim_get_current_tabpage()
            vim.cmd("FlumeTweak")
            equal(vim.api.nvim_get_current_tabpage(), tab, "repeated command reuses its tab")
            press("l")
            equal(vim.api.nvim_get_hl(ns, { name = "Function", link = false }).fg, 0xb2d1f0, "live lighter candidate")
            press("<CR>")
            input("not a color")
            equal(
                vim.api.nvim_get_hl(ns, { name = "Function", link = false }).fg,
                0xb2d1f0,
                "invalid input leaves candidate unchanged"
            )
            truthy(notifications[#notifications]:find("#RRGGBB", 1, true), "invalid color explained")
            press("<CR>")
            input("#123456")
            equal(
                vim.api.nvim_get_hl(ns, { name = "Function", link = false }).fg,
                0x123456,
                "explicit color applied locally"
            )
            press("c")
            selection("syntax_keyword")
            equal(
                vim.api.nvim_get_hl(ns, { name = "Function", link = false }).fg,
                tonumber(require("flume.palette").dusk.syntax_keyword:sub(2), 16),
                "existing ink candidate"
            )
            press("p")
            equal(
                vim.api.nvim_get_hl(ns, { name = "Normal", link = false }).bg,
                tonumber(require("flume.palette").opal.bg:sub(2), 16),
                "light-palette preview background"
            )
            equal(vim.o.background, background, "light preview did not change editor appearance")
            press("<CR>")
            input("#010203")
            press("y")
            local draft = assert(loadstring("return {" .. vim.fn.getreg('"') .. "}"))().schema_overrides
            equal(
                draft.dusk.syntax_function,
                require("flume.palette").dusk.syntax_keyword,
                "Dusk draft retained across palette switch"
            )
            equal(draft.opal.syntax_function, "#010203", "Opal draft copied")
            equal(draft.mira, nil, "unedited palettes omitted")
            press("r")
            press("P")
            press("r")
            vim.fn.setreg('"', "do not overwrite")
            press("y")
            equal(vim.fn.getreg('"'), "do not overwrite", "empty draft does not overwrite register")
            for _, sample in ipairs(require("flume.tweak_samples")) do
                equal(vim.bo[windows.sample_buffer].filetype, sample.filetype, "real sample filetype")
                local status = vim.api.nvim_buf_get_lines(windows.roles_buffer, 4, 5, false)[1]
                truthy(
                    status:find("Tree-sitter", 1, true) or status:find("Plain text", 1, true),
                    "parser/fallback status visible"
                )
                press("s")
            end
            equal(filetype_events, 0, "scratch previews do not launch FileType tooling")
            truthy(vim.deep_equal(config, flume.config), "preview changed original config")
            truthy(vim.deep_equal(colors, flume.colors), "preview changed original colors")
            truthy(
                vim.deep_equal(global_function, vim.api.nvim_get_hl(0, { name = "Function", link = false })),
                "preview changed global highlights"
            )
            equal(vim.g.colors_name, colors_name, "preview selected a global colorscheme")
            press("<CR>")
            local late_input = input
            press("q")
            equal(panes().roles, nil, "close released preview panes")
            equal(vim.api.nvim_get_current_win(), origin_window, "close restored invoking window")
            vim.cmd("FlumeTweak opal")
            local reopened_color = vim.api.nvim_get_hl(ns, { name = "Function", link = false }).fg
            late_input("#ff0000")
            equal(
                vim.api.nvim_get_hl(ns, { name = "Function", link = false }).fg,
                reopened_color,
                "old input cannot recolor a new session"
            )
            press("q")
            truthy(
                vim.deep_equal(global_function, vim.api.nvim_get_hl(0, { name = "Function", link = false })),
                "late callback changed global highlights"
            )
            equal(vim.api.nvim_buf_get_lines(origin, 0, -1, false)[1], "untouched user work", "user buffer retained")
            equal(vim.bo[origin].modified, true, "user modification flag retained")
            for option in pairs(window_options) do
                equal(vim.wo[origin_window][option], true, "invoking window option retained: " .. option)
            end
        end, debug.traceback)
        if vim.api.nvim_win_is_valid(origin_window) then
            for option, value in pairs(window_options) do
                vim.wo[origin_window][option] = value
            end
        end
        vim.api.nvim_del_augroup_by_id(group)
        vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name or "default" })
        vim.ui.input, vim.ui.select, vim.notify = old_input, old_select, old_notify
        require("flume.state").activate = old_activate
        if vim.api.nvim_buf_is_valid(previous) then
            vim.api.nvim_set_current_buf(previous)
        end
        if vim.api.nvim_buf_is_valid(origin) then
            vim.api.nvim_buf_delete(origin, { force = true })
        end
        require("flume").setup({ schema = "dusk", watch_sync = false })
        if not ok then
            error(err)
        end
    end)

    test("FlumeTweak closes on theme takeover, buffer deletion and module reload", function()
        local flume = require("flume")
        flume.setup({ schema = "dusk", watch_sync = false })
        vim.cmd("FlumeTweak")
        vim.cmd("colorscheme default")
        equal(panes().roles, nil, "foreign colorscheme closes preview")
        equal(vim.g.colors_name, "default", "close did not replace foreign theme")
        flume.setup({ schema = "dusk", watch_sync = false })
        vim.cmd("FlumeTweak")
        local sample = panes().sample_buffer
        local input, complete = vim.ui.input, nil
        vim.ui.input = function(_, done)
            complete = done
        end
        press("<CR>")
        vim.ui.input = input
        local namespace = vim.api.nvim_create_namespace("FlumeTweak")
        local before = vim.api.nvim_get_hl(namespace, { name = "Function", link = false }).fg
        vim.api.nvim_buf_delete(sample, { force = true })
        complete("#010203")
        equal(
            vim.api.nvim_get_hl(namespace, { name = "Function", link = false }).fg,
            before,
            "wipeout invalidates pending input immediately"
        )
        truthy(
            vim.wait(100, function()
                return panes().roles == nil
            end),
            "buffer deletion released the preview"
        )
        vim.cmd("FlumeTweak")
        truthy(flume.reload(), "reload succeeded")
        equal(panes().roles, nil, "module reload released old preview")
        vim.cmd("FlumeTweak")
        press("q")
        equal(panes().roles, nil, "reloaded command can open and close another preview")
    end)

    test("FlumeTweak rejects inaccurate RGB and undersized previews without creating windows", function()
        local rgb, columns, lines = vim.o.termguicolors, vim.o.columns, vim.o.lines
        local notify = vim.notify
        local notices = {}
        vim.notify = function(message)
            notices[#notices + 1] = message
        end
        local tabs = #vim.api.nvim_list_tabpages()
        local ok, err = pcall(function()
            vim.o.termguicolors = false
            vim.cmd("FlumeTweak")
            equal(#vim.api.nvim_list_tabpages(), tabs, "RGB refusal creates no tab")
            truthy(notices[#notices]:find("termguicolors", 1, true), "RGB prerequisite explained")
            vim.o.termguicolors = true
            vim.o.columns, vim.o.lines = 60, 20
            vim.cmd("FlumeTweak")
            equal(#vim.api.nvim_list_tabpages(), tabs, "small layout creates no tab")
            truthy(notices[#notices]:find("80 columns", 1, true), "layout prerequisite explained")
        end)
        vim.o.termguicolors, vim.o.columns, vim.o.lines = rgb, columns, lines
        vim.notify = notify
        if not ok then
            error(err)
        end
    end)

    test("FlumeTweak can close after its invoking tab is gone without discarding work", function()
        local previous = vim.api.nvim_get_current_buf()
        local hidden = vim.o.hidden
        local origin = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_set_current_buf(origin)
        vim.api.nvim_buf_set_lines(origin, 0, -1, false, { "modified work survives", "ordinary document colors" })
        local origin_window = vim.api.nvim_get_current_win()
        local statusline, number, cursorline = vim.wo.statusline, vim.wo.number, vim.wo.cursorline
        vim.wo.statusline, vim.wo.number, vim.wo.cursorline = " original editor ", true, false
        require("flume").setup({ schema = "dusk", watch_sync = false })
        vim.cmd("redraw!")
        local before_position = vim.fn.screenpos(origin_window, 2, 1)
        local before_attribute = vim.fn.screenattr(before_position.row, before_position.col)
        vim.o.hidden = true
        local ok, err = xpcall(function()
            vim.cmd("FlumeTweak opal")
            vim.cmd("tabonly")
            press("q")
            equal(panes().roles, nil, "last preview released")
            equal(vim.api.nvim_get_current_buf(), origin, "invoking buffer restored without its old window")
            equal(vim.wo.statusline, " original editor ", "surviving window has the original statusline")
            equal(vim.wo.number, true, "surviving window has original number settings")
            equal(vim.wo.cursorline, false, "surviving window has original cursor-line settings")
            if vim.api.nvim_get_hl_ns then
                equal(vim.api.nvim_get_hl_ns({ winid = 0 }), 0, "surviving window no longer uses the preview namespace")
            end
            vim.cmd("redraw!")
            local after_position = vim.fn.screenpos(vim.api.nvim_get_current_win(), 2, 1)
            equal(
                vim.fn.screenattr(after_position.row, after_position.col),
                before_attribute,
                "restored work renders with ordinary colors"
            )
            equal(
                vim.api.nvim_buf_get_lines(origin, 0, -1, false)[1],
                "modified work survives",
                "buffer contents retained"
            )
            equal(vim.bo[origin].modified, true, "modified state retained")
        end, debug.traceback)
        vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name or "default" })
        if vim.api.nvim_buf_is_valid(previous) then
            vim.api.nvim_set_current_buf(previous)
        end
        if vim.api.nvim_buf_is_valid(origin) then
            vim.api.nvim_buf_delete(origin, { force = true })
        end
        vim.wo.statusline, vim.wo.number, vim.wo.cursorline = statusline, number, cursorline
        vim.o.hidden = hidden
        if not ok then
            error(err)
        end
    end)
end

return M
