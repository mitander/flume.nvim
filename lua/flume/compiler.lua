local M = {}

local uv = vim.uv or vim.loop

local function normalize_schema(schema)
    return require("flume.palette").resolve(schema or "dusk")
end

local function get_schema(schema)
    return require("flume.palette").get(normalize_schema(schema))
end

local function get_palette(schema)
    return get_schema(schema).colors
end

local function schema_suffix(schema)
    return get_schema(schema).suffix
end

local function is_light(schema)
    return get_schema(schema).appearance == "light"
end

local function get_plugin_dir()
    local source = debug.getinfo(1).source:sub(2)
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
end

local function write_file_if_changed(path, content)
    local existing = nil
    local current = io.open(path, "rb")
    if current then
        existing = current:read("*a")
        current:close()
    end

    if existing == content then
        return false
    end

    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    local temporary = path .. ".flume-" .. tostring(uv.hrtime())
    local file = io.open(temporary, "wb")
    if not file then
        error("Could not write temporary file for: " .. path)
    end
    local written, write_error = file:write(content)
    if not written then
        file:close()
        uv.fs_unlink(temporary)
        error("Could not write temporary file for " .. path .. ": " .. tostring(write_error))
    end
    local closed, close_error = file:close()
    if not closed then
        uv.fs_unlink(temporary)
        error("Could not flush temporary file for " .. path .. ": " .. tostring(close_error))
    end

    local renamed, rename_error = uv.fs_rename(temporary, path)
    if not renamed then
        uv.fs_unlink(temporary)
        error("Could not atomically replace " .. path .. ": " .. tostring(rename_error))
    end
    return true
end

local function hex_to_rgb(hex)
    hex = hex:gsub("#", "")
    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

-- Initialize xterm-256 color lookup table
local xterm_palette = {}
local ansi_colors = {
    { 0, 0, 0 },
    { 128, 0, 0 },
    { 0, 128, 0 },
    { 128, 128, 0 },
    { 0, 0, 128 },
    { 128, 0, 128 },
    { 0, 128, 128 },
    { 192, 192, 192 },
    { 128, 128, 128 },
    { 255, 0, 0 },
    { 0, 255, 0 },
    { 255, 255, 0 },
    { 0, 0, 255 },
    { 255, 0, 255 },
    { 0, 255, 255 },
    { 255, 255, 255 },
}
for i = 1, 16 do
    xterm_palette[i - 1] = ansi_colors[i]
end
local steps = { 0, 95, 135, 175, 215, 255 }
for r = 0, 5 do
    for g = 0, 5 do
        for b = 0, 5 do
            local idx = 16 + 36 * r + 6 * g + b
            xterm_palette[idx] = { steps[r + 1], steps[g + 1], steps[b + 1] }
        end
    end
end
for g = 0, 23 do
    local val = 8 + 10 * g
    local idx = 232 + g
    xterm_palette[idx] = { val, val, val }
end

local function rgb_distance(r1, g1, b1, r2, g2, b2)
    return (r1 - r2) ^ 2 + (g1 - g2) ^ 2 + (b1 - b2) ^ 2
end

local function hex_to_xterm(hex)
    local r, g, b = hex_to_rgb(hex)
    local min_dist = math.huge
    local closest_idx = 0
    for idx, rgb in pairs(xterm_palette) do
        local dist = rgb_distance(r, g, b, rgb[1], rgb[2], rgb[3])
        if dist < min_dist then
            min_dist = dist
            closest_idx = idx
        end
    end
    return closest_idx
end

