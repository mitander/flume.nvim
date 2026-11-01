-- Native preview qualification. Requires actual parsers/queries for every selected sample.
-- FLUME_TS_RUNTIME may point to an installed Tree-sitter runtime. No tools are installed.
local draft_path = vim.fn.tempname()
local ok, failure = xpcall(function()
    vim.opt.runtimepath:prepend(vim.fn.getcwd())
    if vim.env.FLUME_TS_RUNTIME and vim.env.FLUME_TS_RUNTIME ~= "" then
        vim.opt.runtimepath:prepend(vim.env.FLUME_TS_RUNTIME)
    end
    vim.o.columns, vim.o.lines = 120, 42
    vim.o.termguicolors = true
    require("flume").setup({ schema = "dusk", watch_sync = false, dev = false })
    dofile("plugin/flume.lua")
    local namespace = vim.api.nvim_create_namespace("FlumeTweak")
    local flume = require("flume")
    local config = vim.deepcopy(flume.config)
    local colors = vim.deepcopy(flume.colors)
    -- A capture incorrectly resolved through global highlights would use this ink.
    vim.api.nvim_set_hl(0, "@string", { fg = "#010203" })
    local tokens = {
        ["queue.lua"] = "queue is full",
        ["dispatch.rs"] = "too many pending requests",
        ["inventory.py"] = "<none>",
        ["request.ts"] = "x-revision",
        ["workspace.tsx"] = "Workspaces",
        ["buffer.zig"] = "project: ready",
        ["catalog.go"] = "context",
    }

    local function panes()
        local result = {}
        for _, window in ipairs(vim.api.nvim_list_wins()) do
            local buffer = vim.api.nvim_win_get_buf(window)
            local name = vim.api.nvim_buf_get_name(buffer)
            if name == "flume-tweak://roles" then
                result.roles, result.roles_buffer = window, buffer
            elseif name:match("^flume%-tweak://sample/") then
                result.sample, result.sample_buffer = window, buffer
            end
        end
        return result
    end

    local function press(window, key)
        vim.api.nvim_set_current_win(window)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "xt", false)
    end

    local function locate(buffer, token)
        for index, line in ipairs(vim.api.nvim_buf_get_lines(buffer, 0, -1, false)) do
            local column = line:find(token, 1, true)
            if column then
                return index, column - 1
            end
        end
        error("missing native fixture token: " .. token)
    end

    local function screen_attribute(window, row, column)
        local position = vim.fn.screenpos(window, row, column + 1)
        assert(position.row > 0 and position.col > 0, "native fixture is outside its window")
        return vim.fn.screenattr(position.row, position.col)
    end

    local selected
    if vim.env.FLUME_TWEAK_LANGUAGES and vim.env.FLUME_TWEAK_LANGUAGES ~= "" then
        selected = {}
        for _, language in ipairs(vim.split(vim.env.FLUME_TWEAK_LANGUAGES, ",", { plain = true })) do
            selected[language] = true
        end
        local known = {}
        for _, sample in ipairs(require("flume.tweak_samples")) do
            known[sample.language] = true
        end
        for language in pairs(selected) do
            assert(known[language], "unknown preview language: " .. language)
        end
    end
    local count = 0
    for _, schema in ipairs(require("flume.palette").schema_order) do
        vim.cmd("FlumeTweak " .. schema)
        local windows = panes()
        vim.wo[windows.roles].cursorline = false
        vim.wo[windows.sample].cursorline = false
        local palette = require("flume.palette").get(schema).colors
        local role_line = locate(windows.roles_buffer, "syntax_string")
        for _, sample in ipairs(require("flume.tweak_samples")) do
            if not selected or selected[sample.language] then
                local parser = assert(
                    vim.treesitter.get_parser(windows.sample_buffer, sample.language),
                    sample.name .. " needs a parser"
                )
                local tree = assert(parser:parse()[1], sample.name .. " did not parse")
                assert(not tree:root():has_error(), sample.name .. " has a parser error")
                assert(
                    vim.treesitter.highlighter.active[windows.sample_buffer],
                    sample.name .. " has no active highlighter"
                )
                local row, column = locate(windows.sample_buffer, tokens[sample.name])
                vim.api.nvim_set_current_win(windows.sample)
                vim.api.nvim_win_set_cursor(windows.sample, { row, column })
                vim.cmd("normal! zz")
                -- Screen attribute ids are not highlight-group ids. Compare actual
                -- cells with a swatch whose RGB is checked independently below.
                local function matches_swatch()
                    vim.cmd("redraw!")
                    local text = screen_attribute(windows.sample, row, column)
                    local swatch = screen_attribute(windows.roles, role_line, 0)
                    return text > 0 and text == swatch
                end
                assert(
                    vim.wait(1000, matches_swatch, 10),
                    schema .. "/" .. sample.name .. " did not render the string swatch ink"
                )
                assert(
                    vim.api.nvim_get_hl(namespace, { name = "FlumeTweakSwatch_syntax_string", link = false }).fg
                        == tonumber(palette.syntax_string:sub(2), 16),
                    "swatch RGB disagrees with the palette"
                )
                vim.api.nvim_win_set_cursor(windows.roles, { role_line, 0 })
                local input = vim.ui.input
                vim.ui.input = function(_, done)
                    done("#123456")
                end
                press(windows.roles, "<CR>")
                vim.ui.input = input
                assert(vim.wait(1000, matches_swatch, 10), sample.name .. " did not recolor live")
                assert(
                    vim.api.nvim_get_hl(namespace, { name = "FlumeTweakSwatch_syntax_string", link = false }).fg
                        == 0x123456,
                    "candidate RGB was not applied"
                )
                assert(
                    vim.api.nvim_get_hl(0, { name = "@string", link = false }).fg == 0x010203,
                    "global namespace changed"
                )
                assert(
                    vim.deep_equal(config, flume.config) and vim.deep_equal(colors, flume.colors),
                    "editor state changed"
                )
                vim.fn.writefile({
                    vim.json.encode({ version = 1, schema = schema, colors = { syntax_string = "#654321" } }),
                }, draft_path)
                vim.cmd("FlumeTweakImport! " .. vim.fn.fnameescape(draft_path))
                assert(vim.wait(1000, matches_swatch, 10), sample.name .. " did not render imported ink")
                assert(
                    vim.api.nvim_get_hl(namespace, { name = "FlumeTweakSwatch_syntax_string", link = false }).fg
                        == 0x654321,
                    "imported RGB was not applied"
                )
                assert(
                    vim.deep_equal(config, flume.config)
                        and vim.deep_equal(colors, flume.colors)
                        and vim.api.nvim_get_hl(0, { name = "@string", link = false }).fg == 0x010203,
                    "import changed the editor theme"
                )
                press(windows.roles, "r")
                count = count + 1
            end
            press(windows.roles, "s")
        end
        press(windows.roles, "q")
    end
    print("PASS: " .. count .. " real parser previews, rendered edits and JSON imports; global theme unchanged")
end, debug.traceback)
vim.fn.delete(draft_path)
if not ok then
    print(failure)
    vim.cmd("cquit 1")
else
    vim.cmd("qa!")
end
