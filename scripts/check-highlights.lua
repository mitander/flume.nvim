-- Optional native-parser lane. Run from the repository root with a complete
-- FLUME_TS_RUNTIME (parser/ and queries/) or your normal Tree-sitter runtime.
local function check()
    vim.opt.runtimepath:prepend(vim.fn.getcwd())
    if vim.env.FLUME_TS_RUNTIME and vim.env.FLUME_TS_RUNTIME ~= "" then
        vim.opt.runtimepath:prepend(vim.env.FLUME_TS_RUNTIME)
    end
    local fixtures = {
        { "zig", "zig", {
            { "const std =", "std", "module", "syntax_namespace" },
            { "std.debug.print", "std", "variable", "syntax_primary" },
            { "std.debug.print", "debug", "variable.member", "syntax_property" },
            { "std.debug.print", "print", "function.call", "syntax_function" },
        } },
        { "rs", "rust", {
            { "struct Door", "Door", "type", "syntax_type" },
            { "let door = Door", "door", "variable", "syntax_primary" },
            { "const KEY", "KEY", "constant", "syntax_constant" },
            { "fn unlock", "unlock", "function", "syntax_function" },
        } },
        { "py", "python", {
            { "def count_events", "count_events", "function", "syntax_function" },
            { "counts: Counter", "counts", "variable", "syntax_primary" },
            { "counts: Counter", "Counter", "type", "syntax_type" },
            { "args.limit <", "limit", "variable.member", "syntax_property" },
            { "counts.most_common", "most_common", "function.method.call", "syntax_function" },
        } },
        { "ts", "typescript", {
            { "const expr:", "expr", "variable", "syntax_primary" },
            { "export function fold", "fold", "function", "syntax_function" },
            { "return expr.value", "value", "variable.member", "syntax_property" },
        } },
        { "tsx", "tsx", {
            { "const value =", "value", "variable", "syntax_primary" },
            { "export const demo", "UndoCounter", "tag", "syntax_constant" },
            { "<section aria", "section", "tag.builtin", "syntax_special" },
        } },
        { "go", "go", {
            { "func Count", "Count", "function", "syntax_function" },
            { "values :=", "values", "variable", "syntax_primary" },
            { "context.Context", "Context", "type", "syntax_type" },
            { "fmt.Printf", "Printf", "function.method.call", "syntax_function" },
        } },
        { "ex", "elixir", {
            { "defmodule Log", "Log", "module", "syntax_namespace" },
            { "lines =", "lines", "variable", "syntax_primary" },
            { "Enum.frequencies", "frequencies", "function.call", "syntax_function" },
        } },
    }
    local palette = require("flume.palette")
    local count = 0
    for _, fixture in ipairs(fixtures) do
        local path, language = "examples/flume." .. fixture[1], fixture[2]
        vim.cmd.edit(path)
        local buf = vim.api.nvim_get_current_buf()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        vim.treesitter.start(buf, language)
        assert(not vim.treesitter.get_parser(buf, language):parse()[1]:root():has_error(), path .. " has parse errors")
        for _, schema in ipairs(palette.schema_order) do
            require("flume").setup({ schema = schema, watch_sync = false })
            for _, probe in ipairs(fixture[3]) do
                local row, col
                for index, line in ipairs(lines) do
                    if line:find(probe[1], 1, true) then
                        row, col = index - 1, assert(line:find(probe[2], 1, true)) - 1
                        break
                    end
                end
                assert(row, path .. " is missing " .. probe[1])
                local found, foreground, priority = false, nil, -1
                for _, capture in ipairs(vim.treesitter.get_captures_at_pos(buf, row, col)) do
                    found = found or capture.capture == probe[3]
                    local hl = vim.api.nvim_get_hl(0, { name = "@" .. capture.capture .. "." .. language, link = false })
                    local metadata = capture.metadata
                    local rank = tonumber(metadata.priority or (metadata[capture.id] or {}).priority) or 100
                    if hl.fg and rank >= priority then
                        foreground, priority = hl.fg, rank
                    end
                end
                assert(found, path .. " " .. probe[2] .. " did not receive @" .. probe[3])
                local expected = tonumber(palette.get(schema).colors[probe[4]]:sub(2), 16)
                assert(foreground == expected, schema .. " " .. path .. " " .. probe[2] .. " has the wrong role color")
                count = count + 1
            end
        end
        print("ok - real " .. language .. " captures in all four palettes")
    end
    print(count .. " real-parser highlight checks passed")
end

local ok, err = xpcall(check, debug.traceback)
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end
vim.cmd("qa!")
