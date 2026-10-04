local M = {}

function M.get_dir()
    local configured = vim.env.FLUME_DATA_DIR
    if configured and configured ~= "" then
        local absolute = vim.fn.fnamemodify(vim.fn.expand(configured), ":p")
        return absolute == "/" and absolute or absolute:gsub("/$", "")
    end
    return vim.fn.stdpath("data") .. "/flume"
end

function M.get_current()
    return M.get_dir() .. "/current"
end

function M.get_legacy_current()
    return require("flume.extras").get_plugin_dir() .. "/extras/current"
end

local function read_schema(path)
    local file = io.open(path .. "/schema", "rb")
    if not file then
        return nil
    end
    local schema = file:read("*l")
    file:close()
    local valid, resolved = pcall(require("flume.palette").resolve, schema or "")
    return valid and resolved or nil
end

function M.get_schema()
    local current = M.get_current()
    -- Invalid new state must not revive an obsolete checkout choice.
    if (vim.uv or vim.loop).fs_lstat(current) then
        return read_schema(current)
    end
    return read_schema(M.get_legacy_current())
end

local function recognized_set(target)
    if not target then
        return false
    end
    local schema, digest, suffix = target:match("^%.current%-set%-([a-z]+)%-(%x+)(.*)$")
    local valid = schema and pcall(require("flume.palette").resolve, schema)
    return valid and #digest == 16 and (suffix == "" or suffix:match("^%-%d+%-%d+$") ~= nil)
end

-- A forwarding link keeps pre-v0.3 includes working until they are relinked.
-- Replacing it also notifies consumers still watching the checkout's extras.
function M.forward_legacy()
    local uv = vim.uv or vim.loop
    local current = M.get_legacy_current()
    if current == M.get_current() then
        return true
    end
    -- Serialize cooperating Flume activations before checking link ownership.
    -- A stale lock is not stolen: shared state still works, and the warning
    -- directs users to relink rather than risking another writer's data.
    local lock = current .. ".flume-lock"
    local locked, lock_error = uv.fs_mkdir(lock, 448)
    if not locked then
        return false, "Legacy forwarding lock unavailable: " .. tostring(lock_error)
    end
    local staged = current .. ".flume-" .. tostring(vim.fn.getpid()) .. "-" .. string.format("%.0f", uv.hrtime())
    local ok, failure = pcall(function()
        local stat = uv.fs_lstat(current)
        if stat and stat.type ~= "link" then
            error("Legacy extras/current is not a symlink; move it aside and relink your integrations")
        end
        local target = stat and uv.fs_readlink(current)
        if stat then
            if target ~= M.get_current() and not recognized_set(target) then
                error("Refusing to replace an unrecognized extras/current link")
            end
        end
        local linked, link_error = uv.fs_symlink(M.get_current(), staged, { dir = true, junction = false })
        if not linked then
            error(tostring(link_error))
        end
        -- Refuse an unexpected change made by a non-cooperating process too.
        local latest = uv.fs_lstat(current)
        if (latest and latest.type ~= "link") or (latest ~= nil) ~= (stat ~= nil) then
            error("Legacy path changed during forwarding")
        end
        if latest and (latest.ino ~= stat.ino or uv.fs_readlink(current) ~= target) then
            error("Legacy link changed during forwarding")
        end
        local replaced, rename_error = uv.fs_rename(staged, current)
        if not replaced then
            error(tostring(rename_error))
        end
    end)
    if uv.fs_lstat(staged) then
        uv.fs_unlink(staged)
    end
    local unlocked, unlock_error = uv.fs_rmdir(lock)
    if not unlocked then
        return false, "Could not remove legacy forwarding lock: " .. tostring(unlock_error)
    end
    return ok, ok and nil or tostring(failure)
end

return M
