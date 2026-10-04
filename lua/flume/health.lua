local M = {}

local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local health_error = health.error or health.report_error

local extras = require("flume.extras")

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

    local state = require("flume.state")
    ok("Shared theme state: " .. state.get_dir())
    local active = flume.get_active_schema()
    if active then
        ok("Synchronized schema: " .. active)
    else
        warn("No valid synchronized schema; run :FlumeSync")
    end
    for app, configuration in pairs(extras.get_apps()) do
        local destination = vim.fn.expand(configuration.dest)
        local target = extras.get_source_path(configuration.src)
        if vim.fn.getftype(destination) == "link" then
            local linked = (vim.uv or vim.loop).fs_readlink(destination)
            if linked == target and vim.fn.filereadable(destination) == 1 then
                ok(app .. " linked to shared state")
            else
                warn(app .. " has a legacy, broken, or different theme link; run :FlumeInstallExtras " .. app)
            end
        else
            warn(app .. " is not linked by Flume; manual setup may be in use")
        end
    end
    ok("Reload: Ghostty on macOS, Tmux inside a session, and linked Pi themes are notified by :FlumeSync")
    ok("Other apps require manual reload or a new invocation; installing a file does not select the theme")

    local suffix = palette.suffix
    local root = extras.get_plugin_dir()
    for _, integration in ipairs(extras.integrations) do
        local label = integration.label
        local path = root .. "/" .. integration.source:format(suffix)
        if vim.fn.filereadable(path) == 1 then
            ok(label .. " extra for " .. selected .. ": " .. path)
        else
            health_error(label .. " extra missing for " .. selected .. ": " .. path)
        end
    end
end

return M
