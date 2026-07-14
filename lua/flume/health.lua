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
    if not loaded or type(flume.get_colors) ~= "function" then
        health_error("Could not load flume palette")
        return
    end

    local selected = flume.config.schema or "dusk"
    local palette_ok, palette = pcall(require("flume.palette").get, selected)
    if not palette_ok then
        health_error("Unknown selected schema: " .. tostring(selected))
        return
    end
    local colors = flume.get_colors(selected)
    ok("Palette loaded: " .. palette.display_name .. " (bg " .. colors.bg .. ", fg " .. colors.syntax_primary .. ")")

    local suffix = palette.suffix
    local root = plugin_root()
    local files = {
        Ghostty = "/extras/ghostty/flume" .. suffix,
        Kitty = "/extras/kitty/flume" .. suffix .. ".conf",
        Tmux = "/extras/tmux/colors" .. suffix .. ".conf",
        LSD = "/extras/lsd/colors" .. suffix .. ".yaml",
        OpenCode = "/extras/opencode/flume" .. suffix .. ".json",
        Lazygit = "/extras/lazygit/flume" .. suffix .. ".yml",
        fzf = "/extras/fzf/flume" .. suffix .. ".opts",
        Delta = "/extras/delta/flume" .. suffix .. ".gitconfig",
        Pi = "/extras/pi/flume" .. suffix .. ".json",
        Tuxedo = "/extras/tuxedo/flume" .. suffix .. ".toml",
    }
    for label, relative in pairs(files) do
        local path = root .. relative
        if vim.fn.filereadable(path) == 1 then
            ok(label .. " extra for " .. selected .. ": " .. path)
        else
            health_error(label .. " extra missing for " .. selected .. ": " .. path)
        end
    end
end

return M
