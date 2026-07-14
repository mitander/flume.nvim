local M = {}

-- Keep this list limited to parser or language-server corrections. Generic
-- semantic roles belong in flume/init.lua.
local modules = {
    "flume.languages.lua",
    "flume.languages.python",
    "flume.languages.rust",
    "flume.languages.typescript",
    "flume.languages.zig",
}

function M.setup(context)
    local claimed_groups = {}
    for _, module_name in ipairs(modules) do
        local language = require(module_name)
        local highlights = language.highlights and language.highlights(context) or {}

        for group, opts in pairs(highlights) do
            if claimed_groups[group] then
                error(group .. " is defined by both " .. claimed_groups[group] .. " and " .. module_name)
            end
            claimed_groups[group] = module_name
            context.set_highlight(group, opts)
        end
    end
end

return M
