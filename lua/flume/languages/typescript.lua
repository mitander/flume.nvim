local M = {}

function M.highlights()
    return {
        -- The TSX parser uses constructor for component/tag names. Keep those
        -- in the tag family rather than the generic typed-constructor family.
        ["@constructor.tsx"] = { link = "@tag" },
    }
end

return M
