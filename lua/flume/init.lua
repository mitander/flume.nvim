local M = {}

local default_config = {
    transparent = false,
    terminal_colors = true,
    overrides = {},
    highlights = {},
    styles = {
        comments = {},
        functions = {},
        keywords = {},
        strings = {},
        types = {},
        variables = {},
    },
}

M.colors = {}
M.config = vim.deepcopy(default_config)

local function hi(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
end

local function styled(opts, style)
    return vim.tbl_deep_extend("force", opts, style or {})
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
    M.config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})
    M.load()
end

function M.get_colors()
    local palette = require("flume.palette")
    return vim.tbl_deep_extend("force", {}, palette.colors, M.config.overrides or {})
end

function M.load()
    M.colors = M.get_colors()
    local c = M.colors
    local styles = M.config.styles or {}

    if M.config.transparent then
        c.bg = "NONE"
        c.element = "NONE"
    end

    vim.o.background = "dark"
    vim.cmd("highlight clear")
    if vim.fn.exists("syntax_on") == 1 then
        vim.cmd("syntax reset")
    end
    vim.g.colors_name = "flume"

    hi("Normal", { fg = c.syntax_primary, bg = c.bg })
    hi("NormalNC", { fg = c.syntax_primary, bg = c.bg })
    hi("NormalFloat", { fg = c.fg, bg = c.bg })
    hi("FloatBorder", { fg = c.border, bg = c.bg })
    hi("FloatTitle", { fg = c.text, bg = c.bg, bold = true })
    hi("WinSeparator", { fg = c.border_variant, bg = c.bg })
    hi("SignColumn", { bg = c.element })
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
    hi("Search", { fg = c.on_accent, bg = c.accent })
    hi("IncSearch", { fg = c.on_accent, bg = c.match })
    hi("CurSearch", { fg = c.on_accent, bg = c.match })
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

    hi("Question", { fg = c.success })
    hi("MoreMsg", { fg = c.success })
    hi("WarningMsg", { fg = c.warning })
    hi("ErrorMsg", { fg = c.error })
    hi("ModeMsg", { fg = c.text })

    hi("DiffAdd", { bg = c.diff_add_bg })
    hi("DiffChange", { bg = c.diff_change_bg })
    hi("DiffDelete", { fg = c.diff_delete, bg = c.diff_delete_bg })
    hi("DiffText", { bg = c.dim_blue })
    hi("Added", { fg = c.diff_add })
    hi("Changed", { fg = c.diff_change })
    hi("Removed", { fg = c.diff_delete })

    hi("DiagnosticError", { fg = c.error })
    hi("DiagnosticWarn", { fg = c.warning })
    hi("DiagnosticInfo", { fg = c.info })
    hi("DiagnosticHint", { fg = c.hint })
    hi("DiagnosticOk", { fg = c.success })
    hi("DiagnosticVirtualTextError", { fg = c.error, bg = c.diff_delete_bg })
    hi("DiagnosticVirtualTextWarn", { fg = c.warning, bg = c.warn_bg })
    hi("DiagnosticVirtualTextInfo", { fg = c.info, bg = c.hint_bg })
    hi("DiagnosticVirtualTextHint", { fg = c.hint, bg = c.hint_bg })
    hi("DiagnosticUnderlineError", { sp = c.error, undercurl = true })
    hi("DiagnosticUnderlineWarn", { sp = c.warning, undercurl = true })
    hi("DiagnosticUnderlineInfo", { sp = c.info, undercurl = true })
    hi("DiagnosticUnderlineHint", { sp = c.hint, undercurl = true })

    hi("Comment", styled({ fg = c.syntax_comment }, styles.comments))
    hi("Constant", { fg = c.syntax_constant })
    hi("String", styled({ fg = c.syntax_string }, styles.strings))
    hi("Character", styled({ fg = c.syntax_string }, styles.strings))
    hi("Number", { fg = c.syntax_boolean })
    hi("Boolean", { fg = c.syntax_boolean })
    hi("Float", { fg = c.syntax_boolean })
    hi("Identifier", styled({ fg = c.syntax_primary }, styles.variables))
    hi("Function", styled({ fg = c.syntax_function }, styles.functions))
    hi("Statement", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("Conditional", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("Repeat", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("Label", { fg = c.accent })
    hi("Operator", { fg = c.syntax_punctuation })
    hi("Keyword", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("Exception", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("PreProc", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("Include", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("Define", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("Macro", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("PreCondit", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("Type", styled({ fg = c.syntax_type }, styles.types))
    hi("StorageClass", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("Structure", styled({ fg = c.syntax_type }, styles.types))
    hi("Typedef", styled({ fg = c.syntax_type }, styles.types))
    hi("Special", { fg = c.syntax_special })
    hi("SpecialChar", { fg = c.syntax_special })
    hi("Tag", { fg = c.syntax_constant })
    hi("Delimiter", { fg = c.syntax_punctuation })
    hi("SpecialComment", { fg = c.syntax_doc_comment })
    hi("Debug", { fg = c.error })
    hi("Underlined", { fg = c.accent, underline = true })
    hi("Ignore", { fg = c.placeholder })
    hi("Error", { fg = c.error })
    hi("Todo", { fg = c.warning, bg = "NONE", bold = true })

    -- Legacy Zig syntax group for @builtins when tree-sitter/LSP semantic
    -- highlighting is unavailable or disabled.
    hi("zigBuiltinFn", { fg = c.syntax_special })

    hi("@attribute", { fg = c.syntax_attribute })
    hi("@attribute.builtin", { fg = c.syntax_special })
    hi("@boolean", { fg = c.syntax_boolean })
    hi("@character", styled({ fg = c.syntax_string }, styles.strings))
    hi("@character.special", { fg = c.syntax_special })
    hi("@comment", styled({ fg = c.syntax_comment }, styles.comments))
    hi("@comment.documentation", styled({ fg = c.syntax_doc_comment }, styles.comments))
    hi("@comment.error", { fg = c.error })
    hi("@comment.note", { fg = c.info })
    hi("@comment.todo", { fg = c.warning, bold = true })
    hi("@comment.warning", { fg = c.warning })
    hi("@constant", { fg = c.syntax_constant })
    hi("@constant.builtin", { fg = c.syntax_boolean })
    hi("@constant.macro", { fg = c.syntax_constant })
    hi("@constructor", styled({ fg = c.syntax_function }, styles.functions))
    hi("@function", styled({ fg = c.syntax_function }, styles.functions))
    hi("@function.builtin", styled({ fg = c.syntax_function }, styles.functions))
    hi("@function.call", styled({ fg = c.syntax_function }, styles.functions))
    hi("@function.macro", styled({ fg = c.syntax_function }, styles.functions))
    hi("@function.method", styled({ fg = c.syntax_function }, styles.functions))
    hi("@function.method.call", styled({ fg = c.syntax_function }, styles.functions))
    hi("@keyword", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("@keyword.conditional", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("@keyword.directive", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("@keyword.exception", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("@keyword.function", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("@keyword.import", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("@keyword.modifier", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("@keyword.operator", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("@keyword.repeat", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("@keyword.return", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("@keyword.type", styled({ fg = c.syntax_keyword }, styles.keywords))
    hi("@label", { fg = c.accent })
    hi("@module", { fg = c.syntax_namespace })
    hi("@module.builtin", { fg = c.syntax_special })
    hi("@namespace", { fg = c.syntax_namespace })
    hi("@number", { fg = c.syntax_boolean })
    hi("@number.float", { fg = c.syntax_boolean })
    hi("@operator", { fg = c.syntax_punctuation })
    hi("@property", { fg = c.syntax_property })
    hi("@field", { fg = c.syntax_property })
    hi("@punctuation.bracket", { fg = c.syntax_punctuation_bracket })
    hi("@punctuation.delimiter", { fg = c.syntax_punctuation })
    hi("@punctuation.special", { fg = c.syntax_punctuation_special })
    hi("@string", styled({ fg = c.syntax_string }, styles.strings))
    hi("@string.documentation", styled({ fg = c.syntax_string }, styles.strings))
    hi("@string.escape", { fg = c.syntax_doc_comment })
    hi("@string.regexp", { fg = c.syntax_boolean })
    hi("@string.special", { fg = c.syntax_boolean })
    hi("@string.special.symbol", { fg = c.syntax_constant })
    hi("@tag", { fg = c.syntax_constant })
    hi("@tag.attribute", { fg = c.syntax_attribute })
    hi("@tag.builtin", { fg = c.syntax_special })
    hi("@tag.delimiter", { fg = c.syntax_punctuation_special })
    hi("@text.literal", styled({ fg = c.syntax_string }, styles.strings))
    hi("@type", styled({ fg = c.syntax_type }, styles.types))
    hi("@type.builtin", styled({ fg = c.syntax_type }, styles.types))
    hi("@type.definition", styled({ fg = c.syntax_type }, styles.types))
    hi("@variable", styled({ fg = c.syntax_primary }, styles.variables))
    hi("@variable.builtin", { fg = c.syntax_boolean })
    hi("@variable.member", { fg = c.syntax_property })
    hi("@variable.readonly", { link = "Constant" })
    hi("@variable.member.readonly", { link = "Constant" })
    hi("@markup.heading", { fg = c.accent, bold = true })
    hi("@markup.italic", { italic = true })
    hi("@markup.link", { fg = c.syntax_function, italic = true })
    hi("@markup.link.label", { fg = c.syntax_function })
    hi("@markup.link.url", { fg = c.syntax_type, underline = true })
    hi("@markup.list", { fg = c.accent })
    hi("@markup.math", { fg = c.syntax_boolean })
    hi("@markup.quote", { fg = c.syntax_doc_comment, italic = true })
    hi("@markup.raw", { fg = c.syntax_string })
    hi("@markup.strong", { bold = true })
    hi("@markup.strikethrough", { strikethrough = true })
    hi("@markup.underline", { underline = true })
    hi("@diff.plus", { fg = c.diff_add })
    hi("@diff.minus", { fg = c.diff_delete })
    hi("@diff.delta", { fg = c.diff_change })

    hi("GitSignsAdd", { fg = c.diff_add, bg = c.bg })
    hi("GitSignsChange", { fg = c.diff_change, bg = c.bg })
    hi("GitSignsDelete", { fg = c.diff_delete, bg = c.bg })
    hi("OilDir", { fg = c.accent })
    hi("OilFile", { fg = c.fg })
    hi("OilHidden", { fg = c.placeholder })
    hi("OilLink", { fg = c.cyan })
    hi("OilStatusLine", { fg = c.fg, bg = c.surface_alt, bold = true })

    hi("TelescopeNormal", { fg = c.fg, bg = c.bg })
    hi("TelescopeBorder", { fg = c.border, bg = c.bg })
    hi("TelescopeTitle", { fg = c.accent, bg = c.bg, bold = true })
    hi("TelescopePromptNormal", { fg = c.fg, bg = c.surface })
    hi("TelescopePromptBorder", { fg = c.border_focused, bg = c.surface })
    hi("TelescopePromptPrefix", { fg = c.accent, bg = c.surface })
    hi("TelescopeSelection", { fg = c.text, bg = c.element_active })
    hi("TelescopeMatching", { fg = c.match, bold = true })

    hi("CmpItemAbbr", { fg = c.fg })
    hi("CmpItemAbbrDeprecated", { fg = c.predictive, strikethrough = true })
    hi("BlinkCmpGhostText", { fg = c.predictive })
    hi("CmpItemAbbrMatch", { fg = c.accent, bold = true })
    hi("CmpItemAbbrMatchFuzzy", { fg = c.accent, bold = true })
    hi("CmpItemKind", { fg = c.syntax_type })
    hi("CmpItemKindFunction", { fg = c.syntax_function })
    hi("CmpItemKindMethod", { fg = c.syntax_function })
    hi("CmpItemKindVariable", { fg = c.syntax_primary })
    hi("CmpItemKindField", { fg = c.syntax_property })
    hi("CmpItemKindProperty", { fg = c.syntax_property })
    hi("CmpItemKindKeyword", { fg = c.syntax_keyword })
    hi("CmpItemKindText", { fg = c.fg })
    hi("CmpItemKindSnippet", { fg = c.magenta })
    hi("CmpItemMenu", { fg = c.muted })

    hi("WhichKey", { fg = c.accent })
    hi("WhichKeyGroup", { fg = c.magenta })
    hi("WhichKeyDesc", { fg = c.fg })
    hi("WhichKeySeparator", { fg = c.placeholder })
    hi("WhichKeyValue", { fg = c.muted })
    hi("WhichKeyFloat", { bg = c.bg })
    hi("WhichKeyBorder", { fg = c.border, bg = c.bg })

    hi("LazyNormal", { fg = c.fg, bg = c.bg })
    hi("LazyButton", { fg = c.fg, bg = c.element_hover })
    hi("LazyButtonActive", { fg = c.text, bg = c.element_active, bold = true })
    hi("LazyH1", { fg = c.on_accent, bg = c.accent, bold = true })
    hi("LazyH2", { fg = c.accent, bold = true })
    hi("LazySpecial", { fg = c.syntax_special })
    hi("LazyReasonPlugin", { fg = c.magenta })
    hi("LazyReasonRuntime", { fg = c.cyan })
    hi("LazyProgressDone", { fg = c.success })
    hi("LazyProgressTodo", { fg = c.border })

    hi("MasonNormal", { fg = c.fg, bg = c.bg })
    hi("MasonHeader", { fg = c.on_accent, bg = c.accent, bold = true })
    hi("MasonHeaderSecondary", { fg = c.on_accent, bg = c.magenta, bold = true })
    hi("MasonHighlight", { fg = c.accent })
    hi("MasonHighlightBlock", { fg = c.on_accent, bg = c.accent })
    hi("MasonMuted", { fg = c.muted })
    hi("MasonError", { fg = c.error })
    hi("MasonWarning", { fg = c.warning })

    hi("TroubleNormal", { fg = c.fg, bg = c.bg })
    hi("TroubleText", { fg = c.fg })
    hi("TroubleCount", { fg = c.magenta, bg = c.surface })
    hi("TroublePreview", { bg = c.element_active })
    hi("TroubleIndent", { fg = c.indent_guide })
    hi("TroubleCode", { fg = c.muted })

    hi("NeoTreeNormal", { fg = c.fg, bg = c.bg })
    hi("NeoTreeNormalNC", { fg = c.fg, bg = c.bg })
    hi("NeoTreeDirectoryIcon", { fg = c.accent })
    hi("NeoTreeDirectoryName", { fg = c.accent })
    hi("NeoTreeFileName", { fg = c.fg })
    hi("NeoTreeRootName", { fg = c.text, bold = true })
    hi("NeoTreeIndentMarker", { fg = c.indent_guide })
    hi("NeoTreeGitAdded", { fg = c.diff_add })
    hi("NeoTreeGitModified", { fg = c.diff_change })
    hi("NeoTreeGitDeleted", { fg = c.diff_delete })
    hi("NeoTreeGitUntracked", { fg = c.syntax_boolean })
    hi("NeoTreeGitIgnored", { fg = c.placeholder })

    hi("NvimTreeNormal", { fg = c.fg, bg = c.bg })
    hi("NvimTreeFolderIcon", { fg = c.accent })
    hi("NvimTreeFolderName", { fg = c.accent })
    hi("NvimTreeOpenedFolderName", { fg = c.accent, bold = true })
    hi("NvimTreeFileName", { fg = c.fg })
    hi("NvimTreeRootFolder", { fg = c.text, bold = true })
    hi("NvimTreeIndentMarker", { fg = c.indent_guide })
    hi("NvimTreeGitNew", { fg = c.diff_add })
    hi("NvimTreeGitDirty", { fg = c.diff_change })
    hi("NvimTreeGitDeleted", { fg = c.diff_delete })
    hi("NvimTreeGitIgnored", { fg = c.placeholder })

    hi("SnacksPicker", { fg = c.fg, bg = c.bg })
    hi("SnacksPickerNormal", { fg = c.fg, bg = c.bg })
    hi("SnacksPickerBorder", { fg = c.border, bg = c.bg })
    hi("SnacksPickerTitle", { fg = c.accent, bg = c.bg, bold = true })
    hi("SnacksPickerMatch", { fg = c.match, bold = true })
    hi("SnacksPickerCursorLine", { bg = c.element_active })
    hi("SnacksPickerDir", { fg = c.muted })
    hi("SnacksPickerFile", { fg = c.fg })

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
    hi("@lsp.type.parameter", styled({ fg = c.syntax_primary }, styles.variables))
    hi("@lsp.type.property", { fg = c.syntax_property })
    hi("@lsp.type.property.readonly", { link = "Constant" })
    hi("@lsp.type.struct", { link = "Type" })
    hi("@lsp.type.type", { link = "Type" })
    hi("@lsp.type.typeParameter", { link = "Type" })
    hi("@lsp.type.variable", styled({ fg = c.syntax_primary }, styles.variables))
    hi("@lsp.type.variable.readonly", { link = "Constant" })
    hi("@lsp.typemod.variable.static", { link = "Constant" })
    hi("@lsp.typemod.property.static", { link = "Constant" })

    hi("FlumeDottedNamespace", { fg = c.syntax_namespace })
    hi("FlumeTypeLikeNamespace", styled({ fg = c.syntax_type }, styles.types))

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

    if M.config.terminal_colors then
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
    else
        for i = 0, 15 do
            vim.g["terminal_color_" .. i] = nil
        end
    end

    for group, opts in pairs(M.config.highlights or {}) do
        if type(opts) == "function" then
            opts = opts(c)
        end
        if opts then
            hi(group, opts)
        end
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
