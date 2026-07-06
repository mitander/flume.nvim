local M = {}

local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local health_error = health.error or health.report_error

local function plugin_root()
    local source = debug.getinfo(1).source:sub(2)
    return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
end

local function check_file(label, path)
    if vim.fn.filereadable(path) == 1 then
        ok(label .. ": " .. path)
    else
        warn(label .. " missing: " .. path)
    end
end

function M.check()
    start("flume.nvim")

    if vim.fn.has("nvim-0.9") == 1 then
        ok("Neovim version supports current Tree-sitter highlight groups")
    else
        warn("Neovim 0.9+ is recommended")
    end

    if vim.o.termguicolors then
        ok("termguicolors is enabled")
    else
        warn("Enable termguicolors for accurate color output")
    end

    local loaded, flume = pcall(require, "flume")
    if loaded and type(flume.get_colors) == "function" then
        local colors = flume.get_colors()
        ok("Palette loaded (bg " .. colors.bg .. ", fg " .. colors.syntax_primary .. ")")
    else
        health_error("Could not load flume palette")
    end

    local root = plugin_root()
    check_file("Ghostty extra", root .. "/extras/ghostty/flume")
    check_file("Tmux extra", root .. "/extras/tmux/colors.conf")
    check_file("LSD extra", root .. "/extras/lsd/colors.yaml")
    check_file("Pi extra", root .. "/extras/pi/flume.json")
    check_file("Tuxedo extra", root .. "/extras/tuxedo/flume.toml")
end

return M
