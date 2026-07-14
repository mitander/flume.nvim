local M = {}

local function get_palette()
    return require("flume.palette").colors
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
    local file = io.open(path, "wb")
    if not file then
        error("Could not write to file: " .. path)
    end
    file:write(content)
    file:close()
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

function M.compile_ghostty()
    local palette = get_palette()
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
        palette.fg, -- selection-foreground
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

    local path = get_plugin_dir() .. "/extras/ghostty/flume"
    return write_file_if_changed(path, content)
end

function M.compile_kitty()
    local palette = get_palette()
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
        palette.fg, -- selection_foreground
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

    local path = get_plugin_dir() .. "/extras/kitty/flume.conf"
    return write_file_if_changed(path, content)
end

function M.compile_tmux()
    local palette = get_palette()
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

    local path = get_plugin_dir() .. "/extras/tmux/colors.conf"
    return write_file_if_changed(path, content)
end

function M.compile_lsd()
    local palette = get_palette()
    local template = [[# Flume colors for lsd.
# lsd 1.1.x uses crossterm color values; use xterm-256 approximations
# instead of #RRGGBB so the theme is actually applied.

name:
  file: %d            # syntax_primary (%s)
  dir: %d             # accent (%s)
  pipe: %d            # cyan (%s)
  symlink: %d         # cyan (%s)
  block-device: %d    # magenta (%s)
  char-device: %d     # magenta (%s)
  socket: %d          # magenta (%s)
  special: %d         # syntax_special (%s)

user: %d              # muted (%s)
group: %d             # placeholder/comment (%s)

permission:
  read: %d            # muted (%s)
  write: %d           # yellow (%s)
  exec: %d            # green (%s)
  exec-sticky: %d     # magenta (%s)
  no-access: %d       # placeholder/comment (%s)
  octal: %d           # bright_blue (%s)
  acl: %d             # cyan (%s)
  context: %d         # doc_comment (%s)

date:
  hour-old: %d        # syntax_primary (%s)
  day-old: %d         # muted (%s)
  older: %d           # placeholder/comment (%s)

size:
  none: %d            # placeholder/comment (%s)
  small: %d           # muted (%s)
  medium: %d          # cyan (%s)
  large: %d           # yellow (%s)

inode:
  valid: %d           # muted (%s)
  invalid: %d         # placeholder/comment (%s)

links:
  valid: %d           # muted (%s)
  invalid: %d         # placeholder/comment (%s)

tree-edge: %d         # border_variant (%s)

git-status:
  default: %d         # placeholder/comment (%s)
  unmodified: %d      # placeholder/comment (%s)
  ignored: %d         # placeholder/comment (%s)
  new-in-index: %d    # green (%s)
  new-in-workdir: %d  # green (%s)
  typechange: %d      # yellow (%s)
  deleted: %d         # red (%s)
  renamed: %d         # accent (%s)
  modified: %d        # yellow (%s)
  conflicted: %d      # bright_red (%s)
]]

    local content = string.format(
        template,
        hex_to_xterm(palette.syntax_primary),
        palette.syntax_primary,
        hex_to_xterm(palette.accent),
        palette.accent,
        hex_to_xterm(palette.cyan),
        palette.cyan,
        hex_to_xterm(palette.cyan),
        palette.cyan,
        hex_to_xterm(palette.magenta),
        palette.magenta,
        hex_to_xterm(palette.magenta),
        palette.magenta,
        hex_to_xterm(palette.magenta),
        palette.magenta,
        hex_to_xterm(palette.syntax_special),
        palette.syntax_special,

        hex_to_xterm(palette.muted),
        palette.muted,
        hex_to_xterm(palette.placeholder),
        palette.placeholder,

        hex_to_xterm(palette.muted),
        palette.muted,
        hex_to_xterm(palette.yellow),
        palette.yellow,
        hex_to_xterm(palette.green),
        palette.green,
        hex_to_xterm(palette.magenta),
        palette.magenta,
        hex_to_xterm(palette.placeholder),
        palette.placeholder,
        hex_to_xterm(palette.bright_blue),
        palette.bright_blue,
        hex_to_xterm(palette.cyan),
        palette.cyan,
        hex_to_xterm(palette.syntax_doc_comment),
        palette.syntax_doc_comment,

        hex_to_xterm(palette.syntax_primary),
        palette.syntax_primary,
        hex_to_xterm(palette.muted),
        palette.muted,
        hex_to_xterm(palette.placeholder),
        palette.placeholder,

        hex_to_xterm(palette.placeholder),
        palette.placeholder,
        hex_to_xterm(palette.muted),
        palette.muted,
        hex_to_xterm(palette.cyan),
        palette.cyan,
        hex_to_xterm(palette.yellow),
        palette.yellow,

        hex_to_xterm(palette.muted),
        palette.muted,
        hex_to_xterm(palette.placeholder),
        palette.placeholder,

        hex_to_xterm(palette.muted),
        palette.muted,
        hex_to_xterm(palette.placeholder),
        palette.placeholder,

        hex_to_xterm(palette.border_variant),
        palette.border_variant,

        hex_to_xterm(palette.placeholder),
        palette.placeholder,
        hex_to_xterm(palette.placeholder),
        palette.placeholder,
        hex_to_xterm(palette.placeholder),
        palette.placeholder,
        hex_to_xterm(palette.green),
        palette.green,
        hex_to_xterm(palette.green),
        palette.green,
        hex_to_xterm(palette.yellow),
        palette.yellow,
        hex_to_xterm(palette.red),
        palette.red,
        hex_to_xterm(palette.accent),
        palette.accent,
        hex_to_xterm(palette.yellow),
        palette.yellow,
        hex_to_xterm(palette.bright_red),
        palette.bright_red
    )

    local path = get_plugin_dir() .. "/extras/lsd/colors.yaml"
    return write_file_if_changed(path, content)
