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

local palettes = require("flume.palette")
local palette = palettes.dusk
local schema_names = palettes.schema_order

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

test("schemas have identical valid palette contracts", function()
    for _, schema in ipairs(schema_names) do
        local colors = palettes[schema]
        for key in pairs(palette) do
            truthy(colors[key], schema .. " palette is missing " .. key)
        end
        for key, value in pairs(colors) do
            truthy(palette[key], "Dusk palette is missing " .. key)
            truthy(type(value) == "string" and value:match("^#%x%x%x%x%x%x$"), schema .. " " .. key .. " is not #RRGGBB")
        end
    end
end)

test("primary and filled text meet contrast contracts", function()
    local ansi_roles = {
        "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
        "bright_black", "bright_red", "bright_green", "bright_yellow", "bright_blue",
        "bright_magenta", "bright_cyan", "bright_white",
    }
    local light_foreground_roles = {
        "error", "warning", "success", "info", "match", "diff_add", "diff_change", "diff_delete",
        "syntax_attribute", "syntax_boolean", "syntax_comment", "syntax_doc_comment", "syntax_constant",
        "syntax_function", "syntax_keyword", "syntax_namespace", "syntax_primary", "syntax_property",
        "syntax_punctuation", "syntax_punctuation_bracket", "syntax_punctuation_special", "syntax_special",
        "syntax_string", "syntax_type",
    }
    for _, schema in ipairs(schema_names) do
        local colors = palettes[schema]
        truthy(contrast(colors.syntax_primary, colors.bg) >= 4.5, schema .. " Normal text contrast is below 4.5:1")
        truthy(contrast(colors.on_accent, colors.accent) >= 4.5, schema .. " accent text contrast is below 4.5:1")
        truthy(contrast(colors.on_accent, colors.match) >= 4.5, schema .. " match text contrast is below 4.5:1")
        truthy(contrast(colors.border_focused, colors.bg) >= 3, schema .. " focused boundary contrast is below 3:1")
        if palettes.schemas[schema].appearance == "light" then
            for _, role in ipairs(light_foreground_roles) do
                truthy(contrast(colors[role], colors.bg) >= 4.5, schema .. " " .. role .. " is below 4.5:1")
            end
            for _, role in ipairs(ansi_roles) do
                truthy(contrast(colors[role], colors.terminal_bg) >= 4.5, schema .. " ANSI " .. role .. " is below 4.5:1")
            end
        end
    end
end)

test("stable schema registry and light comment inks are frozen", function()
    equal(table.concat(schema_names, ","), "dusk,opal,mira,mesa")
    equal(palettes.opal.bg, "#f2eff7")
    equal(palettes.opal.surface, "#ebe6f0")
    equal(palettes.opal.surface_alt, "#ddd6e3")
    equal(palettes.opal.syntax_comment, "#706b70")
    equal(palettes.opal.syntax_doc_comment, "#6c686d")
    equal(palettes.mesa.syntax_comment, "#6f6a6f")
    equal(palettes.mesa.syntax_doc_comment, "#6c686d")
end)

test("Mira and Mesa preserve their editor-first design anchors", function()
    local mira = palettes.mira
    local mesa = palettes.mesa

    equal(mira.bg, "#24212f", "Mira violet-charcoal foundation")
    equal(mesa.bg, "#f3ede8", "Mesa rose-mineral foundation")
    truthy(mira.bg ~= "#282e34", "Mira regressed to the source website canvas")
    truthy(mesa.bg ~= "#e5e2d9", "Mesa regressed to the source website canvas")

    equal(mira.syntax_function, mira.accent, "Mira function structure")
    equal(mesa.syntax_function, mesa.accent, "Mesa function structure")
    equal(mira.syntax_string, mira.success, "Mira string semantics")
    equal(mesa.syntax_string, mesa.success, "Mesa string semantics")
    truthy(mira.syntax_primary ~= mira.accent, "Mira identifiers compete with structure")
    truthy(mesa.syntax_primary ~= mesa.accent, "Mesa identifiers compete with structure")
end)

test("colorscheme clears highlights from the previous theme", function()
    vim.api.nvim_set_hl(0, "FlumeLeakProbe", { fg = "#ff0000", bg = "#00ff00" })
    vim.cmd.colorscheme("flume-dusk")
    local probe = vim.api.nvim_get_hl(0, { name = "FlumeLeakProbe", link = false })
    equal(next(probe), nil, "custom highlight leaked from the previous theme")
end)

test("default schema resolves canonical Normal and Search colors", function()
    require("flume").setup({})
    local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    local search = vim.api.nvim_get_hl(0, { name = "Search", link = false })
    equal(normal.fg, color_number(palette.syntax_primary), "Normal foreground")
    equal(normal.bg, color_number(palette.bg), "Normal background")
    equal(search.fg, color_number(palette.on_accent), "Search foreground")
    equal(search.bg, color_number(palette.accent), "Search background")
    equal(vim.o.background, "dark", "background option")
    equal(vim.g.colors_name, "flume-dusk", "colorscheme name")
end)