function M.compile_ghostty(schema)
    local palette = get_palette(schema)
    local selection_foreground = is_light(schema) and palette.on_accent or palette.fg
    local template = [[# Flume Theme for Ghostty
background = %s
foreground = %s
selection-background = %s
selection-foreground = %s
cursor-color = %s
cursor-text = %s

palette = 0=%s
palette = 1=%s
palette = 2=%s
palette = 3=%s
palette = 4=%s
palette = 5=%s
palette = 6=%s
palette = 7=%s
palette = 8=%s
palette = 9=%s
palette = 10=%s
palette = 11=%s
palette = 12=%s
palette = 13=%s
palette = 14=%s
palette = 15=%s
]]
    local content = string.format(
        template,
        palette.terminal_bg,
        palette.fg,
        palette.black, -- selection-background
        selection_foreground,
        palette.accent,
        palette.on_accent, -- cursor-text
        palette.black,
        palette.red,
        palette.green,
        palette.yellow,
        palette.blue,
        palette.magenta,
        palette.cyan,
        palette.white,
        palette.bright_black,
        palette.bright_red,
        palette.bright_green,
        palette.bright_yellow,
        palette.bright_blue,
        palette.bright_magenta,
        palette.bright_cyan,
        palette.bright_white
    )

    local path = get_plugin_dir() .. "/extras/ghostty/flume" .. schema_suffix(schema)
    return write_file_if_changed(path, content)
end

function M.compile_kitty(schema)
    local palette = get_palette(schema)
    local selection_foreground = is_light(schema) and palette.on_accent or palette.fg
    local template = [[# Flume Theme for Kitty
background            %s
foreground            %s
selection_background  %s
selection_foreground  %s
cursor                %s
cursor_text_color     %s

# Black
color0  %s
color8  %s

# Red
color1  %s
color9  %s

# Green
color2  %s
color10 %s

# Yellow
color3  %s
color11 %s

# Blue
color4  %s
color12 %s

# Magenta
color5  %s
color13 %s

# Cyan
color6  %s
color14 %s

# White
color7  %s
color15 %s

# Tab bar
tab_bar_background        %s
tab_bar_margin_color      %s
active_tab_foreground     %s
active_tab_background     %s
active_tab_font_style     bold
inactive_tab_foreground   %s
inactive_tab_background   %s
inactive_tab_font_style   normal
]]
    local content = string.format(
        template,
        palette.terminal_bg,
        palette.fg,
        palette.black, -- selection_background
        selection_foreground,
        palette.accent,
        palette.on_accent, -- cursor_text_color
        palette.black,
        palette.bright_black,
        palette.red,
        palette.bright_red,
        palette.green,
        palette.bright_green,
        palette.yellow,
        palette.bright_yellow,
        palette.blue,
        palette.bright_blue,
        palette.magenta,
        palette.bright_magenta,
        palette.cyan,
        palette.bright_cyan,
        palette.white,
        palette.bright_white,
        palette.surface,          -- tab_bar_background
        palette.surface,          -- tab_bar_margin_color
        palette.fg,               -- active_tab_foreground
        palette.element_active,   -- active_tab_background
        palette.muted,            -- inactive_tab_foreground
        palette.surface           -- inactive_tab_background
    )

    local path = get_plugin_dir() .. "/extras/kitty/flume" .. schema_suffix(schema) .. ".conf"
    return write_file_if_changed(path, content)
end

function M.compile_tmux(schema)
    local palette = get_palette(schema)
    local template = [[# Flume tmux color variables.

%%hidden thm_bg="%s"
%%hidden thm_fg="%s"
%%hidden thm_black="%s"
%%hidden thm_gray="%s"
%%hidden thm_lgray="%s"
%%hidden thm_accent="%s"
%%hidden thm_red="%s"
%%hidden thm_green="%s"
%%hidden thm_yellow="%s"
%%hidden thm_blue="%s"
%%hidden thm_pink="%s"
%%hidden thm_cyan="%s"
%%hidden thm_orange="%s"
]]
    local content = string.format(
        template,
        palette.bg,
        palette.fg,
        palette.black,
        palette.black, -- thm_gray
        palette.placeholder,
        palette.accent,
        palette.red,
        palette.green,
        palette.yellow,
        palette.blue,
        palette.magenta,
        palette.cyan,
        palette.bright_red -- thm_orange
    )

    local path = get_plugin_dir() .. "/extras/tmux/colors" .. schema_suffix(schema) .. ".conf"
    return write_file_if_changed(path, content)
end

