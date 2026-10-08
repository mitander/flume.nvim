-- Real diff, synthetic diagnostic severities, search, and Visual selection.
local schema = assert(vim.env.FLUME_SHOWCASE_SCHEMA)
local kind = assert(vim.env.FLUME_CAPTURE_KIND)
assert(kind == "selection")
if vim.env.FLUME_TS_RUNTIME and vim.env.FLUME_TS_RUNTIME ~= "" then
    vim.opt.runtimepath:prepend(vim.env.FLUME_TS_RUNTIME)
end
vim.opt.termguicolors = true
if not vim.env.FLUME_CAPTURE_KIND then vim.o.laststatus = 2 end
vim.o.splitright = true
vim.o.showmode = false
vim.o.showcmd = false
vim.o.ruler = false
vim.o.diffopt = "internal,filler,closeoff,linematch:60"
vim.o.completeopt = "menuone,noinsert"
vim.o.pumheight = 6
vim.o.hlsearch = true
vim.fn.setreg("/", "greeting")
vim.v.hlsearch = 1

local source = vim.fn.readfile("states.go")
local function open_buffer(name, lines)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_name(buf, name .. ".go")
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "go"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.wo.number = true
    vim.wo.cursorline = true
    vim.wo.wrap = false
    vim.wo.signcolumn = "yes"
    vim.wo.statusline = "  " .. name .. "  %=%l:%c  "
    vim.treesitter.start(buf, "go")
    return buf
end

open_buffer("before", source)
vim.cmd("diffthis")
vim.wo.signcolumn = "no"
vim.wo.foldcolumn = "0"
local before_win = vim.api.nvim_get_current_win()
vim.cmd("vsplit")
local changed = vim.deepcopy(source)
changed[6] = "func greeting(user string) string {"
changed[7] = '    return fmt.Sprintf("Welcome, %s", user)'
open_buffer("after", changed)
vim.cmd("diffthis")
vim.wo.signcolumn = "no"
vim.wo.foldcolumn = "0"
local after_win = vim.api.nvim_get_current_win()
vim.cmd("diffupdate")
assert(vim.fn.diff_hlID(7, 26) == vim.fn.hlID("DiffText"), "Changed word must use DiffText")
vim.cmd("botright split")
local buf = open_buffer("working states", source)
vim.cmd("diffoff")
vim.wo.foldcolumn = "0"
vim.cmd("resize 20")
local ns = vim.api.nvim_create_namespace("FlumeStateFixture")
vim.diagnostic.config({
    virtual_text = { prefix = "●" }, underline = true,
    signs = { text = { [1] = "E", [2] = "W", [3] = "I", [4] = "H" } },
})
vim.diagnostic.set(ns, buf, {
    { lnum = 5, col = 14, end_col = 18, severity = 1, message = "Fixture error: check name" },
    { lnum = 6, col = 11, end_col = 14, severity = 2, message = "Fixture warning: review format" },
    { lnum = 10, col = 4, end_col = 8, severity = 3, message = "Fixture info: local binding" },
    { lnum = 11, col = 16, end_col = 24, severity = 4, message = "Fixture hint: function call" },
})

local function report()
    vim.cmd("redraw")
    if vim.env.FLUME_SHOWCASE_METADATA then
        vim.fn.writefile({ vim.json.encode({
            nvim = tostring(vim.version()), language = "go", kind = kind,
            parser = assert(vim.api.nvim_get_runtime_file("parser/go.*", false)[1]),
            queries = vim.treesitter.query.get_files("go", "highlights"),
            diff_text = true, diagnostics = #vim.diagnostic.get(buf),
            visual = vim.fn.mode() == "V", completion = vim.fn.pumvisible() == 1,
        }) }, vim.env.FLUME_SHOWCASE_METADATA)
    end
end

vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = function()
    vim.schedule(function()
        for _, view in ipairs({ { before_win, source }, { after_win, changed } }) do
            local available = vim.api.nvim_win_get_width(view[1]) - vim.fn.getwininfo(view[1])[1].textoff
            for _, line in ipairs(view[2]) do
                assert(vim.fn.strdisplaywidth(line) <= available, "Diff specimen must fit its pane without clipping")
            end
        end
        vim.api.nvim_win_set_cursor(0, { 5, 0 })
        vim.cmd("normal! Vj")
        report()
    end)
end })
