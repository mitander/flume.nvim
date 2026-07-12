local M = {}

function M.highlights()
    return {
        -- rust-analyzer reports enum variants such as Ok and Err as enum
        -- members, even when they are used as value constructors.
        ["@lsp.type.enumMember.rust"] = { link = "Type" },
    }
end

return M
