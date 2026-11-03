local M = {}

function M.highlights()
    return {
        -- Receiver self is a binding, not a built-in literal. Module-path self
        -- retains the query's more specific module capture.
        ["@variable.builtin.rust"] = { link = "@variable" },
        -- rust-analyzer reports enum variants such as Ok and Err as enum
        -- members, even when they are used as value constructors.
        ["@lsp.type.enumMember.rust"] = { link = "Type" },
    }
end

return M
