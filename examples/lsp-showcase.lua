-- Attach a real server to an isolated copy of the canonical source.
local language = assert(vim.env.FLUME_SHOWCASE_LANGUAGE)
local servers = {
    go = { name = "gopls", cmd = { "gopls" }, version = { "gopls", "version" },
        settings = { gopls = { semanticTokens = true } }, extension = "go" },
    zig = { name = "zls", cmd = { "zls" }, version = { "zls", "--version" }, extension = "zig" },
}
local server = assert(servers[language], "LSP fixture supports Go and Zig")
local metadata_path = vim.env.FLUME_SHOWCASE_METADATA
-- The parser-only fixture must not signal readiness before the server responds.
vim.env.FLUME_SHOWCASE_METADATA = nil
dofile("showcase.lua")
vim.env.FLUME_SHOWCASE_METADATA = metadata_path
local buf = vim.api.nvim_get_current_buf()
-- ZLS hover links include this path; random/UID-dependent paths change float width.
-- Capture runs in a private container. Manual examples still use unique workspaces.
local workspace = metadata_path and ("/tmp/flume-lsp-" .. language) or vim.fn.tempname()
assert(vim.fn.mkdir(workspace, "", 448) == 1, "LSP fixture requires a fresh private workspace")
local file = workspace .. "/main." .. server.extension
vim.fn.writefile(vim.api.nvim_buf_get_lines(buf, 0, -1, false), file)
if language == "go" then
    vim.fn.writefile({ "module flume.fixture", "", "go 1.22" }, workspace .. "/go.mod")
end
vim.bo[buf].buftype = ""
vim.api.nvim_buf_set_name(buf, file)
vim.wo.statusline = "  Tree-sitter + " .. server.name .. "  %t%=%l:%c  "
vim.diagnostic.enable(false, { bufnr = buf })
vim.api.nvim_create_autocmd("VimLeavePre", { once = true, callback = function()
    vim.fn.delete(workspace, "rf")
end })
local executable = vim.fn.exepath(server.cmd[1])
assert(executable ~= "", "Install " .. server.name)
local version = vim.fn.system(server.version)
assert(vim.v.shell_error == 0, "Cannot identify " .. server.name .. " version")
local client_id = assert(vim.lsp.start({
    name = server.name, cmd = server.cmd, root_dir = workspace, settings = server.settings,
}, { bufnr = buf }))

local tokens = {}
assert(vim.wait(45000, function()
    local client = vim.lsp.get_client_by_id(client_id)
    if not client or not client.initialized then return false end
    for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        for col = 0, #line - 1 do
            for _, token in ipairs(vim.lsp.semantic_tokens.get_at_pos(buf, row - 1, col) or {}) do
                tokens[token.line .. ":" .. token.start_col] = token
            end
        end
    end
    return next(tokens) ~= nil
end, 100), "Server must attach and render semantic tokens")
-- Show a useful server result, not only the subtle semantic-token differences.
local target = language == "go" and "Count(" or "fold("
local hover_row, hover_col
for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local col = line:find(target, 1, true)
    if col then hover_row, hover_col = row, col - 1 end
end
assert(hover_row, "LSP specimen must contain the hover target")
vim.api.nvim_win_set_cursor(0, { hover_row, hover_col })
local client = assert(vim.lsp.get_client_by_id(client_id))
local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
local response = assert(client:request_sync("textDocument/hover", params, 10000, buf), "Server must answer hover")
assert(response.result and response.result.contents, "Server must return hover documentation")
local hover = vim.lsp.util.convert_input_to_markdown_lines(response.result.contents)
assert(#hover > 0, "Hover must contain a signature or documentation")
local function show_hover()
    -- Opening before VimEnter lets startup cursor events close the float again.
    vim.o.laststatus = 2
    vim.lsp.util.open_floating_preview(hover, "markdown", {
        border = "single", max_width = 64, max_height = 10, focusable = false,
        close_events = {},
    })
    vim.cmd("redraw")
    if metadata_path then
        local counts = {}
        for _, token in pairs(tokens) do
            counts[token.type] = (counts[token.type] or 0) + 1
        end
        vim.fn.writefile({ vim.json.encode({
            nvim = tostring(vim.version()), language = language, kind = "lsp", hover = hover,
            workspace = workspace,
            parser = assert(vim.api.nvim_get_runtime_file("parser/" .. language .. ".*", false)[1]),
            queries = vim.treesitter.query.get_files(language, "highlights"),
            server = { name = server.name, version = vim.trim(version), executable = executable,
                settings = server.settings or {}, token_counts = counts },
        }) }, metadata_path)
    end
end
vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = function()
    vim.schedule(show_hover)
end })
