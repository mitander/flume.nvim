-- Optional native-parser lane. Run from the repository root with a complete
-- FLUME_TS_RUNTIME (parser/ and queries/) or your normal Tree-sitter runtime.
local function check()
    vim.opt.runtimepath:prepend(vim.fn.getcwd())
    if vim.env.FLUME_TS_RUNTIME and vim.env.FLUME_TS_RUNTIME ~= "" then
        vim.opt.runtimepath:prepend(vim.env.FLUME_TS_RUNTIME)
    end
    local fixtures = {
        {
            "zig",
            "zig",
            {
                { "const std =", "std", "module", "syntax_namespace" },
                { "std.debug.print", "std", "variable", "syntax_primary" },
                { "std.debug.print", "debug", "variable.member", "syntax_property" },
                { "std.debug.print", "print", "function.call", "syntax_function" },
            },
        },
        {
            "rs",
            "rust",
            {
                { "struct Rejected<T>", "Rejected", "type", "syntax_type" },
                { "struct Rejected<T>", "T", "type", "syntax_type" },
                { "let payload =", "payload", "variable", "syntax_primary" },
                { "fn submit<T>", "submit", "function", "syntax_function" },
                { "&self.error", "error", "variable.member", "syntax_property" },
            },
        },
        {
            "py",
            "python",
            {
                { "class Pair:", "Pair", "type", "syntax_type" },
                { "def luminance", "luminance", "function", "syntax_function" },
                { "channels =", "channels", "variable", "syntax_primary" },
                { "for color in", "foreground", "variable.member", "syntax_property" },
                { "def ratio(self)", "ratio", "function", "syntax_function" },
            },
        },
        {
            "ts",
            "typescript",
            {
                { "class Selection<T", "Selection", "type", "syntax_type" },
                { "const picker =", "picker", "variable", "syntax_primary" },
                { "this.items.filter", "filter", "function.method.call", "syntax_function" },
                { "return this.visible[this.index]", "index", "variable.member", "syntax_property" },
            },
        },
        {
            "tsx",
            "tsx",
            {
                { "const value =", "value", "variable", "syntax_primary" },
                { "export const demo", "UndoCounter", "tag", "syntax_special" },
                { "<section aria", "section", "tag.builtin", "syntax_special" },
            },
        },
        {
            "go",
            "go",
            {
                { "type Queue[T", "Queue", "type", "syntax_type" },
                { "func NewQueue[T", "NewQueue", "function", "syntax_function" },
                { "queue := NewQueue", "queue", "variable", "syntax_primary" },
                { "q.items = nil", "items", "property", "syntax_property" },
                { "fmt.Printf", "Printf", "function.method.call", "syntax_function" },
            },
        },
        {
            "ex",
            "elixir",
            {
                { "defmodule Log", "Log", "module", "syntax_namespace" },
                { "lines =", "lines", "variable", "syntax_primary" },
                { "Enum.frequencies", "frequencies", "function.call", "syntax_function" },
            },
        },
        {
            "Go factory calls and named types",
            "go",
            {
                { "first := NewCount()", "NewCount", "constructor", "syntax_function" },
                { "second := MakeCount()", "MakeCount", "constructor", "syntax_function" },
                { "box := Box{", "Box", "type", "syntax_type" },
                { "box := Box{", "Value", "variable.member", "syntax_property" },
            },
            source = {
                "package fixture",
                "type Box struct { Value int }",
                "func NewCount() int { return 1 }",
                "func MakeCount() int { return 2 }",
                "func Use() {",
                "    first := NewCount()",
                "    second := MakeCount()",
                "    box := Box{Value: first + second}",
                "    _ = box",
                "}",
            },
        },
        {
            "Rust receivers and parser-only generics",
            "rust",
            {
                { "fn read(&self)", "self", "variable.builtin", "syntax_primary" },
                { "&self.value", "self", "variable.builtin", "syntax_primary" },
                { "&self.value", "value", "variable.member", "syntax_property" },
                { "struct Box<T>", "T", "type", "syntax_type" },
                { "value: T", "T", "type", "syntax_type" },
                { "use self::", "self", "module", "syntax_namespace" },
                { "const READY", "READY", "constant", "syntax_constant" },
                { "const READY", "true", "boolean", "syntax_boolean" },
            },
            source = {
                "struct Box<T> { value: T }",
                "impl<T> Box<T> {",
                "    fn read(&self) -> &T { &self.value }",
                "}",
                "mod support { pub const READY: bool = true; }",
                "use self::support::READY;",
            },
        },
        {
            "Python receivers and literals",
            "python",
            {
                { "def read(self)", "self", "variable.builtin", "syntax_primary" },
                { "return self.value", "self", "variable.builtin", "syntax_primary" },
                { "return self.value", "value", "variable.member", "syntax_property" },
                { "def build(cls)", "cls", "variable.builtin", "syntax_primary" },
                { "return cls()", "cls", "function.call", "syntax_function" },
                { "enabled = True", "True", "boolean", "syntax_boolean" },
                { "missing = None", "None", "constant.builtin", "syntax_boolean" },
            },
            source = {
                "class Box:",
                "    def read(self):",
                "        return self.value",
                "    @classmethod",
                "    def build(cls):",
                "        return cls()",
                "enabled = True",
                "missing = None",
            },
        },
        {
            "Lua receiver and table roles",
            "lua",
            {
                { "return self.value", "self", "variable.builtin", "syntax_primary" },
                { "return self.value", "value", "variable.member", "syntax_property" },
                { "function box:read()", "read", "function.method", "syntax_function" },
                { "local box =", "self", "property", "syntax_property" },
                { "local box =", "true", "boolean", "syntax_boolean" },
            },
            source = {
                "local box = { self = true, value = 1 }",
                "function box:read() return self.value end",
            },
        },
    }
    for _, language in ipairs({ "typescript", "tsx" }) do
        fixtures[#fixtures + 1] = {
            language .. " receivers, constructors and bindings",
            language,
            {
                { "return this.value", "this", "variable.builtin", "syntax_primary" },
                { "return this.value", "value", "variable.member", "syntax_property" },
                { "new Box()", "Box", "constructor", "syntax_type" },
                { "const { value }", "value", "variable", "syntax_primary" },
                { "const copy =", "value", "variable.member", "syntax_property" },
                { "const enabled", "true", "boolean", "syntax_boolean" },
                { "const missing", "undefined", "constant.builtin", "syntax_boolean" },
                { "type Holder<T>", "T", "type", "syntax_type" },
            },
            source = {
                "class Box { value = 1; read() { return this.value; } }",
                "const box = new Box();",
                "const { value } = box;",
                "const copy = { value };",
                "const enabled = true;",
                "const missing = undefined;",
                "type Holder<T> = { item: T };",
            },
        }
    end
    local palette = require("flume.palette")
    local count = 0
    for _, fixture in ipairs(fixtures) do
        local path = fixture.source and fixture[1] or "examples/flume." .. fixture[1]
        local language = fixture[2]
        local lines = fixture.source or vim.fn.readfile(path)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].filetype = language
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

                local has_expected_capture, foreground, foreground_priority = false, nil, -1
                for _, capture in ipairs(vim.treesitter.get_captures_at_pos(buf, row, col)) do
                    has_expected_capture = has_expected_capture or capture.capture == probe[3]
                    local highlight =
                        vim.api.nvim_get_hl(0, { name = "@" .. capture.capture .. "." .. language, link = false })
                    local metadata = capture.metadata
                    local capture_priority = tonumber(metadata.priority or (metadata[capture.id] or {}).priority) or 100
                    if highlight.fg and capture_priority >= foreground_priority then
                        foreground, foreground_priority = highlight.fg, capture_priority
                    end
                end

                assert(has_expected_capture, path .. " " .. probe[2] .. " did not receive @" .. probe[3])
                local expected = tonumber(palette.get(schema).colors[probe[4]]:sub(2), 16)
                assert(foreground == expected, schema .. " " .. path .. " " .. probe[2] .. " has the wrong role color")
                count = count + 1
            end
        end
        print("ok - real " .. language .. " captures in all four palettes: " .. path)
        vim.api.nvim_buf_delete(buf, { force = true })
    end
    print(count .. " real-parser highlight checks passed")
end

local ok, err = xpcall(check, debug.traceback)
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
end
vim.cmd("qa!")
