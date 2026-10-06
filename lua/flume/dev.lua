local M = {}

function M.stop()
    pcall(vim.api.nvim_del_augroup_by_name, "FlumeDevReload")
end

function M.start()
    M.stop()
    local root = vim.fn.resolve(require("flume.extras").get_plugin_dir()) .. "/lua/"
    local group = vim.api.nvim_create_augroup("FlumeDevReload", { clear = true })
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        pattern = "*.lua",
        callback = function(event)
            local path = vim.fn.resolve(vim.fn.fnamemodify(event.file, ":p"))
            if path:sub(1, #root) ~= root then
                return
            end
            local flume = require("flume")
            if flume.config.dev and flume.is_active() then
                flume.reload()
            end
        end,
    })
end

return M
