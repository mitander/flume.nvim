-- Native gopls lane: observe real generic-parameter tokens independently of
-- Tree-sitter. Requires an installed gopls and Go, and changes only private state.
local workspace, client
local function check()
    vim.opt.runtimepath:prepend(vim.fn.getcwd())
    assert(vim.fn.exepath("gopls") ~= "", "Install gopls before running the semantic-token check")
    assert(vim.fn.exepath("go") ~= "", "Install Go before running the semantic-token check")
    workspace = vim.fn.tempname()
    assert(vim.fn.mkdir(workspace, "", 448) == 1, "Semantic-token check requires a fresh private workspace")
    local lines = {
        "package fixture",
        "type Box[T any] struct { Value T }",
        "func Read[T any](box Box[T]) T { return box.Value }",
        "func Use() { box := Box[int]{Value: 1}; _ = Read(box); _ = NewCount() }",
        "func NewCount() int { return 1 }",
    }
    vim.fn.writefile({ "module flume.fixture", "", "go 1.22" }, workspace .. "/go.mod")
    vim.fn.writefile(lines, workspace .. "/fixture.go")
    vim.cmd.edit(workspace .. "/fixture.go")
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].filetype = "go"
    vim.diagnostic.enable(false, { bufnr = buf })
    local flume = require("flume")
    flume.setup({ schema = "dusk", watch_sync = false })
    local client_id = assert(vim.lsp.start({
        name = "gopls",
        cmd = { "gopls" },
        root_dir = workspace,
        settings = { gopls = { semanticTokens = true } },
        cmd_env = {
            HOME = workspace,
            GOPATH = workspace .. "/gopath",
            GOCACHE = workspace .. "/cache",
            GOENV = "off",
            GOWORK = "off",
            GOPROXY = "off",
            GOSUMDB = "off",
            GOTOOLCHAIN = "local",
        },
    }, { bufnr = buf }))
    client = assert(vim.lsp.get_client_by_id(client_id))
    -- Field tokens vary across gopls versions (variable versus property). The
    -- parser lane checks their role, and broad LSP variables defer to it.
    local probes = {
        { 2, "Box", "type", "syntax_type" },
        { 2, "T", "typeParameter", "syntax_primary" },
        { 2, "T }", "typeParameter", "syntax_primary" },
        { 3, "Read", "function", "syntax_function" },
        { 3, "T", "typeParameter", "syntax_primary" },
        { 3, "box", "parameter", "syntax_primary" },
        { 3, "T])", "typeParameter", "syntax_primary" },
        { 3, "T {", "typeParameter", "syntax_primary" },
        { 4, "Box", "type", "syntax_type" },
        { 4, "1", "number", "syntax_boolean" },
        { 4, "NewCount", "function", "syntax_function" },
        { 5, "NewCount", "function", "syntax_function" },
    }
    local palette = require("flume.palette")
    for _, schema in ipairs(palette.schema_order) do
        flume.setup({ schema = schema, watch_sync = false })
        local observed = {}
        assert(
            vim.wait(30000, function()
                for index, probe in ipairs(probes) do
                    local row = probe[1] - 1
                    local col = assert(lines[probe[1]]:find(probe[2], 1, true)) - 1
                    for _, token in ipairs(vim.lsp.semantic_tokens.get_at_pos(buf, row, col) or {}) do
                        if token.client_id == client_id and token.type == probe[3] then
                            observed[index] = token
                        end
                    end
                    if not observed[index] then
                        return false
                    end
                end
                return true
            end, 50),
            schema .. " gopls did not emit the expected declaration/use tokens"
        )
        for _, probe in ipairs(probes) do
            local group = "@lsp.type." .. probe[3] .. ".go"
            local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
            local expected = tonumber(palette.get(schema).colors[probe[4]]:sub(2), 16)
            assert(highlight.fg == expected, schema .. " " .. group .. " has the wrong role color")
        end
        print("ok - gopls generic declarations, references and control roles: " .. schema)
    end
    print(#probes * #palette.schema_order .. " real semantic-token checks passed")
end

local ok, err = xpcall(check, debug.traceback)
if client then
    client:stop(true)
    vim.wait(5000, function()
        return client:is_stopped()
    end, 50)
end
if workspace then
    vim.fn.delete(workspace, "rf")
end
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end
vim.cmd("qa!")
