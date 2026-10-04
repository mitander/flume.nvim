-- Optional native lane: FLUME_LUALINE_RUNTIME=/path/to/lualine.nvim
-- nvim --headless --clean -c "lua dofile('tests/lualine.lua')"
local ok, err = xpcall(function()
    local runtime = assert(vim.env.FLUME_LUALINE_RUNTIME, "Set FLUME_LUALINE_RUNTIME to a lualine checkout")
    vim.opt.runtimepath:prepend(runtime)
    vim.opt.runtimepath:prepend(vim.fn.getcwd())
    require("flume").setup({ schema = "mesa", watch_sync = false })
    require("lualine").setup({ options = { theme = "flume" } })
    for _, schema in ipairs({ "mira", "opal", "dusk", "mesa" }) do
        require("flume").setup({ schema = schema, watch_sync = false })
        local colors = require("flume").colors
        local highlight = vim.api.nvim_get_hl(0, { name = "lualine_c_normal", link = false })
        assert(highlight.fg == tonumber(colors.text:sub(2), 16), schema .. " lualine text is stale")
        assert(highlight.bg == tonumber(colors.surface_alt:sub(2), 16), schema .. " lualine surface is stale")
    end
    require("flume").reload()
    local highlight = vim.api.nvim_get_hl(0, { name = "lualine_c_normal", link = false })
    assert(highlight.bg == tonumber(require("flume").colors.surface_alt:sub(2), 16), "reload left stale lualine colors")
end, debug.traceback)
if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
else
    print("PASS: native named lualine theme follows palette switches and reload")
    vim.cmd("qa!")
end
