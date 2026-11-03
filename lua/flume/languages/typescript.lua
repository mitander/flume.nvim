local M = {}

function M.highlights()
    return {
        -- Receivers and built-in object references are bindings, not literals.
        -- null and undefined retain the separate constant.builtin capture.
        ["@variable.builtin.typescript"] = { link = "@variable" },
        ["@variable.builtin.tsx"] = { link = "@variable" },
        -- JSX queries already distinguish tags from new-expression constructors.
        -- Let @constructor.tsx inherit the generic type-family mapping.
    }
end

return M
