local M = {}

local uv = vim.uv or vim.loop

function M.get_plugin_dir()
    local source = debug.getinfo(1).source:sub(2)
    -- Remove '@' if present at the start of source path
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
end

local inventory = require("flume.integrations")
M.integrations = inventory.list
local apps = inventory.apps

function M.get_apps()
    return apps
end

function M.get_source_path(source)
    local active_relative_path = source:match("^extras/current/(.+)$")
    if active_relative_path then
        return require("flume.state").get_current() .. "/" .. active_relative_path
    end

    return M.get_plugin_dir() .. "/" .. source
end

local function install_link(name, app)
    local src_path = M.get_source_path(app.src)
    local dest_path = vim.fn.expand(app.dest)
    local function result(status, message)
        return { app = name, status = status, source = src_path, destination = dest_path, message = message }
    end

    -- A previously installed static helper may predate the source command's flags.
    -- Refresh through complete-set publication, never by editing a published file.
    local needs_activation = app.src:match("^extras/current/") and vim.fn.filereadable(src_path) == 0
    if app.static and not needs_activation then
        local canonical_ok, canonical = pcall(vim.fn.readfile, M.get_plugin_dir() .. "/" .. app.source, "b")
        if not canonical_ok then
            return result("failed", "Could not read shipped setup: " .. tostring(canonical))
        end
        local current_ok, current = pcall(vim.fn.readfile, src_path, "b")
        needs_activation = not current_ok or not vim.deep_equal(canonical, current)
    end
    if needs_activation then
        local state = require("flume.state")
        local schema = state.get_schema() or require("flume").config.schema
        local activated, activate_error = pcall(state.activate, schema)
        if not activated then
            return result("failed", "Could not activate Flume extras: " .. tostring(activate_error))
        end
    end

    local dest_dir = vim.fn.fnamemodify(dest_path, ":h")
    local created, create_error = pcall(vim.fn.mkdir, dest_dir, "p")
    if not created then
        return result("failed", "Could not create " .. dest_dir .. ": " .. tostring(create_error))
    end

    if vim.fn.filereadable(src_path) == 0 then
        return result("failed", "Source file not found: " .. src_path .. "\nHave you compiled the extras?")
    end

    local existing_type = vim.fn.getftype(dest_path)
    if existing_type ~= "" then
        if existing_type ~= "link" then
            return result(
                "refused",
                "Refusing to replace existing file: "
                    .. dest_path
                    .. "\nMove it aside or link "
                    .. src_path
                    .. " manually."
            )
        end

        local target = uv.fs_readlink(dest_path)
        if target == src_path or vim.fn.resolve(dest_path) == src_path then
            return result("already_linked", name .. " extra is already linked to " .. dest_path)
        end
    end

    -- Build the replacement beside the destination, then rename it atomically.
    -- A failed link or rename leaves an existing user symlink untouched.
    local temp_path = dest_path .. ".flume-" .. tostring(uv.hrtime())
    local ok_link, link_err = uv.fs_symlink(src_path, temp_path, { dir = false, junction = false })
    if not ok_link then
        return result("failed", "Failed to link " .. name .. ": " .. tostring(link_err))
    end

    local ok_rename, rename_err = uv.fs_rename(temp_path, dest_path)
    if not ok_rename then
        uv.fs_unlink(temp_path)
        return result("failed", "Failed to install " .. name .. ": " .. tostring(rename_err))
    end

    return result("linked", "Successfully linked " .. name .. " extra to " .. dest_path)
end

local function fish_source_command(source, adopt)
    -- Fish single-quoted strings escape backslashes and quotes, unlike POSIX sh.
    source = "'" .. source:gsub("\\", "\\\\"):gsub("'", "\\'") .. "'"
    return "source " .. source .. (adopt and " --adopt" or "")
end

local function fish_source_lines(source)
    return {
        "if status is-interactive",
        "    " .. fish_source_command(source or M.get_source_path(apps.fish.src)),
        "end",
    }
end

