local M = {}

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

function M.render()
    local palettes = require("flume.palette")
    local roles = vim.tbl_keys(palettes.dusk)
    table.sort(roles)
    local lines = {
        "# Generated palette manifest",
        "",
        "Generated from `lua/flume/palette.lua`; do not edit by hand.",
        "",
        "## Exact roles",
        "",
        "| Role | Dusk | Opal | Mira | Mesa |",
        "| --- | --- | --- | --- | --- |",
    }
    for _, role in ipairs(roles) do
        local values = {}
        for _, schema in ipairs(palettes.schema_order) do
            values[#values + 1] = "`" .. palettes[schema][role] .. "`"
        end
        lines[#lines + 1] = "| `" .. role .. "` | " .. table.concat(values, " | ") .. " |"
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "## Contrast pairs"
    lines[#lines + 1] = ""
    lines[#lines + 1] = "| Schema | Pair | Ratio | Target |"
    lines[#lines + 1] = "| --- | --- | ---: | ---: |"
    local pairs = {
        { "syntax_primary", "bg", 4.5 },
        { "on_accent", "accent", 4.5 },
        { "on_accent", "match", 4.5 },
        { "border_focused", "bg", 3.0 },
    }
    for _, schema in ipairs(palettes.schema_order) do
        local colors = palettes[schema]
        for _, pair in ipairs(pairs) do
            lines[#lines + 1] = string.format(
                "| %s | `%s` / `%s` | %.2f:1 | %.1f:1 |",
                palettes.schemas[schema].display_name,
                pair[1],
                pair[2],
                contrast(colors[pair[1]], colors[pair[2]]),
                pair[3]
            )
        end
    end
    lines[#lines + 1] = ""
    return table.concat(lines, "\n")
end

return M
