local M = {}

function M.highlights(context)
    return {
        -- Lua table constructors are punctuation, not names that construct a
        -- typed value. This capture commonly lands on the table braces.
        ["@constructor.lua"] = { fg = context.colors.syntax_punctuation_bracket },
    }
end

return M
