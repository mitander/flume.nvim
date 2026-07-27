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

local apps = {
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
}

function M.get_apps()
    return apps
end

function M.install(name)
    local app = apps[name]
    if not app then
        vim.notify("Unknown extra: " .. tostring(name), vim.log.levels.ERROR)
        return
    end

    local plugin_dir = M.get_plugin_dir()
    local src_path = plugin_dir .. "/" .. app.src
    local dest_path = vim.fn.expand(app.dest)

    -- `extras/current` is runtime state and is intentionally not checked in.
    -- Materialize it on first install from the editor's selected schema.
    if app.src:match("^extras/current/") and vim.fn.filereadable(src_path) == 0 then
        local flume = require("flume")
        local activated, activate_error = pcall(require("flume.compiler").activate, flume.config.schema)
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

function M.install_all()
    for name in pairs(apps) do
        M.install(name)
    end
end

local function shell_quote(value)
    return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end

function M.get_instruction_lines()
    local plugin_dir = M.get_plugin_dir()
    local lines = {
        "# Flume Theme Extras Configuration",
        "",
        "You can link or copy the compiled theme files to their respective application folders.",
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
        local src_path = plugin_dir .. "/" .. app.src
        table.insert(lines, "### " .. name:sub(1, 1):upper() .. name:sub(2))
        table.insert(lines, "```bash")
        local destination = vim.fn.expand(app.dest)
        table.insert(lines, "if [ -e " .. shell_quote(destination) .. " ] || [ -L " .. shell_quote(destination) .. " ]; then")
        table.insert(lines, "  echo " .. shell_quote("Refusing to replace existing path: " .. destination) .. " >&2")
        table.insert(lines, "else")
        table.insert(lines, "  mkdir -p " .. shell_quote(vim.fn.fnamemodify(destination, ":h")))
        table.insert(lines, "  ln -s " .. shell_quote(src_path) .. " " .. shell_quote(destination))
        table.insert(lines, "fi")
        table.insert(lines, "```")
        table.insert(lines, "")
    end
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
