local failures = {}
local passed = 0

local function test(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
        passed = passed + 1
        print("ok - " .. name)
    else
        failures[#failures + 1] = { name = name, err = err }
        print("not ok - " .. name)
    end
end

local function equal(actual, expected, message)
    if actual ~= expected then
        error(
            (message or "values differ") .. ": expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual),
            2
        )
    end
end

local function truthy(value, message)
    if not value then
        error(message or "expected a truthy value", 2)
    end
end

local function color_number(hex)
    return tonumber(hex:sub(2), 16)
end

local function luminance(hex)
    local function channel(offset)
        local value = tonumber(hex:sub(offset, offset + 1), 16) / 255
        return value <= 0.04045 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
    end
    return 0.2126 * channel(2) + 0.7152 * channel(4) + 0.0722 * channel(6)
end

local function contrast(a, b)
    local lighter = math.max(luminance(a), luminance(b))
    local darker = math.min(luminance(a), luminance(b))
    return (lighter + 0.05) / (darker + 0.05)
end

vim.opt.termguicolors = true
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local palette = require("flume.palette").colors

local required_roles = {
    "bg",
    "fg",
    "text",
    "on_accent",
    "error",
    "warning",
    "success",
    "info",
    "match",
    "diff_add",
    "diff_change",
    "diff_delete",
    "syntax_primary",
    "syntax_comment",
    "syntax_function",
    "syntax_keyword",
    "syntax_namespace",
    "syntax_string",
    "syntax_type",
}

test("palette has valid explicit colors", function()
    for key, value in pairs(palette) do
        truthy(type(value) == "string" and value:match("^#%x%x%x%x%x%x$"), key .. " is not #RRGGBB")
    end
    for _, key in ipairs(required_roles) do
        truthy(palette[key], "missing required palette role " .. key)
    end
end)

test("primary and filled text meet contrast contracts", function()
    truthy(contrast(palette.syntax_primary, palette.bg) >= 4.5, "Normal text contrast is below 4.5:1")
    truthy(contrast(palette.on_accent, palette.accent) >= 4.5, "accent text contrast is below 4.5:1")
    truthy(contrast(palette.on_accent, palette.match) >= 4.5, "match text contrast is below 4.5:1")
end)

test("colorscheme clears highlights from the previous theme", function()
    vim.api.nvim_set_hl(0, "FlumeLeakProbe", { fg = "#ff0000", bg = "#00ff00" })
    vim.cmd.colorscheme("flume")
    local probe = vim.api.nvim_get_hl(0, { name = "FlumeLeakProbe", link = false })
    equal(next(probe), nil, "custom highlight leaked from the previous theme")
end)

test("dark theme resolves canonical Normal and Search colors", function()
    require("flume").setup({})
    local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    local search = vim.api.nvim_get_hl(0, { name = "Search", link = false })
    equal(normal.fg, color_number(palette.syntax_primary), "Normal foreground")
    equal(normal.bg, color_number(palette.bg), "Normal background")
    equal(search.fg, color_number(palette.on_accent), "Search foreground")
    equal(search.bg, color_number(palette.accent), "Search background")
    equal(vim.o.background, "dark", "background option")
    equal(vim.g.colors_name, "flume", "colorscheme name")
end)

test("setup starts from defaults on every call", function()
    local flume = require("flume")
    flume.setup({ overrides = { syntax_comment = "#abcdef" } })
    equal(vim.api.nvim_get_hl(0, { name = "Comment", link = false }).fg, 0xabcdef)
    flume.setup({})
    equal(vim.api.nvim_get_hl(0, { name = "Comment", link = false }).fg, color_number(palette.syntax_comment))
end)

test("transparent mode keeps inverse text and clears the primary background", function()
    require("flume").setup({ transparent = true })
    local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    local header = vim.api.nvim_get_hl(0, { name = "LazyH1", link = false })
    equal(normal.bg, nil, "transparent Normal background")
    equal(header.fg, color_number(palette.on_accent), "filled header foreground")
    equal(header.bg, color_number(palette.accent), "filled header background")
end)

test("semantic states can be overridden independently from ANSI colors", function()
    require("flume").setup({
        overrides = { error = "#abcdef", red = "#123456" },
    })
    equal(vim.api.nvim_get_hl(0, { name = "DiagnosticError", link = false }).fg, 0xabcdef)
    equal(vim.g.terminal_color_1, "#123456")
end)

test("terminal colors can be disabled after being enabled", function()
    local flume = require("flume")
    flume.setup({ terminal_colors = true })
    equal(vim.g.terminal_color_0, palette.black)
    flume.setup({ terminal_colors = false })
    equal(vim.g.terminal_color_0, nil)
    equal(vim.g.terminal_color_15, nil)
end)

test("styles and exact highlight overrides are applied last", function()
    require("flume").setup({
        styles = { comments = { italic = true } },
        highlights = {
            Comment = { fg = "#abcdef", bold = true },
            ["@comment"] = function(colors)
                return { fg = colors.syntax_comment, underline = true }
            end,
            ["@constructor.lua"] = { fg = "#fedcba" },
        },
    })
    local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
    local capture = vim.api.nvim_get_hl(0, { name = "@comment", link = false })
    local language_capture = vim.api.nvim_get_hl(0, { name = "@constructor.lua", link = false })
    equal(comment.fg, 0xabcdef)
    equal(comment.bold, true)
    equal(capture.fg, color_number(palette.syntax_comment))
    equal(capture.underline, true)
    equal(language_capture.fg, 0xfedcba)
end)

test("syntax roles stay consistent across language providers", function()
    require("flume").setup({ styles = { types = { bold = true } } })

    local constructor = vim.api.nvim_get_hl(0, { name = "@constructor", link = false })
    equal(constructor.fg, color_number(palette.syntax_type), "constructor foreground")
    equal(constructor.bold, true, "constructor type style")

    local enum_member = vim.api.nvim_get_hl(0, { name = "@lsp.type.enumMember", link = false })
    equal(enum_member.fg, color_number(palette.syntax_constant), "generic enum member foreground")

    local rust_variant = vim.api.nvim_get_hl(0, { name = "@lsp.type.enumMember.rust", link = false })
    equal(rust_variant.fg, color_number(palette.syntax_type), "Rust constructor foreground")
    equal(rust_variant.bold, true, "Rust constructor type style")

    local lua_constructor = vim.api.nvim_get_hl(0, { name = "@constructor.lua", link = false })
    equal(lua_constructor.fg, color_number(palette.syntax_punctuation_bracket), "Lua constructor foreground")

    local python_namespace = vim.api.nvim_get_hl(0, { name = "@lsp.type.namespace.python", link = false })
    equal(next(python_namespace), nil, "Python namespace defers to Tree-sitter")

    local lsp_variable = vim.api.nvim_get_hl(0, { name = "@lsp.type.variable", link = false })
    equal(next(lsp_variable), nil, "generic LSP variable defers to Tree-sitter")

    local lsp_decorator = vim.api.nvim_get_hl(0, { name = "@lsp.type.decorator", link = false })
    equal(lsp_decorator.fg, color_number(palette.syntax_attribute), "decorator foreground")

    local readonly_variable = vim.api.nvim_get_hl(0, { name = "@lsp.typemod.variable.readonly", link = false })
    equal(readonly_variable.fg, color_number(palette.syntax_constant), "readonly variable foreground")
    local readonly_property = vim.api.nvim_get_hl(0, { name = "@lsp.typemod.property.readonly", link = false })
    equal(readonly_property.fg, color_number(palette.syntax_constant), "readonly property foreground")

    local tsx_constructor = vim.api.nvim_get_hl(0, { name = "@constructor.tsx", link = false })
    equal(tsx_constructor.fg, color_number(palette.syntax_constant), "TSX constructor foreground")

    local namespace = vim.api.nvim_get_hl(0, { name = "@lsp.type.namespace", link = false })
    equal(namespace.fg, color_number(palette.syntax_namespace), "generic namespace foreground")
    local zig_namespace = vim.api.nvim_get_hl(0, { name = "@lsp.type.namespace.zig", link = false })
    equal(next(zig_namespace), nil, "Zig namespace exception")

    equal(
        vim.api.nvim_get_hl(0, { name = "@keyword.import", link = false }).fg,
        color_number(palette.syntax_namespace),
        "import keyword foreground"
    )
    equal(
        vim.api.nvim_get_hl(0, { name = "@keyword.operator", link = false }).fg,
        color_number(palette.syntax_punctuation),
        "keyword operator foreground"
    )
    equal(
        vim.api.nvim_get_hl(0, { name = "@keyword.directive", link = false }).fg,
        color_number(palette.syntax_attribute),
        "directive foreground"
    )
end)

test("public commands are registered", function()
    require("flume").setup({})
    for _, command in ipairs({ "FlumeReload", "FlumeCompile", "FlumeInstallExtras", "FlumeExtras" }) do
        equal(vim.fn.exists(":" .. command), 2, command .. " command")
    end
end)

test("reload stays editor-local and notifies plugins", function()
    local count = 0
    local compiler_loaded = false
    package.loaded["flume.compiler"] = nil
    package.preload["flume.compiler"] = function()
        compiler_loaded = true
        error("reload must not compile extras")
    end
    local group = vim.api.nvim_create_augroup("FlumeReloadContract", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        pattern = "flume",
        callback = function()
            count = count + 1
        end,
    })
    require("flume").reload()
    package.preload["flume.compiler"] = nil
    equal(compiler_loaded, false, "compiler loaded during reload")
    equal(count, 1, "ColorScheme event count")
    vim.api.nvim_del_augroup_by_id(group)
end)

test("extra installation replaces symlinks atomically and preserves files", function()
    local original_notify = vim.notify
    local notifications = {}
    vim.notify = function(message, level)
        notifications[#notifications + 1] = { message = message, level = level }
    end

    local extras = require("flume.extras")
    local apps = extras.get_apps()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")

    local old_target = root .. "/old"
    vim.fn.writefile({ "old" }, old_target)
    local link_dest = root .. "/theme-link"
    assert((vim.uv or vim.loop).fs_symlink(old_target, link_dest))
    apps.contract_link = { src = "README.md", dest = link_dest }
    extras.install("contract_link")
    equal(vim.fn.resolve(link_dest), extras.get_plugin_dir() .. "/README.md", "replacement symlink target")

    local file_dest = root .. "/theme-file"
    vim.fn.writefile({ "keep" }, file_dest)
    apps.contract_file = { src = "README.md", dest = file_dest }
    extras.install("contract_file")
    equal(vim.fn.readfile(file_dest)[1], "keep", "regular destination file")

    truthy(#notifications >= 2, "installer did not report outcomes")
    apps.contract_link = nil
    apps.contract_file = nil
    vim.fn.delete(root, "rf")
    vim.notify = original_notify
end)

test("generated extras are current and machine-readable", function()
    local changed = require("flume.compiler").compile_all({ quiet = true })
    equal(changed.any, false, "generated extras drift")
    equal(changed.count, 0, "generated extras changed count")

    local file = assert(io.open("extras/pi/flume.json", "rb"))
    local decoded = vim.json.decode(file:read("*a"))
    file:close()
    truthy(type(decoded) == "table" and decoded.name, "Pi theme JSON is invalid")

    local ghostty = assert(io.open("extras/ghostty/flume", "rb"))
    local content = ghostty:read("*a")
    ghostty:close()
    local slots = {}
    for index in content:gmatch("palette = (%d+)=") do
        slots[tonumber(index)] = true
    end
    for index = 0, 15 do
        truthy(slots[index], "Ghostty theme is missing ANSI slot " .. index)
    end
end)

test("Vim help tags build", function()
    local root = vim.fn.tempname()
    local doc = root .. "/doc"
    vim.fn.mkdir(doc, "p")
    vim.fn.writefile(vim.fn.readfile("doc/flume.txt"), doc .. "/flume.txt")
    vim.cmd("helptags " .. vim.fn.fnameescape(doc))
    equal(vim.fn.filereadable(doc .. "/tags"), 1, "help tags file")
    vim.fn.delete(root, "rf")
end)

test("health check runs without errors", function()
    require("flume").setup({})

    local original_health = vim.health
    local errors = {}
    vim.health = {
        start = function() end,
        ok = function() end,
        warn = function() end,
        error = function(message)
            errors[#errors + 1] = message
        end,
    }
    package.loaded["flume.health"] = nil
    require("flume.health").check()
    package.loaded["flume.health"] = nil
    vim.health = original_health

    equal(#errors, 0, "health errors")
end)

if #failures > 0 then
    io.stderr:write(string.format("\n%d test(s) failed; %d passed\n", #failures, passed))
    for _, failure in ipairs(failures) do
        io.stderr:write("\n[" .. failure.name .. "]\n" .. failure.err .. "\n")
    end
    vim.cmd("cquit 1")
else
    print(string.format("\n%d tests passed", passed))
    vim.cmd("qa!")
end
