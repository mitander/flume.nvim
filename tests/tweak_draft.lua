local M = {}

function M.register(test, equal, truthy)
    test("draft files reject invalid documents before admitting any colors", function()
        local reader = require("flume.tweak_draft")
        local path = vim.fn.tempname()
        local invalid = {
            "",
            "not JSON",
            "null",
            "[]",
            "{}",
            '{"version":2,"schema":"dusk","colors":{"bg":"#123456"}}',
            '{"version":"1","schema":"dusk","colors":{"bg":"#123456"}}',
            '{"version":1,"schema":"missing","colors":{"bg":"#123456"}}',
            '{"version":1,"schema":null,"colors":{"bg":"#123456"}}',
            '{"version":1,"schema":"dusk","colors":{}}',
            '{"version":1,"schema":"dusk","colors":[]}',
            '{"version":1,"schema":"dusk","colors":null}',
            '{"version":1,"schema":"dusk","colors":{"bg":"#123456","unknown":"#abcdef"}}',
            '{"version":1,"schema":"dusk","colors":{"bg":"#123"}}',
            '{"version":1,"schema":"dusk","colors":{"bg":"#gggggg"}}',
            '{"version":1,"schema":"dusk","colors":{"bg":123456}}',
            '{"version":1,"schema":"dusk","colors":{"bg":null}}',
            '{"version":1,"schema":"dusk","colors":{"bg":false}}',
            '{"version":1,"schema":"dusk","colors":{"bg":[]}}',
            '{"version":1,"schema":"dusk","colors":["#123456"]}',
            '{"version":1,"schema":"dusk","colors":{"bg":"#123456"},"extra":true}',
            "vim.g.flume_draft_executed = true",
        }
        local ok, failure = xpcall(function()
            for _, contents in ipairs(invalid) do
                vim.fn.writefile({ contents }, path)
                local draft, message = reader.read(path)
                equal(draft, nil, "invalid document admitted: " .. contents)
                truthy(type(message) == "string" and #message > 0, "validation failure explained")
            end
            equal(vim.g.flume_draft_executed, nil, "draft content was executed")
            vim.fn.writefile({ '{"version":1,"schema":"opal","colors":{"bg":"#ABCDEF"}}' }, path)
            local draft = assert(reader.read(path))
            equal(draft.schema, "opal", "schema retained")
            equal(draft.colors.bg, "#abcdef", "hex normalized")
        end, debug.traceback)
        vim.fn.delete(path)
        if not ok then
            error(failure)
        end
    end)

    test("draft file reads are bounded and close descriptors on refusal", function()
        local reader = require("flume.tweak_draft")
        local uv = vim.uv or vim.loop
        local path = vim.fn.tempname()
        local open, close, read, stat = uv.fs_open, uv.fs_close, uv.fs_read, uv.fs_fstat
        local opened, closed = 0, 0
        uv.fs_open = function(...)
            local fd, failure = open(...)
            if fd then
                opened = opened + 1
            end
            return fd, failure
        end
        uv.fs_close = function(...)
            local result, failure = close(...)
            if result then
                closed = closed + 1
            end
            return result, failure
        end
        local ok, failure = xpcall(function()
            equal(reader.read(path), nil, "missing file refused")
            equal(reader.read(path .. "\0suffix"), nil, "NUL path refused")
            local document = '{"version":1,"schema":"dusk","colors":{"bg":"#123456"}}'
            vim.fn.writefile({ document .. string.rep(" ", 65536 - #document) }, path, "b")
            truthy(reader.read(path), "64 KiB file admitted")
            uv.fs_read = function(fd, size, offset)
                return read(fd, math.min(size, 8), offset)
            end
            vim.fn.writefile({ document }, path)
            truthy(reader.read(path), "partial reads assemble the complete document")
            vim.fn.writefile({ document .. " invalid suffix" }, path)
            equal(reader.read(path), nil, "partial reads cannot hide an invalid suffix")
            uv.fs_read = read
            vim.fn.writefile({ document .. string.rep(" ", 65537 - #document) }, path, "b")
            local draft, message = reader.read(path)
            equal(draft, nil, "oversized file refused")
            truthy(message:find("64 KiB", 1, true), "size limit explained")
            uv.fs_fstat = function(fd)
                local result = assert(stat(fd))
                result.size = 1
                return result
            end
            equal(reader.read(path), nil, "actual read remains bounded if the file grows")
            uv.fs_fstat = stat
            vim.fn.writefile({ document }, path)
            uv.fs_read = function()
                return nil, "injected read failure"
            end
            equal(reader.read(path), nil, "read failure refuses the draft")
            uv.fs_read = read
            vim.fn.delete(path)
            vim.fn.mkdir(path)
            equal(reader.read(path), nil, "directory refused")
            vim.fn.delete(path, "d")
            if vim.fn.has("unix") == 1 then
                vim.fn.system({ "mkfifo", path })
                equal(vim.v.shell_error, 0, "pipe fixture created")
                equal(reader.read(path), nil, "pipe refused without waiting for a writer")
            end
            equal(opened, closed, "all opened descriptors closed")
        end, debug.traceback)
        uv.fs_open, uv.fs_close, uv.fs_read, uv.fs_fstat = open, close, read, stat
        vim.fn.delete(path, "rf")
        if not ok then
            error(failure)
        end
    end)
end

return M
