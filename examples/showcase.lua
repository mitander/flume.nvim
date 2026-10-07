-- Real Tree-sitter highlighting, without a language server.
local schema = vim.env.FLUME_SHOWCASE_SCHEMA or "dusk"
local language = vim.env.FLUME_SHOWCASE_LANGUAGE or "zig"
local extensions = {
    zig = "zig", rust = "rs", tsx = "tsx", python = "py", go = "go",
    elixir = "ex", toml = "toml",
}
local extension = assert(extensions[language], "Unsupported capture language: " .. language)
vim.opt.termguicolors = true
if vim.env.FLUME_TS_RUNTIME and vim.env.FLUME_TS_RUNTIME ~= "" then
    vim.opt.runtimepath:prepend(vim.env.FLUME_TS_RUNTIME)
end

local buf = vim.api.nvim_create_buf(true, false)
local lines = vim.fn.readfile("flume." .. extension)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
vim.api.nvim_buf_set_name(buf, "flume-" .. schema .. "." .. extension)
vim.api.nvim_set_current_buf(buf)
vim.bo[buf].filetype = language == "tsx" and "typescriptreact" or language
vim.bo[buf].buftype = "nofile"
vim.bo[buf].bufhidden = "wipe"
vim.bo[buf].swapfile = false
vim.bo[buf].modifiable = false
vim.wo.number = true
vim.wo.cursorline = true
vim.wo.signcolumn = "no"
vim.wo.wrap = false
if not vim.env.FLUME_CAPTURE_KIND then vim.o.laststatus = 2 end
vim.o.showmode = false
vim.o.ruler = false
vim.o.statusline = "  NORMAL  %t%=%l:%c  "

local parser = vim.treesitter.get_parser(buf, language)
assert(not parser:parse()[1]:root():has_error(), language .. " capture fixture contains a parse error")
local query_files = vim.treesitter.query.get_files(language, "highlights")
assert(#query_files > 0, "Install " .. language .. " highlight queries or set FLUME_TS_RUNTIME")
vim.treesitter.start(buf, language)
-- Park the block cursor on whitespace so the specimen text stays readable.
local cursor_line = math.min(17, #lines)
local cursor_column = (lines[cursor_line]:find("%s") or 1) - 1
vim.api.nvim_win_set_cursor(0, { cursor_line, cursor_column })
vim.cmd("redraw")

if vim.env.FLUME_SHOWCASE_METADATA then
    local metadata = {
        nvim = tostring(vim.version()),
        language = language,
        parser = assert(vim.api.nvim_get_runtime_file("parser/" .. language .. ".*", false)[1]),
        queries = query_files,
    }
    vim.fn.writefile({ vim.json.encode(metadata) }, vim.env.FLUME_SHOWCASE_METADATA)
end