-- Completion receives the same result for immediate and consent-based installs.
-- A link is not proof that the application selected or reloaded the theme.
function M.install(name, complete)
    local app = apps[name]
    local function finish(result)
        if result.status ~= "cancelled" then
            local successful = result.status == "linked" or result.status == "already_linked"
            if successful then
                result.next_step = app.next_step
                if name == "fish_tools" then
                    result.next_step =
                        "New shells preserve existing fzf/Lazygit settings and update the LS_COLORS directory rule. config.fish can override them."
                end
                if result.next_step then
                    result.message = result.message .. "\n" .. result.next_step
                end
                if app.consent then
                    result.reload_command = fish_source_command(result.source)
                    if name == "fish_tools" then
                        result.adopt_command = fish_source_command(result.source, true)
                        result.message = result.message
                            .. "\nExisting Fish shell (preserve configured tools):\n"
                            .. result.reload_command
                            .. "\nTo replace this session's fzf/Lazygit settings instead:\n"
                            .. result.adopt_command
                            .. "\nNeither command changes persistent variables."
                    else
                        result.message = result.message .. "\n" .. result.reload_command
                    end
                end
            end
            local failed = result.status == "failed" or result.status == "refused"
            vim.notify(result.message, failed and vim.log.levels.ERROR or vim.log.levels.INFO)
        end
        if complete then
            complete(result)
        end
        return result
    end

    if not app then
        return finish({ app = name, status = "failed", message = "Unknown extra: " .. tostring(name) })
    end
    if not app.consent then
        return finish(install_link(name, app))
    end

    if name == "fish_tools" then
        vim.ui.select({ "Install", "Do not install" }, {
            prompt = app.consent .. " via " .. app.dest .. "? Existing symlinks may be replaced.",
        }, function(choice)
            if choice == "Install" then
                local result = install_link(name, app)
                result.settings = "preserve"
                finish(result)
            elseif choice == "Do not install" then
                finish({
                    app = name,
                    status = "declined",
                    message = "Fish tool setup was not installed. No files changed.",
                })
            else
                finish({ app = name, status = "cancelled" })
            end
        end)
        return
    end

    vim.ui.select({ "Yes", "No" }, {
        prompt = app.consent
            .. " via "
            .. app.dest
            .. "? config.fish can override it. Existing symlinks may be replaced.",
    }, function(choice)
        if choice == "Yes" then
            finish(install_link(name, app))
        elseif choice == "No" then
            local source = M.get_source_path(app.src)
            finish({
                app = name,
                status = "declined",
                source = source,
                destination = vim.fn.expand(app.dest),
                message = app.label
                    .. " was not installed. After :FlumeSync, add this after other settings in config.fish:\n"
                    .. table.concat(fish_source_lines(source), "\n"),
            })
        else
            finish({ app = name, status = "cancelled" })
        end
    end)
end

