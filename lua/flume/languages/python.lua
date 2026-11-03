local M = {}

function M.highlights()
    return {
        -- The query uses this capture for receiver bindings self and cls.
        ["@variable.builtin.python"] = { link = "@variable" },
        -- Python language servers often classify imported modules, classes,
        -- and callables alike as namespaces. Defer to Tree-sitter so those
        -- names keep their more specific module, type, or function captures.
        ["@lsp.type.namespace.python"] = {},
    }
end

return M
