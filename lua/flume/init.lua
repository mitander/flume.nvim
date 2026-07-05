local M = {}

M.colors = {}
M.config = {
    transparent = false,
    overrides = {},
}

local function hi(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
end

local function get_zig_namespace_token_context(ev)
    local token = ev.data and ev.data.token
    if not token or token.type ~= "namespace" or vim.bo[ev.buf].filetype ~= "zig" then
        return nil
    end

    local line = vim.api.nvim_buf_get_lines(ev.buf, token.line, token.line + 1, false)[1] or ""
    local start_col = token.start_col or 0
    local end_col = token.end_col or (start_col + (token.length or 1))
    local text = line:sub(start_col + 1, end_col)

    return token, line, text
end

local function is_dotted_namespace_token(token, line)
    return line:sub(1, token.start_col):match("%.$") ~= nil
end

local function is_type_like_namespace(text)
    return text:match("^[A-Z]") ~= nil
end

local function clear_flume_modules()
    for name in pairs(package.loaded) do
        if name == "flume" or name:match("^flume%.") then
            package.loaded[name] = nil
        end
    end
end

local function system_success(cmd)
    vim.fn.system(cmd)
    return vim.v.shell_error == 0
end

local function reload_ghostty()
    if vim.fn.has("macunix") == 0 or vim.fn.executable("osascript") == 0 then
        vim.notify("Flume compiled Ghostty theme. Reload Ghostty manually.", vim.log.levels.INFO)
        return
    end

    local script = [[
tell application "System Events"
    if exists process "Ghostty" then
        tell process "Ghostty"
            set frontmost to true
            keystroke "," using {command down, shift down}
        end tell
    end if
end tell
]]
    if not system_success({ "osascript", "-e", script }) then
        vim.notify("Flume compiled Ghostty theme, but Ghostty config reload failed", vim.log.levels.WARN)
    end
end

local function reload_tmux()
    if vim.fn.executable("tmux") == 0 or not system_success({ "tmux", "has-session" }) then
        return
    end

    local paths = {
        vim.fn.expand("~/.config/tmux/tmux.conf"),
        vim.fn.expand("~/.tmux.conf"),
        vim.fn.expand("~/.tmux/flume-theme.conf"),
    }

    local sourced = false
    for _, path in ipairs(paths) do
        if vim.fn.filereadable(path) == 1 then
            sourced = system_success({ "tmux", "source-file", path }) or sourced
        end
    end

    if not sourced then
        vim.notify("Flume compiled Tmux theme, but no tmux config file was found to source", vim.log.levels.WARN)
    end
end

local function reload_external_apps(changed)
    if not changed or not changed.any then
        return
    end
    if changed.ghostty then
        reload_ghostty()
    end
    if changed.tmux then
        reload_tmux()
    end
end

function M.reload()
    local config = vim.deepcopy(M.config)
    package.loaded["flume.palette"] = nil
    package.loaded["flume.compiler"] = nil

    local ok, changed = pcall(function()
        return require("flume.compiler").compile_all({ quiet = true })
    end)
    if not ok then
        vim.notify("Flume extras compile failed: " .. tostring(changed), vim.log.levels.ERROR)
        changed = nil
    end

    clear_flume_modules()
    require("flume").setup(config)

    reload_external_apps(changed)
    local extras_status = changed
            and (changed.any and (changed.count .. " extra file(s) updated") or "extras unchanged")
        or "extras not updated"
    vim.notify("Flume theme reloaded (" .. extras_status .. ")", vim.log.levels.INFO)
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    M.load()
end

function M.load()
    local palette = require("flume.palette")
    M.colors = vim.tbl_deep_extend("force", {}, palette.colors, M.config.overrides or {})
    local c = M.colors

    if M.config.transparent then
        c.bg = "NONE"
        c.terminal_bg = "NONE"
        c.element = "NONE"
    end

    vim.o.background = "dark"
    vim.g.colors_name = "flume"

    hi("Normal", { fg = c.syntax_primary, bg = c.bg })
    hi("NormalNC", { fg = c.syntax_primary, bg = c.bg })
    hi("NormalFloat", { fg = c.fg, bg = c.bg })
    hi("FloatBorder", { fg = c.border, bg = c.bg })
    hi("FloatTitle", { fg = c.text, bg = c.bg, bold = true })
    hi("WinSeparator", { fg = c.border_variant, bg = c.bg })
    hi("SignColumn", { bg = c.bg })
    hi("FoldColumn", { fg = c.placeholder, bg = c.bg })
    hi("Folded", { fg = c.muted, bg = c.surface })
    hi("EndOfBuffer", { fg = c.bg, bg = c.bg })
    hi("NonText", { fg = c.line_number })
    hi("Whitespace", { fg = c.line_number })
    hi("IblIndent", { fg = c.indent_guide })
    hi("IblWhitespace", { fg = c.indent_guide })
    hi("ColorColumn", { bg = c.surface })
    hi("CursorLine", { bg = c.active_line })
    hi("CursorLineNr", { fg = c.active_line_number, bg = c.active_line, bold = true })
    hi("LineNr", { fg = c.line_number, bg = c.bg })
    hi("Visual", { bg = c.element_active })
    hi("Search", { fg = c.text, bg = c.dim_blue })
    hi("IncSearch", { fg = c.terminal_bg, bg = c.yellow })
    hi("CurSearch", { fg = c.terminal_bg, bg = c.yellow })
    hi("MatchParen", { fg = c.text, bg = c.element_active, bold = true })
    hi("Directory", { fg = c.accent })
    hi("Title", { fg = c.accent, bold = true })

    hi("StatusLine", { fg = c.text, bg = c.surface_alt })
    hi("StatusLineNC", { fg = c.muted, bg = c.surface })
    hi("TabLine", { fg = c.muted, bg = c.surface })
    hi("TabLineSel", { fg = c.text, bg = c.bg, bold = true })
    hi("TabLineFill", { bg = c.surface })

    hi("Pmenu", { fg = c.fg, bg = c.surface })
    hi("PmenuSel", { fg = c.text, bg = c.element_active })
    hi("PmenuSbar", { bg = c.surface })
    hi("PmenuThumb", { bg = c.bright_black })
    hi("WildMenu", { fg = c.text, bg = c.element_active })

    hi("Question", { fg = c.green })
    hi("MoreMsg", { fg = c.green })
    hi("WarningMsg", { fg = c.yellow })
    hi("ErrorMsg", { fg = c.red })
    hi("ModeMsg", { fg = c.text })

    hi("DiffAdd", { bg = c.diff_add_bg })
    hi("DiffChange", { bg = c.diff_change_bg })
    hi("DiffDelete", { fg = c.red, bg = c.diff_delete_bg })
    hi("DiffText", { bg = c.dim_blue })
    hi("Added", { fg = c.green })
    hi("Changed", { fg = c.yellow })
    hi("Removed", { fg = c.red })

    hi("DiagnosticError", { fg = c.red })
    hi("DiagnosticWarn", { fg = c.yellow })
    hi("DiagnosticInfo", { fg = c.accent })
    hi("DiagnosticHint", { fg = c.hint })
    hi("DiagnosticOk", { fg = c.green })
    hi("DiagnosticVirtualTextError", { fg = c.red, bg = c.diff_delete_bg })
    hi("DiagnosticVirtualTextWarn", { fg = c.yellow, bg = c.warn_bg })
    hi("DiagnosticVirtualTextInfo", { fg = c.accent, bg = c.hint_bg })
    hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = c.hint_bg })
    hi("DiagnosticUnderlineError", { sp = c.red, undercurl = true })
    hi("DiagnosticUnderlineWarn", { sp = c.yellow, undercurl = true })
    hi("DiagnosticUnderlineInfo", { sp = c.accent, undercurl = true })
    hi("DiagnosticUnderlineHint", { sp = c.hint, undercurl = true })

    hi("Comment", { fg = c.syntax_comment })
    hi("Constant", { fg = c.syntax_constant })
    hi("String", { fg = c.syntax_string })
    hi("Character", { fg = c.syntax_string })
    hi("Number", { fg = c.syntax_boolean })
    hi("Boolean", { fg = c.syntax_boolean })
    hi("Float", { fg = c.syntax_boolean })
    hi("Identifier", { fg = c.syntax_primary })
    hi("Function", { fg = c.syntax_function })
    hi("Statement", { fg = c.syntax_keyword })
    hi("Conditional", { fg = c.syntax_keyword })
    hi("Repeat", { fg = c.syntax_keyword })
    hi("Label", { fg = c.accent })
    hi("Operator", { fg = c.syntax_punctuation })
    hi("Keyword", { fg = c.syntax_keyword })
    hi("Exception", { fg = c.syntax_keyword })
    hi("PreProc", { fg = c.syntax_keyword })
    hi("Include", { fg = c.syntax_keyword })
    hi("Define", { fg = c.syntax_keyword })
    hi("Macro", { fg = c.syntax_keyword })
    hi("PreCondit", { fg = c.syntax_keyword })
    hi("Type", { fg = c.syntax_type })
    hi("StorageClass", { fg = c.syntax_keyword })
    hi("Structure", { fg = c.syntax_type })
    hi("Typedef", { fg = c.syntax_type })
    hi("Special", { fg = c.syntax_special })
    hi("SpecialChar", { fg = c.syntax_special })
    hi("Tag", { fg = c.syntax_constant })
    hi("Delimiter", { fg = c.syntax_punctuation })
    hi("SpecialComment", { fg = c.syntax_doc_comment })
    hi("Debug", { fg = c.red })
    hi("Underlined", { fg = c.accent, underline = true })
    hi("Ignore", { fg = c.placeholder })
    hi("Error", { fg = c.red })
    hi("Todo", { fg = c.yellow, bg = "NONE", bold = true })

    -- Legacy Zig syntax group for @builtins when tree-sitter/LSP semantic
    -- highlighting is unavailable or disabled.
    hi("zigBuiltinFn", { fg = c.syntax_special })

    hi("@attribute", { fg = c.syntax_attribute })
    hi("@boolean", { fg = c.syntax_boolean })
    hi("@character", { fg = c.syntax_string })
    hi("@comment", { fg = c.syntax_comment })
    hi("@comment.documentation", { fg = c.syntax_doc_comment })
    hi("@constant", { fg = c.syntax_constant })
    hi("@constant.builtin", { fg = c.syntax_boolean })
    hi("@constructor", { fg = c.syntax_function })
    hi("@function", { fg = c.syntax_function })
    hi("@function.builtin", { fg = c.syntax_function })
    hi("@function.call", { fg = c.syntax_function })
    hi("@function.macro", { fg = c.syntax_function })
    hi("@keyword", { fg = c.syntax_keyword })
    hi("@keyword.conditional", { fg = c.syntax_keyword })
    hi("@keyword.function", { fg = c.syntax_keyword })
    hi("@keyword.operator", { fg = c.syntax_keyword })
    hi("@keyword.repeat", { fg = c.syntax_keyword })
    hi("@keyword.return", { fg = c.syntax_keyword })
    hi("@label", { fg = c.accent })
    hi("@module", { fg = c.syntax_primary })
    hi("@namespace", { fg = c.syntax_primary })
    hi("@number", { fg = c.syntax_boolean })
    hi("@number.float", { fg = c.syntax_boolean })
    hi("@operator", { fg = c.syntax_punctuation })
    hi("@property", { fg = c.syntax_property })
    hi("@field", { fg = c.syntax_property })
    hi("@punctuation.bracket", { fg = c.syntax_punctuation_bracket })
    hi("@punctuation.delimiter", { fg = c.syntax_punctuation })
    hi("@punctuation.special", { fg = c.syntax_punctuation_special })
    hi("@string", { fg = c.syntax_string })
    hi("@string.documentation", { fg = c.syntax_string })
    hi("@string.escape", { fg = c.syntax_doc_comment })
    hi("@string.regexp", { fg = c.syntax_boolean })
    hi("@string.special", { fg = c.syntax_boolean })
    hi("@tag", { fg = c.syntax_constant })
    hi("@tag.attribute", { fg = c.syntax_attribute })
    hi("@tag.delimiter", { fg = c.syntax_punctuation_special })
    hi("@text.literal", { fg = c.syntax_string })
    hi("@type", { fg = c.syntax_type })
    hi("@type.builtin", { fg = c.syntax_type })
    hi("@variable", { fg = c.syntax_primary })
    hi("@variable.builtin", { fg = c.syntax_boolean })
    hi("@variable.member", { fg = c.syntax_property })
    hi("@variable.readonly", { link = "Constant" })
    hi("@variable.member.readonly", { link = "Constant" })
    hi("@markup.heading", { fg = c.accent, bold = true })
    hi("@markup.italic", { italic = true })
    hi("@markup.link", { fg = c.syntax_function, italic = true })
    hi("@markup.link.url", { fg = c.syntax_type, underline = true })
    hi("@markup.list", { fg = c.accent })
    hi("@markup.raw", { fg = c.syntax_string })

    hi("GitSignsAdd", { fg = c.green, bg = c.bg })
    hi("GitSignsChange", { fg = c.yellow, bg = c.bg })
    hi("GitSignsDelete", { fg = c.red, bg = c.bg })
    hi("OilDir", { fg = c.accent })
    hi("OilFile", { fg = c.fg })
    hi("OilHidden", { fg = c.placeholder })
    hi("OilLink", { fg = c.cyan })
    hi("OilStatusLine", { fg = c.fg, bg = c.surface_alt, bold = true })

    -- LSP semantic tokens mapping
    hi("@lsp.type.class", { link = "Type" })
    hi("@lsp.type.decorator", { link = "Identifier" })
    hi("@lsp.type.enum", { link = "Type" })
    hi("@lsp.type.enumMember", { link = "Constant" })
    hi("@lsp.type.function", { link = "Function" })
    hi("@lsp.type.interface", { link = "Type" })
    hi("@lsp.type.macro", { link = "Macro" })
    hi("@lsp.type.method", { link = "Function" })
    hi("@lsp.type.builtin", { fg = c.syntax_special })
    hi("@lsp.type.builtin.zig", { fg = c.syntax_special })
    -- Avoid flattening dotted Zig namespaces like render.camera into one color,
    -- tree-sitter can still color the member side via @variable.member.
    hi("@lsp.type.namespace", {})
    hi("@lsp.type.parameter", { fg = c.syntax_primary })
    hi("@lsp.type.property", { fg = c.syntax_property })
    hi("@lsp.type.property.readonly", { link = "Constant" })
    hi("@lsp.type.struct", { link = "Type" })
    hi("@lsp.type.type", { link = "Type" })
    hi("@lsp.type.typeParameter", { link = "Type" })
    hi("@lsp.type.variable", { fg = c.syntax_primary })
    hi("@lsp.type.variable.readonly", { link = "Constant" })
    hi("@lsp.typemod.variable.static", { link = "Constant" })
    hi("@lsp.typemod.property.static", { link = "Constant" })

    hi("FlumeDottedNamespace", { fg = c.syntax_namespace })
    hi("FlumeTypeLikeNamespace", { fg = c.syntax_type })

    local semantic_tokens = vim.lsp and vim.lsp.semantic_tokens
    if semantic_tokens and semantic_tokens.highlight_token then
        local augroup = vim.api.nvim_create_augroup("FlumeSemanticTokens", { clear = true })
        vim.api.nvim_create_autocmd("LspTokenUpdate", {
            group = augroup,
            callback = function(ev)
                local token, line, text = get_zig_namespace_token_context(ev)
                if not token then
                    return
                end

                if is_type_like_namespace(text) then
                    semantic_tokens.highlight_token(token, ev.buf, ev.data.client_id, "FlumeTypeLikeNamespace")
                elseif is_dotted_namespace_token(token, line) then
                    semantic_tokens.highlight_token(token, ev.buf, ev.data.client_id, "FlumeDottedNamespace")
                end
            end,
        })
        if semantic_tokens.force_refresh then
            pcall(semantic_tokens.force_refresh, 0)
        end
    end

    local terminal_colors = {
        c.black,
        c.red,
        c.green,
        c.yellow,
        c.blue,
        c.magenta,
        c.cyan,
        c.white,
        c.bright_black,
        c.bright_red,
        c.bright_green,
        c.bright_yellow,
        c.bright_blue,
        c.bright_magenta,
        c.bright_cyan,
        c.bright_white,
    }

    for i, color in ipairs(terminal_colors) do
        vim.g["terminal_color_" .. (i - 1)] = color
    end

    vim.api.nvim_create_user_command("FlumeReload", M.reload, {})
    vim.api.nvim_create_user_command("FlumeCompile", function()
        package.loaded["flume.palette"] = nil
        package.loaded["flume.compiler"] = nil
        require("flume.compiler").compile_all()
    end, {})
    vim.api.nvim_create_user_command("FlumeInstallExtras", function(opts)
        local arg = opts.args
        if arg == "" then
            require("flume.extras").install_all()
        else
            require("flume.extras").install(arg)
        end
    end, {
        nargs = "?",
        complete = function()
            return vim.tbl_keys(require("flume.extras").get_apps())
        end,
    })
    vim.api.nvim_create_user_command("FlumeExtras", function()
        require("flume.extras").show_instructions()
    end, {})
end

return M
