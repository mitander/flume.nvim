-- Deterministic marketing fixture: valid Zig, no parser, LSP, Git state, or diagnostics.
local schema = vim.env.FLUME_SHOWCASE_SCHEMA or "dusk"
local ns = vim.api.nvim_create_namespace("flume-showcase")
local buf = vim.api.nvim_create_buf(true, false)
local lines = vim.fn.readfile("flume.zig")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
vim.api.nvim_buf_set_name(buf, "flume-" .. schema .. ".zig")
vim.api.nvim_set_current_buf(buf)
vim.bo[buf].buftype = "nofile"
vim.bo[buf].bufhidden = "wipe"
vim.bo[buf].swapfile = false
vim.bo[buf].modifiable = false
vim.wo.number = true
vim.wo.cursorline = true
vim.wo.signcolumn = "no"
vim.wo.wrap = false
vim.o.laststatus = 2
vim.o.showmode = false
vim.o.ruler = false
vim.o.statusline = "  NORMAL  %t%=line %l  col %c  "

local marked = {}

local function mark(line, text, group, occurrence)
    local source = lines[line]
    local from = 1
    local start_col
    for _ = 1, occurrence or 1 do
        start_col = source:find(text, from, true)
        assert(start_col, text)
        from = start_col + #text
    end

    local first = start_col - 1
    local last = first + #text
    marked[line] = marked[line] or {}
    for _, range in ipairs(marked[line]) do
        assert(last <= range.first or first >= range.last, "overlapping showcase highlights on line " .. line)
    end
    table.insert(marked[line], { first = first, last = last })

    vim.api.nvim_buf_set_extmark(buf, ns, line - 1, first, {
        end_col = last,
        hl_group = group,
    })
end

for _, spec in ipairs({
    { 1, "/// A tiny expression tree with constant folding.", "@comment.documentation" },
    { 2, "const", "@keyword" }, { 2, "std", "@variable" },
    { 2, "@import", "@function.builtin" }, { 2, '"std"', "@string" },
    { 4, "const", "@keyword" }, { 4, "Ast", "@type" },
    { 4, "union", "@keyword.type" }, { 4, "enum", "@keyword.type" },
    { 5, "num", "@property" }, { 5, "i64", "@type.builtin" },
    { 6, "ident", "@property" }, { 6, "u8", "@type.builtin" },
    { 7, "add", "@property" }, { 7, "struct", "@keyword.type" },
    { 7, "lhs", "@property" }, { 7, "Ast", "@type" },
    { 7, "rhs", "@property" }, { 7, "Ast", "@type", 2 },
    { 9, "// Fold constants; identifiers remain dynamic.", "@comment" },
    { 10, "fn", "@keyword.function" }, { 10, "fold", "@function" },
    { 10, "self", "@variable.parameter" }, { 10, "Ast", "@type" }, { 10, "i64", "@type.builtin" },
    { 11, "return", "@keyword.return" }, { 11, "switch", "@keyword.conditional" },
    { 12, ".num", "@constant" }, { 12, "n", "@variable.parameter", 2 },
    { 13, ".ident", "@constant" }, { 13, "null", "@constant.builtin" },
    { 14, ".add", "@constant" }, { 14, "a", "@variable.parameter", 2 }, { 14, "blk", "@label" },
    { 15, "const", "@keyword" }, { 15, "lhs", "@property" }, { 15, "fold", "@function.call" },
    { 15, "orelse", "@keyword" }, { 15, "break", "@keyword" }, { 15, "null", "@constant.builtin" },
    { 16, "const", "@keyword" }, { 16, "rhs", "@property" }, { 16, "fold", "@function.call" },
    { 16, "orelse", "@keyword" }, { 16, "break", "@keyword" }, { 16, "null", "@constant.builtin" },
    { 17, "break", "@keyword" }, { 17, "+", "@operator" },
    { 23, "pub", "@keyword.modifier" }, { 23, "fn", "@keyword.function" },
    { 23, "main", "@function" }, { 23, "void", "@type.builtin" },
    { 24, "// Build and evaluate 40 + 2.", "@comment" },
    { 25, "const", "@keyword" }, { 25, "Ast", "@type" }, { 25, ".num", "@property" }, { 25, "40", "@number" },
    { 26, "const", "@keyword" }, { 26, "Ast", "@type" }, { 26, ".num", "@property" }, { 26, "2", "@number" },
    { 27, "const", "@keyword" }, { 27, "Ast", "@type" }, { 27, ".add", "@property" },
    { 27, ".lhs", "@property" }, { 27, ".rhs", "@property" },
    { 28, "print", "@function.call" }, { 28, '"{s} folded = {}\\n"', "@string" },
    { 28, "@tagName", "@function.builtin" }, { 28, "fold", "@function.call", 2 },
}) do
    mark(spec[1], spec[2], spec[3], spec[4])
end

vim.api.nvim_win_set_cursor(0, { 17, 0 })
vim.cmd("redraw")
