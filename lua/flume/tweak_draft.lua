local M = {}

local uv = vim.uv or vim.loop
local max_bytes = 65536

local function decode(contents)
    -- Neovim's decoder can stop at a raw NUL and ignore the remaining bytes.
    if contents:find("\0", 1, true) then
        return nil, "Draft JSON must not contain raw NUL bytes."
    end
    local ok, draft = pcall(vim.json.decode, contents)
    if not ok or type(draft) ~= "table" then
        return nil, "Expected a JSON object with version, schema and colors."
    end
    for key in pairs(draft) do
        if key ~= "version" and key ~= "schema" and key ~= "colors" then
            return nil, "Unknown draft field. Expected only version, schema and colors."
        end
    end
    if draft.version ~= 1 then
        return nil, "Unsupported draft version. Expected version 1."
    end
    local palettes = require("flume.palette")
    if type(draft.schema) ~= "string" or not palettes.schemas[draft.schema] then
        return nil, "Unknown draft schema. Expected dusk, opal, mira or mesa."
    end
    if type(draft.colors) ~= "table" or next(draft.colors) == nil then
        return nil, "Draft colors must be a nonempty object of role colors."
    end

    local colors = {}
    local canonical = palettes.get(draft.schema).colors
    for role, value in pairs(draft.colors) do
        if not canonical[role] then
            return nil, "Draft colors contain an unknown palette role."
        end
        if type(value) ~= "string" or not value:match("^#%x%x%x%x%x%x$") then
            return nil, "Draft colors must be six-digit #RRGGBB strings."
        end
        colors[role] = value:lower()
    end
    return { schema = draft.schema, colors = colors }
end

local function read_contents(fd)
    local chunks, size = {}, 0
    while size <= max_bytes do
        local chunk, failure = uv.fs_read(fd, max_bytes + 1 - size, size)
        if not chunk then
            return nil, "Cannot read draft file: " .. failure
        end
        if chunk == "" then
            return table.concat(chunks)
        end
        chunks[#chunks + 1], size = chunk, size + #chunk
    end
    return nil, "Draft file exceeds 64 KiB."
end

---Read a bounded, declarative draft. No Lua or other file content is executed.
---@param path string
---@return table? draft
---@return string? error
function M.read(path)
    if type(path) ~= "string" or path == "" or path:find("\0", 1, true) then
        return nil, "Expected a draft file path."
    end
    -- Nonblocking open lets us reject pipes without waiting for a writer. The
    -- descriptor check also covers a path replaced between lookup and open.
    local flags = uv.constants.O_RDONLY + (uv.constants.O_NONBLOCK or 0)
    local fd, open_error = uv.fs_open(path, flags, 0)
    if not fd then
        return nil, "Cannot open draft file: " .. open_error
    end
    local stat, stat_error = uv.fs_fstat(fd)
    local contents, read_error
    if not stat then
        read_error = "Cannot inspect draft file: " .. stat_error
    elseif stat.type ~= "file" then
        read_error = "Draft input must be a regular file."
    elseif stat.size > max_bytes then
        read_error = "Draft file exceeds 64 KiB."
    else
        contents, read_error = read_contents(fd)
    end
    local closed, close_error = uv.fs_close(fd)
    if not contents then
        return nil, read_error
    end
    if not closed then
        return nil, "Cannot close draft file: " .. close_error
    end
    return decode(contents)
end

return M