test("named schema entry points resolve before overrides", function()
    local flume = require("flume")
    for _, schema in ipairs(schema_names) do
        flume.setup({ schema = schema, overrides = { syntax_comment = "#abcdef" } })
        vim.cmd.colorscheme("flume-" .. schema)
        local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
        local heading = vim.api.nvim_get_hl(0, { name = "@markup.heading", link = false })
        equal(normal.fg, color_number(palettes[schema].syntax_primary), schema .. " Normal foreground")
        equal(normal.bg, color_number(palettes[schema].bg), schema .. " Normal background")
        equal(heading.fg, color_number(palettes[schema].accent), schema .. " markup heading foreground")
        equal(vim.api.nvim_get_hl(0, { name = "Comment", link = false }).fg, 0xabcdef, schema .. " override")
        equal(vim.o.background, palettes.schemas[schema].appearance, schema .. " background option")
        equal(vim.g.colors_name, "flume-" .. schema, schema .. " colorscheme name")
    end

end)

test("supported plugin highlights stay inside every schema palette", function()
    local role_contract = {
        FzfLuaNormal = { fg = "fg", bg = "bg" },
        FzfLuaBackdrop = { bg = "bg" },
        FzfLuaBorder = { fg = "border", bg = "bg" },
        FzfLuaTitle = { fg = "accent", bg = "bg" },
        FzfLuaCursorLine = { fg = "text", bg = "element_active" },
        FzfLuaFzfCursorLine = { fg = "text", bg = "element_active" },
        FzfLuaSearch = { fg = "match" },
        FzfLuaHeaderBind = { fg = "accent" },
        FzfLuaHeaderText = { fg = "muted" },
        FzfLuaPathColNr = { fg = "syntax_type" },
        FzfLuaPathLineNr = { fg = "muted" },
        FzfLuaLivePrompt = { fg = "accent" },
        FzfLuaLiveSym = { fg = "syntax_namespace" },
        FzfLuaBufNr = { fg = "muted" },
        FzfLuaBufFlagCur = { fg = "syntax_property" },
        FzfLuaBufFlagAlt = { fg = "accent" },
        FzfLuaTabTitle = { fg = "accent" },
        FzfLuaTabMarker = { fg = "success" },
        GitSignsStagedAdd = { fg = "dim_green", bg = "bg" },
        GitSignsStagedChange = { fg = "dim_yellow", bg = "bg" },
        GitSignsStagedDelete = { fg = "dim_red", bg = "bg" },
        IblIndent = { fg = "indent_guide" },
        IblWhitespace = { fg = "indent_guide" },
        IblScope = { fg = "line_number", bg = "bg" },
        NvimTreeWindowPicker = { fg = "on_accent", bg = "accent" },
    }

    local flume = require("flume")
    for _, schema in ipairs(schema_names) do
        flume.setup({ schema = schema })
        local colors = palettes[schema]
        for group, roles in pairs(role_contract) do
            local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
            for channel, role in pairs(roles) do
                equal(highlight[channel], color_number(colors[role]), schema .. " " .. group .. " " .. channel)
            end
        end
    end
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

test("setup applies and announces one schema exactly once", function()
    local count = 0
    local group = vim.api.nvim_create_augroup("FlumeSetupContract", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        pattern = "flume-opal",
        callback = function()
            count = count + 1
        end,
    })
    require("flume").setup({ schema = "opal" })
    equal(vim.g.colors_name, "flume-opal")
    equal(require("flume").config.schema, "opal")
    equal(count, 1, "setup ColorScheme event count")
    vim.api.nvim_del_augroup_by_id(group)
end)

test("public commands are registered", function()
    require("flume").setup({})
    for _, command in ipairs({ "FlumeReload", "FlumeCompile", "FlumeSync", "FlumeInstallExtras", "FlumeExtras" }) do
        equal(vim.fn.exists(":" .. command), 2, command .. " command")
    end
    local schemas = vim.fn.getcompletion("FlumeSync ", "cmdline")
    table.sort(schemas)
    equal(table.concat(schemas, ","), "dusk,mesa,mira,opal", "FlumeSync schema completion")
end)

test("screenshot initialization uses the single setup path", function()
    local script = table.concat(vim.fn.readfile("scripts/screenshot-window.sh"), "\n")
    truthy(script:find("require('flume').setup", 1, true), "screenshot setup call missing")
    truthy(not script:find("vim.cmd.colorscheme", 1, true), "screenshot applies setup and colorscheme")
end)