end

function M.compile_pi()
    local palette = get_palette()
    local template = [[{
  "$schema": "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
  "name": "flume",
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
    "success": "green",
    "error": "red",
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

    "mdHeading": "property",
    "mdLink": "blue",
    "mdLinkUrl": "cyan",
    "mdCode": "cyan",
    "mdCodeBlock": "softFg",
    "mdCodeBlockBorder": "borderMuted",
    "mdQuote": "muted",
    "mdQuoteBorder": "borderMuted",
    "mdHr": "borderMuted",
    "mdListBullet": "cyan",

    "toolDiffAdded": "green",
    "toolDiffRemoved": "red",
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

    local path = get_plugin_dir() .. "/extras/pi/flume.json"
    return write_file_if_changed(path, content)
end

function M.compile_tuxedo()
    local palette = get_palette()
    local template = [[# Flume theme for Tuxedo.
name = Flume
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

    local path = get_plugin_dir() .. "/extras/tuxedo/flume.toml"
    return write_file_if_changed(path, content)
end

function M.compile_opencode()
    local palette = get_palette()
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

    local path = get_plugin_dir() .. "/extras/opencode/flume.json"
    return write_file_if_changed(path, content)
end

function M.compile_all(opts)
    opts = opts or {}
    local changed = {
        ghostty = M.compile_ghostty(),
        kitty = M.compile_kitty(),
        opencode = M.compile_opencode(),
        tmux = M.compile_tmux(),
        lsd = M.compile_lsd(),
        pi = M.compile_pi(),
        tuxedo = M.compile_tuxedo(),
    }

    local count = 0
    for _, did_change in pairs(changed) do
        if did_change then
            count = count + 1
        end
    end
    changed.count = count
    changed.any = count > 0

    if not opts.quiet then
        if changed.any then
            print("Flume extras compiled: " .. count .. " file(s) updated")
        else
            print("Flume extras already up to date")
        end
    end

    return changed
end

return M