function M.install_all(complete)
    local results = {}
    local function next_install(index)
        local integration = inventory.list[index]
        if not integration then
            if complete then
                complete(results)
            end
            return
        end
        if not integration.dest then
            return next_install(index + 1)
        end
        M.install(integration.name, function(result)
            results[#results + 1] = result
            next_install(index + 1)
        end)
    end
    next_install(1)
end

local function shell_quote(value)
    return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end

function M.get_instruction_lines()
    local lines = {
        "# Flume Theme Extras Configuration",
        "",
        "Active themes: " .. require("flume.state").get_current(),
        "Run :FlumeSync once, then link and enable the theme in each application.",
        "Semantic export: " .. require("flume.state").get_current() .. "/palette.json",
        "External apps need their own reload support; see docs/workflows.md.",
        "",
        "## Option 1: Link directly from Neovim",
        "Run the following command to link all configurations:",
        "```vim",
        ":FlumeInstallExtras",
        "```",
        "Or link a specific application theme:",
        "```vim",
        ":FlumeInstallExtras ghostty",
        ":FlumeInstallExtras kitty",
        ":FlumeInstallExtras opencode",
        ":FlumeInstallExtras tmux",
        ":FlumeInstallExtras lsd",
        ":FlumeInstallExtras lazygit",
        ":FlumeInstallExtras fish",
        ":FlumeInstallExtras fish_tools",
        ":FlumeInstallExtras pi",
        "```",
        "",
        "## Option 2: Copy-paste terminal commands",
        "Run these commands in your shell to symlink the themes manually:",
        "",
    }

    local keys = {}
    for k in pairs(apps) do
        table.insert(keys, k)
    end
    table.sort(keys)

    for _, name in ipairs(keys) do
        local app = apps[name]
        local source = M.get_source_path(app.src)
        table.insert(lines, "### " .. name:sub(1, 1):upper() .. name:sub(2))
        table.insert(lines, "```bash")

        local destination = vim.fn.expand(app.dest)
        table.insert(
            lines,
            "if [ -e " .. shell_quote(destination) .. " ] || [ -L " .. shell_quote(destination) .. " ]; then"
        )
        table.insert(lines, "  echo " .. shell_quote("Refusing to replace existing path: " .. destination) .. " >&2")
        table.insert(lines, "else")
        table.insert(lines, "  mkdir -p " .. shell_quote(vim.fn.fnamemodify(destination, ":h")))
        table.insert(lines, "  ln -s " .. shell_quote(source) .. " " .. shell_quote(destination))
        table.insert(lines, "fi")
        table.insert(lines, "```")
        table.insert(lines, "")
    end

    table.insert(lines, "## Fish startup colors")
    table.insert(lines, "The Fish installer asks before linking conf.d/flume.fish. It never edits config.fish.")
    table.insert(lines, "conf.d loads before config.fish, so later color settings can override Flume.")
    table.insert(lines, "For manual setup, add this after other color settings in your Fish config.fish:")
    table.insert(lines, "```fish")
    vim.list_extend(lines, fish_source_lines())
    table.insert(lines, "```")
    table.insert(
        lines,
        "After :FlumeSync, source the active file again in existing shells. New shells load it at startup."
    )
    table.insert(lines, "")
    table.insert(lines, "## Fish tool setup")
    table.insert(
        lines,
        "Run :FlumeInstallExtras fish_tools for optional Fish 3.5+ setup of fzf, Lazygit and LS_COLORS."
    )
    table.insert(
        lines,
        "Confirm installation, then choose a printed source command to preserve or replace current-session tool exports."
    )
    table.insert(lines, "The installer prints both commands. Neovim cannot apply them to its parent shell.")
    table.insert(
        lines,
        "Normal startup preserves explicit FZF_DEFAULT_OPTS_FILE and LG_CONFIG_FILE choices. No config.fish edits."
    )
    table.insert(lines, "New shells load it automatically. Source the active fish-tools.fish again in existing shells.")
    table.insert(lines, "")
    table.insert(lines, "## LSD filename colors")
    table.insert(lines, "The YAML theme styles metadata. Add this after existing LS_COLORS setup in your shell config")
    table.insert(
        lines,
        "for world-writable directory names in ANSI magenta on the normal background (pink with Flume)."
    )
    table.insert(
        lines,
        "Other entries, including sticky-directory colors, stay unchanged. GNU ls also uses this setting."
    )
    table.insert(lines, "Fish:")
    table.insert(lines, "```fish")
    table.insert(lines, 'set -gx LS_COLORS "$LS_COLORS:ow=0;35"')
    table.insert(lines, "```")
    table.insert(lines, "Bash or Zsh:")
    table.insert(lines, "```sh")
    table.insert(lines, 'export LS_COLORS="${LS_COLORS:+$LS_COLORS:}ow=0;35"')
    table.insert(lines, "```")
    table.insert(lines, "")
    table.insert(lines, "## Lazygit configuration layering")
    table.insert(lines, "Set this environment variable so new Lazygit sessions layer the active theme:")
    table.insert(lines, "```bash")
    table.insert(lines, 'export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/flume.yml"')
    table.insert(lines, "```")
    table.insert(lines, "")
    return lines
end

function M.show_instructions()
    local lines = M.get_instruction_lines()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

    vim.cmd("vsplit")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
end

return M