function M.compile_lsd(schema)
    local palette = get_palette(schema)
    local light = is_light(schema)
    local permission_read = palette.muted
    local permission_write = light and palette.muted or palette.yellow
    local permission_exec = light and palette.muted or palette.green
    local metadata = palette.muted
    local template = [[# Flume colors for lsd.
# lsd color themes only style metadata; file names continue to use LS_COLORS.
# Numeric values are xterm-256 approximations supported by crossterm.

user: %d              # muted (%s)
group: %d             # muted (%s)

permission:
  read: %d             # quiet metadata (%s)
  write: %d            # quiet metadata (%s)
  exec: %d             # quiet metadata (%s)
  exec-sticky: %d      # error (%s)
  no-access: %d        # placeholder (%s)
  octal: %d            # muted (%s)
  acl: %d              # accent (%s)
  context: %d          # doc_comment (%s)

date:
  hour-old: %d         # muted (%s)
  day-old: %d          # muted (%s)
  older: %d            # placeholder (%s)

size:
  none: %d             # placeholder (%s)
  small: %d            # muted (%s)
  medium: %d           # muted (%s)
  large: %d            # warning (%s)

inode:
  valid: %d            # muted (%s)
  invalid: %d          # placeholder (%s)

links:
  valid: %d            # muted (%s)
  invalid: %d          # placeholder (%s)

tree-edge: %d          # border_variant (%s)

git-status:
  default: %d          # placeholder (%s)
  unmodified: %d       # placeholder (%s)
  ignored: %d          # placeholder (%s)
  new-in-index: %d     # success (%s)
  new-in-workdir: %d   # success (%s)
  typechange: %d       # warning (%s)
  deleted: %d          # error (%s)
  renamed: %d          # accent (%s)
  modified: %d         # warning (%s)
  conflicted: %d       # error (%s)
]]

    local args = {}
    local function add(value)
        args[#args + 1] = hex_to_xterm(value)
        args[#args + 1] = value
    end

    for _, value in ipairs({
        metadata,
        metadata,
        permission_read,
        permission_write,
        permission_exec,
        palette.error,
        palette.placeholder,
        metadata,
        palette.accent,
        palette.syntax_doc_comment,
        metadata,
        metadata,
        palette.placeholder,
        palette.placeholder,
        metadata,
        metadata,
        palette.warning,
        metadata,
        palette.placeholder,
        metadata,
        palette.placeholder,
        palette.border_variant,
        palette.placeholder,
        palette.placeholder,
        palette.placeholder,
        palette.success,
        palette.success,
        palette.warning,
        palette.error,
        palette.accent,
        palette.warning,
        palette.error,
    }) do
        add(value)
    end

    local content = string.format(template, unpack(args))

    local path = get_plugin_dir() .. "/extras/lsd/colors" .. schema_suffix(schema) .. ".yaml"
    return write_file_if_changed(path, content)
end

function M.compile_pi(schema)
    local schema_meta = get_schema(schema)
    local palette = schema_meta.colors
    local template = [[{
  "$schema": "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
  "name": "%s",
  "vars": {
    "bg": "%s",
    "surface": "%s",
    "surfaceAlt": "%s",
    "elementActive": "%s",
    "border": "%s",
    "borderMuted": "%s",
    "fg": "%s",
    "softFg": "%s",
    "muted": "%s",
    "dim": "%s",
    "accent": "%s",
    "blue": "%s",
    "cyan": "%s",
    "green": "%s",
    "yellow": "%s",
    "red": "%s",
    "success": "%s",
    "error": "%s",
    "diffAdd": "%s",
    "diffDelete": "%s",
    "pink": "%s",
    "magenta": "%s",
    "property": "%s",
    "punctuation": "%s",
    "punctuationMuted": "%s",
    "diffAddBg": "%s",
    "diffChangeBg": "%s",
    "diffDeleteBg": "%s",
    "warnBg": "%s"
  },
  "colors": {
    "accent": "accent",
    "border": "border",
    "borderAccent": "cyan",
    "borderMuted": "borderMuted",
    "success": "success",
    "error": "error",
    "warning": "yellow",
    "muted": "muted",
    "dim": "dim",
    "text": "fg",
    "thinkingText": "muted",

    "selectedBg": "surfaceAlt",
    "userMessageBg": "surface",
    "userMessageText": "fg",
    "customMessageBg": "surface",
    "customMessageText": "fg",
    "customMessageLabel": "accent",
    "toolPendingBg": "surfaceAlt",
    "toolSuccessBg": "diffAddBg",
    "toolErrorBg": "diffDeleteBg",
    "toolTitle": "accent",
    "toolOutput": "softFg",

    "mdHeading": "accent",
    "mdLink": "blue",
    "mdLinkUrl": "cyan",
    "mdCode": "cyan",
    "mdCodeBlock": "softFg",
    "mdCodeBlockBorder": "borderMuted",
    "mdQuote": "muted",
    "mdQuoteBorder": "borderMuted",
    "mdHr": "borderMuted",
    "mdListBullet": "cyan",

    "toolDiffAdded": "diffAdd",
    "toolDiffRemoved": "diffDelete",
    "toolDiffContext": "muted",

    "syntaxComment": "dim",
    "syntaxKeyword": "magenta",
    "syntaxFunction": "blue",
    "syntaxVariable": "fg",
    "syntaxString": "green",
    "syntaxNumber": "pink",
    "syntaxType": "yellow",
    "syntaxOperator": "cyan",
    "syntaxPunctuation": "punctuationMuted",

    "thinkingOff": "dim",
    "thinkingMinimal": "borderMuted",
    "thinkingLow": "border",
    "thinkingMedium": "muted",
    "thinkingHigh": "border",
    "thinkingXhigh": "magenta",

    "bashMode": "yellow"
  },
  "export": {
    "pageBg": "bg",
    "cardBg": "surface",
    "infoBg": "diffChangeBg"
  }
}
]]
    local content = string.format(
        template,
        schema_meta.integration_name,
        palette.bg,
        palette.surface,
        palette.surface_alt,
        palette.element_active,
        palette.border,
        palette.border_variant,
        palette.syntax_primary,
        palette.fg,
        palette.muted,
        palette.syntax_comment,
        palette.accent,
        palette.syntax_function,
        palette.cyan,
        palette.syntax_string,
        palette.syntax_type,
        palette.red,
        palette.success,
        palette.error,
        palette.diff_add,
        palette.diff_delete,
        palette.syntax_boolean,
        palette.syntax_keyword,
        palette.syntax_property,
        palette.syntax_punctuation,
        palette.syntax_punctuation_bracket,
        palette.diff_add_bg,
        palette.diff_change_bg,
        palette.diff_delete_bg,
        palette.warn_bg
    )

    local path = get_plugin_dir() .. "/extras/pi/flume" .. schema_suffix(schema) .. ".json"
    return write_file_if_changed(path, content)
end

function M.compile_lazygit(schema)
    local palette = get_palette(schema)
    local template = [[# Generated by Flume. Load after your base Lazygit config.
gui:
  theme:
    activeBorderColor: ["%s", bold]
    inactiveBorderColor: ["%s"]
    searchingActiveBorderColor: ["%s", bold]
    optionsTextColor: ["%s"]
    selectedLineBgColor: ["%s"]
    inactiveViewSelectedLineBgColor: ["%s"]
    cherryPickedCommitBgColor: ["%s"]
    cherryPickedCommitFgColor: ["%s"]
    unstagedChangesColor: ["%s"]
    defaultFgColor: ["%s"]
git:
  pagers:
    - colorArg: always
      pager: 'delta --%s --features="" --paging=never --syntax-theme=ansi --minus-style="syntax %s" --minus-emph-style="syntax %s" --plus-style="syntax %s" --plus-emph-style="syntax %s" --line-numbers --line-numbers-minus-style=%s --line-numbers-plus-style=%s --line-numbers-left-style=%s --line-numbers-right-style=%s'
]]
    local content = string.format(
        template,
        palette.border_focused,
        palette.border,
        palette.match,
        palette.muted,
        palette.element_active,
        palette.active_line,
        palette.element_active,
        palette.syntax_keyword,
        palette.diff_delete,
        palette.syntax_primary,
        is_light(schema) and "light" or "dark",
        palette.diff_delete_bg,
        palette.diff_delete_emphasis,
        palette.diff_add_bg,
        palette.diff_add_emphasis,
        palette.diff_delete,
        palette.diff_add,
        palette.border,
        palette.border
    )

    return write_file_if_changed(get_plugin_dir() .. "/extras/lazygit/flume" .. schema_suffix(schema) .. ".yml", content)
end

function M.compile_fzf(schema)
    local palette = get_palette(schema)
    local colors = {
        "fg:" .. palette.fg,
        "bg:" .. palette.bg,
        "hl:" .. palette.match,
        "fg+:" .. palette.text,
        "bg+:" .. palette.element_active,
        "hl+:" .. palette.match,
        "info:" .. palette.muted,
        "prompt:" .. palette.accent,
        "pointer:" .. palette.error,
        "marker:" .. palette.success,
        "spinner:" .. palette.syntax_keyword,
        "header:" .. palette.muted,
        "border:" .. palette.border,
        "gutter:" .. palette.bg,
        "query:" .. palette.text,
    }
    local opts = "--no-bold --color=" .. table.concat(colors, ",")
    local path = get_plugin_dir() .. "/extras/fzf/flume" .. schema_suffix(schema) .. ".opts"
    return write_file_if_changed(path, opts .. "\n")
end

function M.compile_delta(schema)
    local palette = get_palette(schema)
    local template = [[# Generated by Flume.
[delta]
    light = %s
    features = flume
    syntax-theme = ansi

[delta "flume"]
    minus-style = syntax "%s"
    minus-emph-style = syntax "%s"
    plus-style = syntax "%s"
    plus-emph-style = syntax "%s"
    line-numbers = true
    line-numbers-minus-style = "%s"
    line-numbers-plus-style = "%s"
    line-numbers-left-style = "%s"
    line-numbers-right-style = "%s"
    commit-decoration-style = "%s" box
    file-style = "%s"
    file-decoration-style = "%s" ul
    hunk-header-style = "%s"
    hunk-header-decoration-style = "%s" box
]]
    local content = string.format(
        template,
        is_light(schema) and "true" or "false",
        palette.diff_delete_bg,
        palette.diff_delete_emphasis,
        palette.diff_add_bg,
        palette.diff_add_emphasis,
        palette.diff_delete,
        palette.diff_add,
        palette.border,
        palette.border,
        palette.accent,
        palette.syntax_primary,
        palette.accent,
        palette.syntax_primary,
        palette.border
    )

    return write_file_if_changed(get_plugin_dir() .. "/extras/delta/flume" .. schema_suffix(schema) .. ".gitconfig", content)
end

function M.compile_tuxedo(schema)
    local schema_meta = get_schema(schema)
    local palette = schema_meta.colors
    local template = [[# Generated by Flume for Tuxedo.
name = %s
bg = %s
panel = %s
border = %s
fg = %s
dim = %s
accent = %s
cursor = %s
selection = %s
statusbar = %s
status_fg = %s
mode_fg = %s
mode_bg = %s
pri_a = %s
pri_b = %s
pri_c = %s
pri_d = %s
pri_other = %s
project = %s
context = %s
due = %s
overdue = %s
today = %s
done = %s
selected = %s
matched = %s
]]
    local content = string.format(
        template,
        schema_meta.display_name,
        palette.bg,
        palette.surface,
        palette.border,
        palette.syntax_primary,
        palette.muted,
        palette.accent,
        palette.element_active,
        palette.element_active,
        palette.surface_alt,
        palette.text,
        palette.bg,
        palette.accent,
        palette.red,
        palette.syntax_type,
        palette.syntax_string,
        palette.syntax_function,
        palette.syntax_keyword,
        palette.cyan,
        palette.syntax_keyword,
        palette.syntax_type,
        palette.red,
        palette.bright_red,
        palette.syntax_comment,
        palette.element_active,
        palette.syntax_type
    )

    local path = get_plugin_dir() .. "/extras/tuxedo/flume" .. schema_suffix(schema) .. ".toml"
    return write_file_if_changed(path, content)
end

function M.compile_opencode(schema)
    local palette = get_palette(schema)
    local template = [[{
  "$schema": "https://opencode.ai/theme.json",
  "defs": {
    "bg":                    "%s",
    "surface":               "%s",
    "element_active":        "%s",
    "fg":                    "%s",
    "muted":                 "%s",
    "placeholder":           "%s",
    "accent":                "%s",
    "border":                "%s",
    "border_variant":        "%s",
    "border_focused":        "%s",
    "red":                   "%s",
    "bright_red":            "%s",
    "green":                 "%s",
    "bright_green":          "%s",
    "yellow":                "%s",
    "blue":                  "%s",
    "bright_blue":           "%s",
    "cyan":                  "%s",
    "magenta":               "%s",
    "syntax_comment":        "%s",
    "syntax_keyword":        "%s",
    "syntax_function":       "%s",
    "syntax_primary":        "%s",
    "syntax_string":         "%s",
    "syntax_boolean":        "%s",
    "syntax_type":           "%s",
    "syntax_punctuation":    "%s",
    "diff_add_bg":           "%s",
    "diff_delete_bg":        "%s"
  },
  "theme": {
    "primary":                    "accent",
    "secondary":                  "magenta",
    "accent":                     "accent",
    "error":                      "red",
    "warning":                    "yellow",
    "success":                    "green",
    "info":                       "accent",
    "text":                       "fg",
    "textMuted":                  "muted",
    "background":                 "bg",
    "backgroundPanel":            "surface",
    "backgroundElement":          "element_active",
    "border":                     "border",
    "borderActive":               "border_focused",
    "borderSubtle":               "border_variant",
    "diffAdded":                  "green",
    "diffRemoved":                "red",
    "diffContext":                "muted",
    "diffHunkHeader":             "muted",
    "diffHighlightAdded":         "bright_green",
    "diffHighlightRemoved":       "bright_red",
    "diffAddedBg":                "diff_add_bg",
    "diffRemovedBg":              "diff_delete_bg",
    "diffContextBg":              "surface",
    "diffLineNumber":             "placeholder",
    "diffAddedLineNumberBg":      "diff_add_bg",
    "diffRemovedLineNumberBg":    "diff_delete_bg",
    "markdownText":               "fg",
    "markdownHeading":            "accent",
    "markdownLink":               "blue",
    "markdownLinkText":           "bright_blue",
    "markdownCode":               "cyan",
    "markdownBlockQuote":         "placeholder",
    "markdownEmph":               "syntax_boolean",
    "markdownStrong":             "yellow",
    "markdownHorizontalRule":     "border",
    "markdownListItem":           "accent",
    "markdownListEnumeration":    "cyan",
    "markdownImage":              "blue",
    "markdownImageText":          "bright_blue",
    "markdownCodeBlock":          "fg",
    "syntaxComment":              "syntax_comment",
    "syntaxKeyword":              "syntax_keyword",
    "syntaxFunction":             "syntax_function",
    "syntaxVariable":             "syntax_primary",
    "syntaxString":               "syntax_string",
    "syntaxNumber":               "syntax_boolean",
    "syntaxType":                 "syntax_type",
    "syntaxOperator":             "syntax_punctuation",
    "syntaxPunctuation":          "syntax_punctuation"
  }
}
]]
    local content = string.format(
        template,
        palette.bg,
        palette.surface,
        palette.element_active,
        palette.fg,
        palette.muted,
        palette.placeholder,
        palette.accent,
        palette.border,
        palette.border_variant,
        palette.border_focused,
        palette.red,
        palette.bright_red,
        palette.green,
        palette.bright_green,
        palette.yellow,
        palette.blue,
        palette.bright_blue,
        palette.cyan,
        palette.magenta,
        palette.syntax_comment,
        palette.syntax_keyword,
        palette.syntax_function,
        palette.syntax_primary,
        palette.syntax_string,
        palette.syntax_boolean,
        palette.syntax_type,
        palette.syntax_punctuation,
        palette.diff_add_bg,
        palette.diff_delete_bg
    )

    local path = get_plugin_dir() .. "/extras/opencode/flume" .. schema_suffix(schema) .. ".json"
    return write_file_if_changed(path, content)
end

function M.activate(schema)
    schema = normalize_schema(schema)
    require("flume.palette").get(schema)
    local root = get_plugin_dir()
    local suffix = schema_suffix(schema)
    local extras = root .. "/extras"
    local current = extras .. "/current"
    local token = tostring(vim.fn.getpid()) .. "-" .. string.format("%.0f", uv.hrtime())
    local staged_name = ".current-stage-" .. token
    local staged_set = extras .. "/" .. staged_name
    local staged_link = extras .. "/.current-link-" .. token
    local legacy_backup = extras .. "/.current-backup-" .. token
    vim.fn.mkdir(staged_set, "p")

    local function read_all(path)
        local file = assert(io.open(path, "rb"))
        local content = file:read("*a")
        file:close()
        return content
    end

    local ok, result = xpcall(function()
        local manifest = { schema }
        write_file_if_changed(staged_set .. "/schema", schema .. "\n")

        local function copy(source, name)
            local content = read_all(source)
            -- Hash each text artifact before assembling the set identity. Passing
            -- NUL-delimited strings to vim.fn.sha256() becomes a Blob on Neovim
            -- 0.9, where sha256() only accepts String values.
            manifest[#manifest + 1] = name .. ":" .. vim.fn.sha256(content)
            local existing_file = io.open(current .. "/" .. name, "rb")
            local existing = nil
            if existing_file then
                existing = existing_file:read("*a")
                existing_file:close()
            end
            write_file_if_changed(staged_set .. "/" .. name, content)
            return existing ~= content
        end

        local changes = {
            ghostty = copy(root .. "/extras/ghostty/flume" .. suffix, "ghostty"),
            kitty = copy(root .. "/extras/kitty/flume" .. suffix .. ".conf", "kitty.conf"),
            tmux = copy(root .. "/extras/tmux/colors" .. suffix .. ".conf", "tmux.conf"),
            lsd = copy(root .. "/extras/lsd/colors" .. suffix .. ".yaml", "lsd.yaml"),
            opencode = copy(root .. "/extras/opencode/flume" .. suffix .. ".json", "opencode.json"),
            lazygit = copy(root .. "/extras/lazygit/flume" .. suffix .. ".yml", "lazygit.yml"),
            fzf = copy(root .. "/extras/fzf/flume" .. suffix .. ".opts", "fzf.opts"),
            delta = copy(root .. "/extras/delta/flume" .. suffix .. ".gitconfig", "delta.gitconfig"),
            pi = copy(root .. "/extras/pi/flume" .. suffix .. ".json", "pi.json"),
            tuxedo = copy(root .. "/extras/tuxedo/flume" .. suffix .. ".toml", "tuxedo.toml"),
        }

        local set_name = ".current-set-" .. schema .. "-" .. vim.fn.sha256(table.concat(manifest, "\n")):sub(1, 16)
        local set_path = extras .. "/" .. set_name
        local promoted, promote_error = uv.fs_rename(staged_set, set_path)
        if not promoted then
            if not uv.fs_stat(set_path) then
                error("Could not promote the staged integration set: " .. tostring(promote_error))
            end

            local names = {
                "schema",
                "ghostty",
                "kitty.conf",
                "tmux.conf",
                "lsd.yaml",
                "opencode.json",
                "lazygit.yml",
                "fzf.opts",
                "delta.gitconfig",
                "pi.json",
                "tuxedo.toml",
            }
            local identical = true
            for _, name in ipairs(names) do
                local existing_ok, existing = pcall(read_all, set_path .. "/" .. name)
                if not existing_ok or existing ~= read_all(staged_set .. "/" .. name) then
                    identical = false
                    break
                end
            end

            if identical then
                vim.fn.delete(staged_set, "rf")
            else
                -- Recover from a stale/corrupt immutable set left by an older
                -- activator without disturbing a current symlink that may use it.
                set_name = set_name .. "-" .. token
                set_path = extras .. "/" .. set_name
                local recovered, recover_error = uv.fs_rename(staged_set, set_path)
                if not recovered then
                    error("Could not promote recovered integration set: " .. tostring(recover_error))
                end
            end
        end

        local linked, link_error = uv.fs_symlink(set_name, staged_link, { dir = true, junction = false })
        if not linked then
            error("Could not stage the active integration link: " .. tostring(link_error))
        end

        local current_stat = uv.fs_lstat(current)
        local migrated_directory = current_stat and current_stat.type == "directory"
        if migrated_directory then
            local moved, move_error = uv.fs_rename(current, legacy_backup)
            if not moved then
                error("Could not migrate the previous integration directory: " .. tostring(move_error))
            end
        end

        local swapped, swap_error = uv.fs_rename(staged_link, current)
        if not swapped then
            if migrated_directory then
                local restored, restore_error = uv.fs_rename(legacy_backup, current)
                if not restored then
                    error(
                        "Could not activate integration set ("
                            .. tostring(swap_error)
                            .. ") or restore the previous set ("
                            .. tostring(restore_error)
                            .. ")"
                    )
                end
            end
            error("Could not activate integration set: " .. tostring(swap_error))
        end

        if migrated_directory then
            vim.fn.delete(legacy_backup, "rf")
        end
        for name, kind in vim.fs.dir(extras) do
            if kind == "directory" and name:match("^%.current%-set%-") and name ~= set_name then
                vim.fn.delete(extras .. "/" .. name, "rf")
            end
        end
        return changes
    end, debug.traceback)

    if uv.fs_lstat(staged_link) then
        uv.fs_unlink(staged_link)
    end
    if not ok and uv.fs_stat(staged_set) then
        vim.fn.delete(staged_set, "rf")
    end
    if uv.fs_stat(legacy_backup) and not uv.fs_lstat(current) then
        local restored, restore_error = uv.fs_rename(legacy_backup, current)
        if not restored then
            error(result .. "\nCould not restore previous integrations: " .. tostring(restore_error))
        end
    end

    if not ok then
        error(result)
    end
    return result
end

local function count_changes(changes)
    local count = 0
    for _, changed in pairs(changes) do
        if changed then
            count = count + 1
        end
    end
    return count
end

function M.compile_all(opts)
    opts = opts or {}
    local changed = {}
    local compilers = { "ghostty", "kitty", "tmux", "lsd", "opencode", "lazygit", "fzf", "delta", "pi", "tuxedo" }
    local schemas = require("flume.palette").schema_order
    local paths = {
        ghostty = "extras/ghostty/flume%s",
        kitty = "extras/kitty/flume%s.conf",
        tmux = "extras/tmux/colors%s.conf",
        lsd = "extras/lsd/colors%s.yaml",
        opencode = "extras/opencode/flume%s.json",
        lazygit = "extras/lazygit/flume%s.yml",
        fzf = "extras/fzf/flume%s.opts",
        delta = "extras/delta/flume%s.gitconfig",
        pi = "extras/pi/flume%s.json",
        tuxedo = "extras/tuxedo/flume%s.toml",
    }

    for _, schema in ipairs(schemas) do
        local suffix = schema_suffix(schema)
        for _, name in ipairs(compilers) do
            changed[paths[name]:format(suffix)] = M["compile_" .. name](schema)
        end
    end

    local count = count_changes(changed)
    local activated = {}
    if opts.activate ~= false then
        activated = M.activate(opts.schema or "dusk")
        count = count + count_changes(activated)
    end
    changed.current = activated
    changed.count = count
    changed.any = count > 0

    if not opts.quiet then
        if changed.any then
            local artifacts = {}
            for name, did_change in pairs(changed) do
                if name ~= "current" and name ~= "count" and name ~= "any" and did_change == true then
                    artifacts[#artifacts + 1] = name
                end
            end
            table.sort(artifacts)
            print("Flume extras compiled: " .. count .. " file(s) updated: " .. table.concat(artifacts, ", "))
        else
            print("Flume extras already up to date")
        end
    end

    return changed
end

return M
