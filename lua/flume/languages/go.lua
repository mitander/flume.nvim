local M = {}

function M.highlights()
    return {
        -- The query guesses constructors from New*/Make* call names. These are
        -- ordinary Go functions, even when they return a newly allocated value.
        -- Composite literals and conversions retain their separate type captures.
        ["@constructor.go"] = { link = "Function" },
    }
end

return M
