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

M.integrations = {
    { name = "ghostty", label = "Ghostty", source = "extras/ghostty/flume%s", current = "ghostty" },
    { name = "kitty", label = "Kitty", source = "extras/kitty/flume%s.conf", current = "kitty.conf" },
    { name = "tmux", label = "Tmux", source = "extras/tmux/colors%s.conf", current = "tmux.conf" },
    { name = "lsd", label = "LSD", source = "extras/lsd/colors%s.yaml", current = "lsd.yaml" },
    { name = "opencode", label = "OpenCode", source = "extras/opencode/flume%s.json", current = "opencode.json" },
    { name = "lazygit", label = "Lazygit", source = "extras/lazygit/flume%s.yml", current = "lazygit.yml" },
    { name = "fish", label = "Fish", source = "extras/fish/flume%s.fish", current = "fish.fish" },
    { name = "fzf", label = "fzf", source = "extras/fzf/flume%s.opts", current = "fzf.opts" },
    { name = "delta", label = "Delta", source = "extras/delta/flume%s.gitconfig", current = "delta.gitconfig" },
    { name = "pi", label = "Pi", source = "extras/pi/flume%s.json", current = "pi.json" },
    { name = "palette", label = "Semantic palette", source = "extras/palette/flume%s.json", current = "palette.json" },
}

local config_home = vim.env.XDG_CONFIG_HOME
if not config_home or config_home == "" then
    config_home = "~/.config"
end

local apps = {
    fish = {
        src = "extras/current/fish.fish",
        dest = config_home .. "/fish/conf.d/flume.fish",
    },
    ghostty = {
        src = "extras/current/ghostty",
        dest = "~/.config/ghostty/themes/flume",
    },
    kitty = {
        src = "extras/current/kitty.conf",
        dest = "~/.config/kitty/themes/flume.conf",
    },
    opencode = {
        src = "extras/current/opencode.json",
        dest = "~/.config/opencode/themes/flume.json",
    },
    tmux = {
        src = "extras/current/tmux.conf",
        dest = "~/.tmux/flume-theme.conf",
    },
    lsd = {
        src = "extras/current/lsd.yaml",
        dest = "~/.config/lsd/colors.yaml",
    },
    lazygit = {
        src = "extras/current/lazygit.yml",
        dest = "~/.config/lazygit/flume.yml",
    },
}

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

    -- `extras/current` is runtime state and is intentionally not checked in.
    -- Materialize it on first install from the editor's selected schema.
    if app.src:match("^extras/current/") and vim.fn.filereadable(src_path) == 0 then
        local flume = require("flume")
        local activated, activate_error = pcall(require("flume.state").activate, flume.config.schema)
        if not activated then
            vim.notify("Could not activate Flume extras: " .. tostring(activate_error), vim.log.levels.ERROR)
            return
        end
    end

    local dest_dir = vim.fn.fnamemodify(dest_path, ":h")
    vim.fn.mkdir(dest_dir, "p")

    if vim.fn.filereadable(src_path) == 0 then
        vim.notify("Source file not found: " .. src_path .. "\nHave you compiled the extras?", vim.log.levels.ERROR)
        return
    end

    local existing_type = vim.fn.getftype(dest_path)
    if existing_type ~= "" then
        if existing_type ~= "link" then
            vim.notify(
                "Refusing to replace existing file: "
                    .. dest_path
                    .. "\n"
                    .. "Move it aside or link "
                    .. src_path
                    .. " manually.",
                vim.log.levels.ERROR
            )
            return
        end

        local target = uv.fs_readlink(dest_path)
        if target == src_path or vim.fn.resolve(dest_path) == src_path then
            vim.notify(name .. " extra is already linked to " .. app.dest, vim.log.levels.INFO)
            return
        end
    end

    -- Build the replacement beside the destination, then rename it atomically.
    -- A failed link or rename leaves an existing user symlink untouched.
    local temp_path = dest_path .. ".flume-" .. tostring(uv.hrtime())
    local ok_link, link_err = uv.fs_symlink(src_path, temp_path, { dir = false, junction = false })
    if not ok_link then
        vim.notify("Failed to link " .. name .. ": " .. tostring(link_err), vim.log.levels.ERROR)
        return
    end

    local ok_rename, rename_err = uv.fs_rename(temp_path, dest_path)
    if not ok_rename then
        uv.fs_unlink(temp_path)
        vim.notify("Failed to install " .. name .. ": " .. tostring(rename_err), vim.log.levels.ERROR)
        return
    end

    vim.notify("Successfully linked " .. name .. " extra to " .. app.dest, vim.log.levels.INFO)
end

local function fish_source_lines()
    local source = M.get_source_path(apps.fish.src)
    -- Fish single-quoted strings escape backslashes and quotes, unlike POSIX sh.
    source = "'" .. source:gsub("\\", "\\\\"):gsub("'", "\\'") .. "'"
    return {
        "if status is-interactive",
        "    source " .. source,
        "end",
    }
end

function M.install(name)
    local app = apps[name]
    if not app then
        vim.notify("Unknown extra: " .. tostring(name), vim.log.levels.ERROR)
        return
    end
    if name ~= "fish" then
        return install_link(name, app)
    end

    vim.ui.select({ "Yes", "No" }, {
        prompt = "Auto-load Fish colors via "
            .. app.dest
            .. "? config.fish can override them. Existing symlinks may be replaced.",
    }, function(choice)
        if choice == "Yes" then
            install_link(name, app)
        elseif choice == "No" then
            vim.notify(
                "Fish was not installed. After :FlumeSync, add this after other color settings in your Fish config.fish:\n"
                    .. table.concat(fish_source_lines(), "\n"),
                vim.log.levels.INFO
            )
        end
    end)
end

function M.install_all()
    for name in pairs(apps) do
        M.install(name)
    end
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
