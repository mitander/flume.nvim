local M = {}

local config_home = vim.env.XDG_CONFIG_HOME
if not config_home or config_home == "" then
    config_home = "~/.config"
end

-- One inventory for compilation, publication, installation and health checks.
-- Static shell setup is shipped as source, not regenerated for each palette.
M.list = {
    {
        name = "ghostty",
        label = "Ghostty",
        source = "extras/ghostty/flume%s",
        current = "ghostty",
        dest = "~/.config/ghostty/themes/flume",
        next_step = "Select theme = flume in Ghostty's config.",
    },
    {
        name = "kitty",
        label = "Kitty",
        source = "extras/kitty/flume%s.conf",
        current = "kitty.conf",
        dest = "~/.config/kitty/themes/flume.conf",
        next_step = "Include themes/flume.conf from kitty.conf, then reload Kitty.",
    },
    {
        name = "tmux",
        label = "Tmux",
        source = "extras/tmux/colors%s.conf",
        current = "tmux.conf",
        dest = "~/.tmux/flume-theme.conf",
        next_step = "Source ~/.tmux/flume-theme.conf from .tmux.conf, then reload Tmux.",
    },
    {
        name = "lsd",
        label = "LSD",
        source = "extras/lsd/colors%s.yaml",
        current = "lsd.yaml",
        dest = "~/.config/lsd/colors.yaml",
        next_step = "Select color.theme: custom in LSD 1.2+. Filename colors use LS_COLORS, not this file.",
    },
    {
        name = "opencode",
        label = "OpenCode",
        source = "extras/opencode/flume%s.json",
        current = "opencode.json",
        dest = "~/.config/opencode/themes/flume.json",
        next_step = "Select flume with OpenCode's /theme command.",
    },
    {
        name = "lazygit",
        label = "Lazygit",
        source = "extras/lazygit/flume%s.yml",
        current = "lazygit.yml",
        dest = "~/.config/lazygit/flume.yml",
        next_step = "Layer this file with LG_CONFIG_FILE, or install fish_tools for Fish setup.",
    },
    {
        name = "fish",
        label = "Fish",
        source = "extras/fish/flume%s.fish",
        current = "fish.fish",
        dest = config_home .. "/fish/conf.d/flume.fish",
        consent = "Auto-load Fish colors",
        next_step = "New shells load the colors. Existing shells must source the active file again. config.fish can override them.",
    },
    {
        name = "fish_tools",
        label = "Fish tool setup",
        source = "extras/fish/flume-tools.fish",
        current = "fish-tools.fish",
        static = true,
        dest = config_home .. "/fish/conf.d/flume-tools.fish",
        consent = "Configure fzf, Lazygit and LS_COLORS in Fish 3.5+",
        next_step = "Normal startup respects tool exports. Run the printed source command to apply your chosen mode now.",
    },
    { name = "fzf", label = "fzf", source = "extras/fzf/flume%s.opts", current = "fzf.opts" },
    { name = "delta", label = "Delta", source = "extras/delta/flume%s.gitconfig", current = "delta.gitconfig" },
    {
        name = "pi",
        label = "Pi",
        source = "extras/pi/flume%s.json",
        current = "pi.json",
        dest = "~/.pi/agent/themes/flume.json",
        next_step = "Select flume in Pi's theme settings.",
    },
    { name = "palette", label = "Semantic palette", source = "extras/palette/flume%s.json", current = "palette.json" },
}

M.apps = {}
for _, integration in ipairs(M.list) do
    if integration.dest then
        integration.src = "extras/current/" .. integration.current
        M.apps[integration.name] = integration
    end
end

return M
