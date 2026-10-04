-- Lualine loads named themes afresh on ColorScheme; do not cache this table.
local c = require("flume").colors
local theme = {}

for mode, accent in pairs({
    normal = c.accent,
    insert = c.success,
    visual = c.magenta,
    replace = c.error,
    command = c.warning,
    terminal = c.info,
}) do
    theme[mode] = {
        a = { fg = accent, bg = c.surface_alt, gui = "bold" },
        b = { fg = c.text, bg = c.surface_alt },
        c = { fg = c.text, bg = c.surface_alt },
    }
end

theme.inactive = {
    a = { fg = c.placeholder, bg = c.surface },
    b = { fg = c.placeholder, bg = c.surface },
    c = { fg = c.placeholder, bg = c.surface, gui = "bold" },
}

return theme
