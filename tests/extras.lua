local M = {}

local function read_all(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

local function keyset(values)
    local result = {}
    for _, value in ipairs(values) do
        result[value] = true
    end
    return result
end

local function sorted_keys(values)
    local result = vim.tbl_keys(values)
    table.sort(result)
    return table.concat(result, ",")
end

function M.register(test, equal, truthy)
    local palettes = require("flume.palette")
    local apps = { "ghostty", "kitty", "tmux", "lsd", "opencode", "lazygit", "fzf", "delta", "pi", "tuxedo" }

    local function suffix(schema)
        return palettes.schemas[schema].suffix
    end

    local function path(app, schema)
        local ending = suffix(schema)
        local patterns = {
            ghostty = "extras/ghostty/flume%s",
            kitty = "extras/kitty/flume%s.conf",
            tmux = "extras/tmux/colors%s.conf",
            lsd = "extras/lsd/colors%s.yaml",
            opencode = "extras/opencode/flume%s.json",
            lazygit = "extras/lazygit/flume%s.yml",
            fzf = "extras/fzf/flume%s.opts",
            delta = "extras/delta/flume%s.gitconfig",
            pi = "extras/pi/flume%s.json",
            tuxedo = "extras/tuxedo/flume%s.toml",
        }
        return patterns[app]:format(ending)
    end

    test("generated inventory is exactly four schemas by ten integrations", function()
        local expected = {}
        for _, app in ipairs(apps) do
            for _, schema in ipairs(palettes.schema_order) do
                expected[path(app, schema)] = true
            end
        end
        local actual = {}
        for _, app in ipairs(apps) do
            for _, artifact in ipairs(vim.fn.glob("extras/" .. app .. "/*", false, true)) do
                if vim.fn.isdirectory(artifact) == 0 then
                    actual[artifact] = true
                end
            end
        end
        equal(sorted_keys(actual), sorted_keys(expected), "generated integration inventory")
        equal(vim.tbl_count(actual), 40, "generated artifact count")
    end)

    test("terminal integration contracts parse for every schema", function()
        local ghost_scalars = keyset({
            "background", "foreground", "selection-background", "selection-foreground", "cursor-color", "cursor-text",
        })
        local kitty_keys = keyset({
            "background", "foreground", "selection_background", "selection_foreground", "cursor", "cursor_text_color",
            "tab_bar_background", "tab_bar_margin_color", "active_tab_foreground", "active_tab_background",
            "active_tab_font_style", "inactive_tab_foreground", "inactive_tab_background", "inactive_tab_font_style",
        })
        for index = 0, 15 do
            kitty_keys["color" .. index] = true
        end

        for _, schema in ipairs(palettes.schema_order) do
            local colors = palettes[schema]
            local ghost = read_all(path("ghostty", schema))
            local scalars, slots = {}, {}
            for line in ghost:gmatch("[^\n]+") do
                local key, value = line:match("^([%w%-]+) = (#[%x]+)$")
                if key == "palette" then
                    error("Ghostty palette line parsed as scalar")
                elseif key then
                    truthy(not scalars[key], schema .. " duplicate Ghostty key " .. key)
                    scalars[key] = value
                end
                local index, color = line:match("^palette = (%d+)=(#[%x]+)$")
                if index then
                    index = tonumber(index)
                    truthy(not slots[index], schema .. " duplicate Ghostty ANSI " .. index)
                    slots[index] = color
                end
            end
            equal(sorted_keys(scalars), sorted_keys(ghost_scalars), schema .. " Ghostty scalar keys")
            equal(vim.tbl_count(slots), 16, schema .. " Ghostty ANSI count")
            for index = 0, 15 do
                truthy(slots[index], schema .. " missing Ghostty ANSI " .. index)
            end
            equal(scalars.background, colors.terminal_bg, schema .. " Ghostty background")
            equal(scalars["cursor-color"], colors.accent, schema .. " Ghostty cursor")

            local kitty = {}
            for line in read_all(path("kitty", schema)):gmatch("[^\n]+") do
                if not line:match("^#") then
                    local key, value = line:match("^(%S+)%s+(%S+)$")
                    if key then
                        truthy(not kitty[key], schema .. " duplicate Kitty key " .. key)
                        kitty[key] = value
                    end
                end
            end
            equal(sorted_keys(kitty), sorted_keys(kitty_keys), schema .. " Kitty keys")
            equal(kitty.background, colors.terminal_bg, schema .. " Kitty background")
            equal(kitty.color0, colors.black, schema .. " Kitty ANSI 0")
            equal(kitty.color15, colors.bright_white, schema .. " Kitty ANSI 15")
        end
    end)

    test("tmux lsd and fzf contracts parse for every schema", function()
        local tmux_keys = keyset({
            "thm_bg", "thm_fg", "thm_black", "thm_gray", "thm_lgray", "thm_accent", "thm_red",
            "thm_green", "thm_yellow", "thm_blue", "thm_pink", "thm_cyan", "thm_orange",
        })
        local lsd_keys = keyset({
            "user", "group", "permission.read", "permission.write", "permission.exec", "permission.exec-sticky",
            "permission.no-access", "permission.octal", "permission.acl", "permission.context", "date.hour-old",
            "date.day-old", "date.older", "size.none", "size.small", "size.medium", "size.large", "inode.valid",
            "inode.invalid", "links.valid", "links.invalid", "tree-edge", "git-status.default",
            "git-status.unmodified", "git-status.ignored", "git-status.new-in-index", "git-status.new-in-workdir",
            "git-status.typechange", "git-status.deleted", "git-status.renamed", "git-status.modified",
            "git-status.conflicted",
        })
        local fzf_keys = keyset({
            "fg", "bg", "hl", "fg+", "bg+", "hl+", "info", "prompt", "pointer", "marker", "spinner",
            "header", "border", "gutter", "query",
        })

        for _, schema in ipairs(palettes.schema_order) do
            local tmux = {}
            for key, value in read_all(path("tmux", schema)):gmatch('%%hidden ([%w_]+)="(#[%x]+)"') do
                truthy(not tmux[key], schema .. " duplicate Tmux key " .. key)
                tmux[key] = value
            end
            equal(sorted_keys(tmux), sorted_keys(tmux_keys), schema .. " Tmux keys")

            local lsd, section = {}, nil
            for line in read_all(path("lsd", schema)):gmatch("[^\n]+") do
                line = line:gsub("%s+#.*$", "")
                local top = line:match("^([%w%-]+):%s*$")
                if top then
                    section = top
                else
                    local key, value = line:match("^([%w%-]+):%s*(%d+)")
                    if key then
                        lsd[key] = tonumber(value)
                        section = nil
                    else
                        key, value = line:match("^  ([%w%-]+):%s*(%d+)")
                        if key then
                            truthy(section, schema .. " LSD nested key without section")
                            lsd[section .. "." .. key] = tonumber(value)
                        end
                    end
                end
            end
            equal(sorted_keys(lsd), sorted_keys(lsd_keys), schema .. " LSD keys")
            for key, value in pairs(lsd) do
                truthy(value >= 0 and value <= 255, schema .. " LSD " .. key .. " outside xterm range")
            end

            local opts = read_all(path("fzf", schema))
            truthy(opts:match("^%-%-no%-bold %-%-color="), schema .. " fzf prefix")
            local parsed = {}
            for key, value in opts:gmatch("([%w+]+):(#[%x]+)") do
                parsed[key] = value
            end
            equal(sorted_keys(parsed), sorted_keys(fzf_keys), schema .. " fzf keys")
            equal(parsed.bg, palettes[schema].bg, schema .. " fzf background")
            equal(parsed.prompt, palettes[schema].accent, schema .. " fzf prompt")
        end
    end)

    test("Pi and OpenCode JSON aliases resolve for every schema", function()
        local pi_top = keyset({ "$schema", "name", "vars", "colors", "export" })
        local opencode_top = keyset({ "$schema", "defs", "theme" })
        for _, schema in ipairs(palettes.schema_order) do
            local colors = palettes[schema]
            local pi = vim.json.decode(read_all(path("pi", schema)))
            equal(sorted_keys(pi), sorted_keys(pi_top), schema .. " Pi top-level keys")
            equal(pi.name, palettes.schemas[schema].integration_name, schema .. " Pi theme name")
            for key, alias in pairs(pi.colors) do
                truthy(pi.vars[alias], schema .. " Pi colors." .. key .. " has unknown alias " .. tostring(alias))
            end
            for key, alias in pairs(pi.export) do
                truthy(pi.vars[alias], schema .. " Pi export." .. key .. " has unknown alias " .. tostring(alias))
            end
            equal(pi.vars.bg, colors.bg, schema .. " Pi background")
            equal(pi.vars.diffAdd, colors.diff_add, schema .. " Pi added color")
            equal(pi.colors.syntaxVariable, "fg", schema .. " Pi neutral variables")

            local opencode = vim.json.decode(read_all(path("opencode", schema)))
            equal(sorted_keys(opencode), sorted_keys(opencode_top), schema .. " OpenCode top-level keys")
            for key, alias in pairs(opencode.theme) do
                truthy(opencode.defs[alias], schema .. " OpenCode theme." .. key .. " has unknown alias " .. tostring(alias))
            end
            equal(opencode.defs.bg, colors.bg, schema .. " OpenCode background")
            equal(opencode.theme.syntaxVariable, "syntax_primary", schema .. " OpenCode neutral variables")
        end
    end)

    test("Lazygit Delta and Tuxedo contracts parse for every schema", function()
        local lazygit_keys = keyset({
            "activeBorderColor", "inactiveBorderColor", "searchingActiveBorderColor", "optionsTextColor",
            "selectedLineBgColor", "inactiveViewSelectedLineBgColor", "cherryPickedCommitBgColor",
            "cherryPickedCommitFgColor", "unstagedChangesColor", "defaultFgColor",
        })
        local delta_keys = keyset({
            "delta.light", "delta.features", "delta.syntax-theme", "delta.flume.minus-style",
            "delta.flume.minus-emph-style", "delta.flume.plus-style", "delta.flume.plus-emph-style",
            "delta.flume.line-numbers", "delta.flume.line-numbers-minus-style",
            "delta.flume.line-numbers-plus-style", "delta.flume.line-numbers-left-style",
            "delta.flume.line-numbers-right-style", "delta.flume.commit-decoration-style",
            "delta.flume.file-style", "delta.flume.file-decoration-style", "delta.flume.hunk-header-style",
            "delta.flume.hunk-header-decoration-style",
        })
        local tuxedo_keys = keyset({
            "name", "bg", "panel", "border", "fg", "dim", "accent", "cursor", "selection", "statusbar",
            "status_fg", "mode_fg", "mode_bg", "pri_a", "pri_b", "pri_c", "pri_d", "pri_other", "project",
            "context", "due", "overdue", "today", "done", "selected", "matched",
        })

        for _, schema in ipairs(palettes.schema_order) do
            local colors = palettes[schema]
            local lazygit_content = read_all(path("lazygit", schema))
            local lazygit = {}
            for key in lazygit_content:gmatch("\n    ([%w]+Color):") do
                lazygit[key] = true
            end
            equal(sorted_keys(lazygit), sorted_keys(lazygit_keys), schema .. " Lazygit theme keys")
            for _, mapping in ipairs({
                '--minus-style="syntax ' .. colors.diff_delete_bg .. '"',
                '--minus-emph-style="syntax ' .. colors.diff_delete_emphasis .. '"',
                '--plus-style="syntax ' .. colors.diff_add_bg .. '"',
                '--plus-emph-style="syntax ' .. colors.diff_add_emphasis .. '"',
            }) do
                truthy(lazygit_content:find(mapping, 1, true), schema .. " Lazygit pager missing " .. mapping)
            end

            local delta_path = path("delta", schema)
            local command = { "git", "config", "--file", delta_path, "--name-only", "--get-regexp", "^delta" }
            local output = vim.fn.systemlist(command)
            equal(vim.v.shell_error, 0, schema .. " Delta git-config parse")
            local parsed_delta = {}
            for _, key in ipairs(output) do
                parsed_delta[key] = true
            end
            equal(sorted_keys(parsed_delta), sorted_keys(delta_keys), schema .. " Delta keys")
            local delta_content = read_all(delta_path)
            for _, mapping in ipairs({
                'minus-style = syntax "' .. colors.diff_delete_bg .. '"',
                'minus-emph-style = syntax "' .. colors.diff_delete_emphasis .. '"',
                'plus-style = syntax "' .. colors.diff_add_bg .. '"',
                'plus-emph-style = syntax "' .. colors.diff_add_emphasis .. '"',
                'line-numbers-minus-style = "' .. colors.diff_delete .. '"',
                'line-numbers-plus-style = "' .. colors.diff_add .. '"',
            }) do
                truthy(delta_content:find(mapping, 1, true), schema .. " Delta missing " .. mapping)
            end
            local light = vim.fn.system({ "git", "config", "--file", delta_path, "--get", "delta.light" }):gsub("%s+$", "")
            equal(vim.v.shell_error, 0, schema .. " Delta light parse")
            equal(light, palettes.schemas[schema].appearance == "light" and "true" or "false", schema .. " Delta light mode")

            local tuxedo = {}
            for key, value in read_all(path("tuxedo", schema)):gmatch("^([%w_]+) = ([^\n]+)") do
                tuxedo[key] = value
            end
            for key, value in read_all(path("tuxedo", schema)):gmatch("\n([%w_]+) = ([^\n]+)") do
                tuxedo[key] = value
            end
            equal(sorted_keys(tuxedo), sorted_keys(tuxedo_keys), schema .. " Tuxedo keys")
            equal(tuxedo.name, palettes.schemas[schema].display_name, schema .. " Tuxedo palette name")
            for key, value in pairs(tuxedo) do
                if key ~= "name" then
                    truthy(value:match("^#%x%x%x%x%x%x$"), schema .. " Tuxedo " .. key .. " is not hex")
                end
            end
        end
    end)

    test("auto-install destinations remain the exact safe five", function()
        local apps_config = require("flume.extras").get_apps()
        local expected = {
            ghostty = "~/.config/ghostty/themes/flume",
            kitty = "~/.config/kitty/themes/flume.conf",
            opencode = "~/.config/opencode/themes/flume.json",
            tmux = "~/.tmux/flume-theme.conf",
            lsd = "~/.config/lsd/colors.yaml",
        }
        equal(sorted_keys(apps_config), sorted_keys(expected), "auto-install app set")
        for app, destination in pairs(expected) do
            equal(apps_config[app].dest, destination, app .. " safe destination")
        end

        local instructions = table.concat(require("flume.extras").get_instruction_lines(), "\n")
        truthy(not instructions:find("ln -sf", 1, true), "manual instructions force-replace destinations")
        truthy(instructions:find("if [ -e '", 1, true), "manual instructions do not refuse existing files")
        truthy(instructions:find("ln -s '", 1, true), "manual instructions do not shell-quote links")
    end)

    test("generated palette manifest matches canonical Lua palette", function()
        equal(read_all("docs/palette-manifest.md"), require("flume.manifest").render(), "palette manifest drift")
    end)
end

return M