test("sync applies schemas and preserves a no-argument entry point", function()
    local synchronized_schema = nil
    package.loaded["flume.sync"] = {
        run = function(opts)
            synchronized_schema = opts.schema
            return { any = false, count = 0 }
        end,
    }

    vim.cmd.colorscheme("flume-dusk")
    vim.cmd("FlumeSync")
    equal(synchronized_schema, "dusk", "implicit synchronized schema")
    equal(vim.g.colors_name, "flume-dusk", "implicit sync entry point")

    vim.cmd("FlumeSync opal")
    package.loaded["flume.sync"] = nil
    equal(synchronized_schema, "opal", "explicit synchronized schema")
    equal(require("flume").config.schema, "opal", "editor schema after sync")
    equal(vim.g.colors_name, "flume-opal", "editor colorscheme after sync")
end)

test("reload preserves colorscheme entry identity", function()
    for _, entry in ipairs({ "flume-dusk", "flume-opal", "flume-mira", "flume-mesa" }) do
        vim.cmd.colorscheme(entry)
        require("flume").reload()
        equal(vim.g.colors_name, entry, entry .. " identity after reload")
    end
end)

test("reload stays editor-local and notifies plugins", function()
    require("flume").setup({})
    local count = 0
    package.loaded["flume.sync"] = nil
    package.preload["flume.sync"] = function()
        error("reload must not synchronize global extras")
    end
    local group = vim.api.nvim_create_augroup("FlumeReloadContract", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        pattern = "flume-dusk",
        callback = function()
            count = count + 1
        end,
    })
    require("flume").reload()
    package.preload["flume.sync"] = nil
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
    local active_schema_file = io.open("extras/current/schema", "rb")
    local active_schema = active_schema_file and active_schema_file:read("*l") or "dusk"
    if active_schema_file then
        active_schema_file:close()
    end
    if not palettes.schemas[active_schema] then
        active_schema = "dusk"
    end
    local changed = require("flume.compiler").compile_all({ quiet = true, activate = false })
    equal(changed.any, false, "generated extras drift")
    equal(changed.count, 0, "generated extras changed count")

    local file = assert(io.open("extras/pi/flume-dusk.json", "rb"))
    local decoded = vim.json.decode(file:read("*a"))
    file:close()
    truthy(type(decoded) == "table" and decoded.name, "Pi theme JSON is invalid")
    equal(decoded.vars.diffAdd, palette.diff_add, "Pi added-line color")
    equal(decoded.vars.diffDelete, palette.diff_delete, "Pi removed-line color")
    equal(decoded.colors.toolDiffAdded, "diffAdd", "Pi added-line semantic role")
    equal(decoded.colors.toolDiffRemoved, "diffDelete", "Pi removed-line semantic role")

    local generated_diff_contracts = {
        ["extras/lazygit/flume-dusk.yml"] = {
            'inactiveViewSelectedLineBgColor: ["' .. palette.active_line .. '"]',
            'unstagedChangesColor: ["' .. palette.diff_delete .. '"]',
            '--minus-style="syntax ' .. palette.diff_delete_bg .. '"',
            '--minus-emph-style="syntax ' .. palette.diff_delete_emphasis .. '"',
            '--plus-style="syntax ' .. palette.diff_add_bg .. '"',
            '--plus-emph-style="syntax ' .. palette.diff_add_emphasis .. '"',
            '--line-numbers-minus-style=' .. palette.diff_delete,
            '--line-numbers-plus-style=' .. palette.diff_add,
        },
        ["extras/delta/flume-dusk.gitconfig"] = {
            'minus-style = syntax "' .. palette.diff_delete_bg .. '"',
            'minus-emph-style = syntax "' .. palette.diff_delete_emphasis .. '"',
            'plus-style = syntax "' .. palette.diff_add_bg .. '"',
            'plus-emph-style = syntax "' .. palette.diff_add_emphasis .. '"',
            'line-numbers-minus-style = "' .. palette.diff_delete .. '"',
            'line-numbers-plus-style = "' .. palette.diff_add .. '"',
        },
    }
    for path, expected_mappings in pairs(generated_diff_contracts) do
        local generated = assert(io.open(path, "rb"))
        local generated_content = generated:read("*a")
        generated:close()
        for _, expected in ipairs(expected_mappings) do
            truthy(generated_content:find(expected, 1, true), path .. " is missing mapping " .. expected)
        end
        truthy(not generated_content:find("\n    selectedRangeBgColor:", 1, true), path .. " uses a removed Lazygit key")
        truthy(not generated_content:find("\n    stagedChangesColor:", 1, true), path .. " uses a removed Lazygit key")
    end

    local ghostty = assert(io.open("extras/ghostty/flume-dusk", "rb"))
    local content = ghostty:read("*a")
    ghostty:close()
    local slots = {}
    for index in content:gmatch("palette = (%d+)=") do
        slots[tonumber(index)] = true
    end
    for index = 0, 15 do
        truthy(slots[index], "Ghostty theme is missing ANSI slot " .. index)
    end

    local function read_all(path)
        local generated = assert(io.open(path, "rb"))
        local content = generated:read("*a")
        generated:close()
        return content
    end

    local compiler = require("flume.compiler")
    local activation_contract = {
        ghostty = { source = "extras/ghostty/flume%s", current = "extras/current/ghostty" },
        kitty = { source = "extras/kitty/flume%s.conf", current = "extras/current/kitty.conf" },
        tmux = { source = "extras/tmux/colors%s.conf", current = "extras/current/tmux.conf" },
        lsd = { source = "extras/lsd/colors%s.yaml", current = "extras/current/lsd.yaml" },
        opencode = { source = "extras/opencode/flume%s.json", current = "extras/current/opencode.json" },
        lazygit = { source = "extras/lazygit/flume%s.yml", current = "extras/current/lazygit.yml" },
        fzf = { source = "extras/fzf/flume%s.opts", current = "extras/current/fzf.opts" },
        delta = { source = "extras/delta/flume%s.gitconfig", current = "extras/current/delta.gitconfig" },
        pi = { source = "extras/pi/flume%s.json", current = "extras/current/pi.json" },
        tuxedo = { source = "extras/tuxedo/flume%s.toml", current = "extras/current/tuxedo.toml" },
    }
    for _, schema in ipairs(require("flume.palette").schema_order) do
        local suffix = require("flume.palette").schemas[schema].suffix
        local lsd = read_all("extras/lsd/colors" .. suffix .. ".yaml")
        truthy(not lsd:find("\nname:", 1, true), schema .. " LSD theme uses unsupported name keys")
        if require("flume.palette").schemas[schema].appearance == "light" then
            local read_color = lsd:match("\n  read: (%d+)")
            equal(lsd:match("\n  write: (%d+)"), read_color, schema .. " quiet write permission")
            equal(lsd:match("\n  exec: (%d+)"), read_color, schema .. " quiet exec permission")

            local on_accent = require("flume.palette")[schema].on_accent
            local ghostty = read_all("extras/ghostty/flume" .. suffix)
            equal(
                ghostty:match("\nselection%-foreground = (#[%x]+)"),
                on_accent,
                schema .. " Ghostty selection foreground"
            )
            local kitty = read_all("extras/kitty/flume" .. suffix .. ".conf")
            equal(
                kitty:match("\nselection_foreground%s+(#[%x]+)"),
                on_accent,
                schema .. " Kitty selection foreground"
            )
        end

        local pi_theme = vim.json.decode(read_all("extras/pi/flume" .. suffix .. ".json"))
        equal(pi_theme.colors.mdHeading, "accent", schema .. " quiet Pi heading")

        compiler.activate(schema)
        equal(read_all("extras/current/schema"), schema .. "\n", schema .. " active schema marker")
        for adapter, paths in pairs(activation_contract) do
            equal(
                read_all(paths.current),
                read_all(paths.source:format(suffix)),
                schema .. " active " .. adapter .. " extra"
            )
        end
    end

    local invalid_ok = pcall(compiler.activate, "unknown")
    truthy(not invalid_ok, "invalid activation schema was accepted")

    compiler.activate("dusk")
    local missing_source = "extras/tuxedo/flume-opal.toml"
    local held_source = missing_source .. ".contract"
    assert((vim.uv or vim.loop).fs_rename(missing_source, held_source))
    local partial_ok = pcall(compiler.activate, "opal")
    assert((vim.uv or vim.loop).fs_rename(held_source, missing_source))
    truthy(not partial_ok, "activation with a missing source unexpectedly succeeded")
    equal(
        read_all("extras/current/ghostty"),
        read_all("extras/ghostty/flume-dusk"),
        "failed activation partially replaced the active set"
    )

    compiler.activate(active_schema)
    equal((vim.uv or vim.loop).fs_lstat("extras/current").type, "link", "active set is not atomically linked")
end)

require("tests.extras").register(test, equal, truthy)

test("Vim help tags build", function()
    local root = vim.fn.tempname()
    local doc = root .. "/doc"
    vim.fn.mkdir(doc, "p")
    vim.fn.writefile(vim.fn.readfile("doc/flume.txt"), doc .. "/flume.txt")
    vim.cmd("helptags " .. vim.fn.fnameescape(doc))
    equal(vim.fn.filereadable(doc .. "/tags"), 1, "help tags file")
    vim.fn.delete(root, "rf")
end)

test("health check covers canonical schemas", function()
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

    for _, schema in ipairs({ "dusk", "opal", "mira", "mesa" }) do
        require("flume").setup({ schema = schema })
        package.loaded["flume.health"] = nil
        require("flume.health").check()
    end

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
