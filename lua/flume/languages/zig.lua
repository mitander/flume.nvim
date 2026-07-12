local M = {}

function M.highlights(context)
    return {
        -- Legacy fallback for @builtins when Tree-sitter and semantic tokens
        -- are unavailable or disabled.
        zigBuiltinFn = { fg = context.colors.syntax_special },

        -- zls applies namespace tokens broadly to dotted access. Let the more
        -- precise Tree-sitter captures provide the visible distinction.
        ["@lsp.type.namespace.zig"] = {},
    }
end

return M
