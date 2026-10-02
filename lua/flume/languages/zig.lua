local M = {}

function M.highlights(context)
    return {
        -- Legacy fallback for @builtins when Tree-sitter and semantic tokens
        -- are unavailable or disabled.
        zigBuiltinFn = { fg = context.colors.syntax_special },
    }
end

return M
