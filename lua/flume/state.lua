local M = {}

local uv = vim.uv or vim.loop
local set_prefix = ".current-set-"
local digest_length = 16

local function read_all(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

-- Staging is private until the complete set is promoted and current is swapped.
local function write_staged(path, content)
    local file = assert(io.open(path, "wb"))
    local written, write_error = file:write(content)
    local closed, close_error = file:close()
    if not written or not closed then
        error("Could not write staged integration " .. path .. ": " .. tostring(write_error or close_error))
    end
end

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
    if target:sub(1, #set_prefix) ~= set_prefix then
        return false
    end
    local schema, digest, suffix = target:sub(#set_prefix + 1):match("^([a-z]+)%-(%x+)(.*)$")
    local valid = schema and pcall(require("flume.palette").resolve, schema)
    return valid and #digest == digest_length and (suffix == "" or suffix:match("^%-%d+%-%d+$") ~= nil)
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

-- Publish canonical artifacts without loading the compiler or editor-local options.
function M.activate(schema)
    local palette = require("flume.palette").get(schema or "dusk")
    schema = require("flume.palette").resolve(schema or "dusk")
    local extras_config = require("flume.extras")
    local root = extras_config.get_plugin_dir()
    local integrations = extras_config.integrations
    local extras = M.get_dir()
    local current = M.get_current()
    local token = tostring(vim.fn.getpid()) .. "-" .. string.format("%.0f", uv.hrtime())
    local staged_set = extras .. "/.current-stage-" .. token
    local staged_link = extras .. "/.current-link-" .. token
    local legacy_backup = extras .. "/.current-backup-" .. token
    vim.fn.mkdir(staged_set, "p")

    local ok, result = xpcall(function()
        local manifest = { schema }
        write_staged(staged_set .. "/schema", schema .. "\n")

        local function copy(source, name)
            local content = read_all(source)
            -- Neovim 0.9 sha256() needs text, not a NUL-delimited Blob.
            manifest[#manifest + 1] = name .. ":" .. vim.fn.sha256(content)
            local existing_ok, existing = pcall(read_all, current .. "/" .. name)
            write_staged(staged_set .. "/" .. name, content)
            return not existing_ok or existing ~= content
        end

        local changes = {}
        for _, integration in ipairs(integrations) do
            changes[integration.name] = copy(root .. "/" .. integration.source:format(palette.suffix), integration.current)
        end

        local set_name = set_prefix .. schema .. "-" .. vim.fn.sha256(table.concat(manifest, "\n")):sub(1, digest_length)
        local set_path = extras .. "/" .. set_name
        local promoted, promote_error = uv.fs_rename(staged_set, set_path)
        if not promoted then
            if not uv.fs_stat(set_path) then
                error("Could not promote the staged integration set: " .. tostring(promote_error))
            end

            local names = { "schema" }
            for _, integration in ipairs(integrations) do
                names[#names + 1] = integration.current
            end
            local function identical_set(path)
                local entries = 0
                for _, kind in vim.fs.dir(path) do
                    if kind ~= "file" then
                        return false
                    end
                    entries = entries + 1
                end
                if entries ~= #names then
                    return false
                end
                for _, name in ipairs(names) do
                    local existing_ok, existing = pcall(read_all, path .. "/" .. name)
                    if not existing_ok or existing ~= read_all(staged_set .. "/" .. name) then
                        return false
                    end
                end
                return true
            end

            local reusable = identical_set(set_path)
            if not reusable then
                -- Verify complete recovery sets before reuse, even when inactive.
                local prefix = set_name .. "-"
                for name, kind in vim.fs.dir(extras) do
                    if kind == "directory" and name:sub(1, #prefix) == prefix
                        and identical_set(extras .. "/" .. name) then
                        set_name = name
                        set_path = extras .. "/" .. name
                        reusable = true
                        break
                    end
                end
            end

            if reusable then
                vim.fn.delete(staged_set, "rf")
            else
                -- Never replace a corrupt set: another reader may still use it.
                set_name = set_name .. "-" .. token
                set_path = extras .. "/" .. set_name
                local recovered, recover_error = uv.fs_rename(staged_set, set_path)
                if not recovered then
                    error("Could not promote recovered integration set: " .. tostring(recover_error))
                end
            end
        end

        local linked, link_error = uv.fs_symlink(set_name, staged_link, { dir = true, junction = false })
        if not linked then
            error("Could not stage the active integration link: " .. tostring(link_error))
        end

        local current_stat = uv.fs_lstat(current)
        local migrated_directory = current_stat and current_stat.type == "directory"
        if migrated_directory then
            local moved, move_error = uv.fs_rename(current, legacy_backup)
            if not moved then
                error("Could not migrate the previous integration directory: " .. tostring(move_error))
            end
        end

        local swapped, swap_error = uv.fs_rename(staged_link, current)
        if not swapped then
            if migrated_directory then
                local restored, restore_error = uv.fs_rename(legacy_backup, current)
                if not restored then
                    error(
                        "Could not activate integration set ("
                            .. tostring(swap_error)
                            .. ") or restore the previous set ("
                            .. tostring(restore_error)
                            .. ")"
                    )
                end
            end
            error("Could not activate integration set: " .. tostring(swap_error))
        end

        if migrated_directory then
            vim.fn.delete(legacy_backup, "rf")
        end
        -- Retain immutable sets for concurrent readers and publishers.
        return changes
    end, debug.traceback)

    if uv.fs_lstat(staged_link) then
        uv.fs_unlink(staged_link)
    end
    if not ok and uv.fs_stat(staged_set) then
        vim.fn.delete(staged_set, "rf")
    end
    if uv.fs_stat(legacy_backup) and not uv.fs_lstat(current) then
        local restored, restore_error = uv.fs_rename(legacy_backup, current)
        if not restored then
            error(result .. "\nCould not restore previous integrations: " .. tostring(restore_error))
        end
    end

    if not ok then
        error(result)
    end
    local forwarded, forward_error = M.forward_legacy()
    if not forwarded then
        vim.notify("Flume synchronized, but legacy links could not be updated: " .. forward_error
            .. ". Relink integrations to " .. current, vim.log.levels.WARN)
    end
    return result
end

return M
