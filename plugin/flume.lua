-- The preview is opt-in and does not load or select a theme at startup.
vim.api.nvim_create_user_command("FlumeTweak", function(opts)
    require("flume.tweak").open(opts.args ~= "" and opts.args or nil)
end, {
    nargs = "?",
    desc = "Preview local Flume role edits without changing the editor theme",
    complete = function()
        return require("flume.palette").schema_order
    end,
})
