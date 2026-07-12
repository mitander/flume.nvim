local M = {}

function M.highlights()
    return {
        -- Python language servers often classify imported modules, classes,
        -- and callables alike as namespaces. Defer to Tree-sitter so those
        -- names keep their more specific module, type, or function captures.
        ["@lsp.type.namespace.python"] = {},
    }
end

return M
