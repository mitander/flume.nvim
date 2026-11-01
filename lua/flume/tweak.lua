local M = {}

local namespace = vim.api.nvim_create_namespace("FlumeTweak")
local samples = require("flume.tweak_samples")
local session
local header_lines = 6
local priority_roles = {
    "syntax_function",
    "syntax_type",
    "syntax_keyword",
    "syntax_property",
    "syntax_namespace",
    "syntax_string",
    "syntax_boolean",
    "syntax_constant",
    "syntax_primary",
    "syntax_comment",
    "bg",
    "surface",
    "active_line",
    "selection_bg",
    "selection_fg",
    "muted",
    "error",
    "warning",
    "match",
}
local state_groups = {
    "Visual",
    "PmenuSel",
    "Search",
    "DiffText",
    "DiffAdd",
    "DiffDelete",
    "DiagnosticVirtualTextError",
    "DiagnosticVirtualTextWarn",
}

local preview_options = {
    number = false,
    relativenumber = false,
    wrap = false,
    spell = false,
    diff = false,
    scrollbind = false,
    cursorbind = false,
    cursorline = false,
    cursorcolumn = false,
    winfixwidth = false,
    winfixheight = false,
    winhighlight = "",
    conceallevel = 0,
    foldmethod = "manual",
    signcolumn = "no",
    statusline = " FlumeTweak ",
}

local function set_window_options(window, options)
    -- Diff mode changes folding/binding options, so settle it before the rest.
    vim.wo[window].diff = options.diff
    for name, value in pairs(options) do
        if name ~= "diff" then
            vim.wo[window][name] = value
        end
    end
end

local function active(state)
    return session == state and not state.closing
end

local function is_hex(value)
    return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") ~= nil
end

local function mix(color, target, amount)
    local channels = {}
    for offset = 2, 6, 2 do
        local value = tonumber(color:sub(offset, offset + 1), 16)
        channels[#channels + 1] = math.floor(value + (target - value) * amount + 0.5)
    end
    return string.format("#%02x%02x%02x", channels[1], channels[2], channels[3])
end

local function set_lines(buffer, lines)
    vim.bo[buffer].modifiable = true
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
    vim.bo[buffer].modifiable = false
    vim.bo[buffer].modified = false
end

local function colors_for(state)
    return vim.tbl_extend("force", {}, state.base[state.schema], state.edits[state.schema])
end

local function current_role(state)
    local row = vim.api.nvim_win_get_cursor(state.roles_window)[1]
    return state.roles[row - header_lines]
end

local function close(state)
    if session ~= state then
        return
    end
    session = nil
    state.closing = true
    pcall(vim.api.nvim_del_augroup_by_id, state.group)
    local was_inside = vim.api.nvim_get_current_tabpage() == state.tab
    for _, window in ipairs(state.windows) do
        if vim.api.nvim_win_is_valid(window) then
            vim.api.nvim_win_set_hl_ns(window, 0)
            pcall(vim.api.nvim_win_close, window, true)
            if vim.api.nvim_win_is_valid(window) then
                -- The final editor window cannot close. Reuse it as an ordinary
                -- window, not as a preview-colored or preview-configured pane.
                set_window_options(window, state.origin_options)
            end
        end
    end
    -- Only scratch buffers created by this session may be discarded. If this
    -- became the last tab, deleting its scratch buffer leaves an empty editor.
    for _, buffer in ipairs(state.buffers) do
        if vim.api.nvim_buf_is_valid(buffer) then
            pcall(vim.api.nvim_buf_delete, buffer, { force = true })
        end
    end
    if was_inside then
        if vim.api.nvim_win_is_valid(state.origin) then
            vim.api.nvim_set_current_win(state.origin)
        elseif vim.api.nvim_buf_is_valid(state.origin_buffer) then
            vim.api.nvim_set_current_buf(state.origin_buffer)
        end
    end
end

local function load_sample(state)
    local sample = samples[state.sample]
    local buffer = state.sample_buffer
    pcall(vim.treesitter.stop, buffer)
    vim.diagnostic.reset(namespace, buffer)
    local lines = vim.split(sample.code:gsub("\n$", ""), "\n", { plain = true })
    set_lines(buffer, lines)
    vim.api.nvim_buf_set_name(buffer, "flume-tweak://sample/" .. sample.name)
    vim.api.nvim_buf_call(buffer, function()
        -- Do not trigger FileType hooks, LSP clients or project tooling for a
        -- scratch sample. Use actual installed parser queries or plain text.
        vim.cmd("noautocmd setlocal filetype=" .. sample.filetype .. " syntax=")
        vim.cmd("syntax clear")
        vim.b.current_syntax = nil
    end)
    local queries_ok, queries = pcall(vim.treesitter.query.get_files, sample.language, "highlights")
    local parser_ok = queries_ok and #queries > 0 and pcall(vim.treesitter.start, buffer, sample.language)
    if parser_ok then
        state.capture = "Tree-sitter: " .. sample.language
    else
        -- Sourcing syntax files can write global highlight definitions. An
        -- isolated preview must not load them as a substitute for a parser.
        state.capture = "Plain text (no parser/query)"
    end
    vim.diagnostic.set(namespace, buffer, {
        {
            lnum = 5,
            col = 0,
            severity = vim.diagnostic.severity.ERROR,
            message = "Example error diagnostic",
            source = "FlumeTweak",
        },
        {
            lnum = 8,
            col = 0,
            severity = vim.diagnostic.severity.WARN,
            message = "Example warning diagnostic",
            source = "FlumeTweak",
        },
    }, { virtual_text = { prefix = "●" }, signs = true, underline = true })
    vim.wo[state.sample_window].statusline = " " .. sample.name .. " | " .. state.capture .. " | v: select text "
    vim.api.nvim_win_set_cursor(state.sample_window, { 1, 0 })
end

local function render(state)
    local colors = colors_for(state)
    -- Role exploration intentionally bypasses exact group overrides and uses
    -- opaque surfaces. Global config, highlights and terminal inks are untouched.
    require("flume").set_highlights(namespace, colors, { styles = state.styles })
    vim.api.nvim_set_hl(namespace, "FlumeTweakHeading", { fg = colors.accent, bold = true })
    local lines = {
        "FlumeTweak · " .. state.schema .. " · " .. vim.tbl_count(state.edits[state.schema]) .. " edits",
        "h/l shade  c ink  Enter hex  r reset",
        "p/P palette  s/S sample  y copy",
        "q/Esc close · editor unchanged",
        state.capture,
        "",
    }
    for _, role in ipairs(state.roles) do
        lines[#lines + 1] =
            string.format("■ %-26s %s%s", role, colors[role], state.edits[state.schema][role] and " *" or "")
        vim.api.nvim_set_hl(namespace, "FlumeTweakSwatch_" .. role, { fg = colors[role] })
    end
    local cursor = vim.api.nvim_win_get_cursor(state.roles_window)
    set_lines(state.roles_buffer, lines)
    vim.api.nvim_buf_clear_namespace(state.roles_buffer, namespace, 0, -1)
    vim.api.nvim_buf_add_highlight(state.roles_buffer, namespace, "FlumeTweakHeading", 0, 0, -1)
    for index, role in ipairs(state.roles) do
        vim.api.nvim_buf_add_highlight(
            state.roles_buffer,
            namespace,
            "FlumeTweakSwatch_" .. role,
            header_lines + index - 1,
            0,
            #"■"
        )
    end
    vim.api.nvim_win_set_cursor(state.roles_window, cursor)
end

local function edit_color(state, role, value)
    value = value:lower()
    state.edits[state.schema][role] = value ~= state.base[state.schema][role] and value or nil
    render(state)
end

local function change_shade(state, direction)
    local role = current_role(state)
    if not role then
        return
    end
    local anchor = state.anchors[state.schema][role] or state.base[state.schema][role]
    local candidates =
        { mix(anchor, 0, 0.16), mix(anchor, 0, 0.08), anchor, mix(anchor, 255, 0.08), mix(anchor, 255, 0.16) }
    local index = ((state.candidates[state.schema][role] or 3) - 1 + direction) % #candidates + 1
    state.candidates[state.schema][role] = index
    edit_color(state, role, candidates[index])
end

local function enter_color(state)
    local role = current_role(state)
    if not role then
        return
    end
    local schema, revision = state.schema, state.revision
    vim.ui.input({ prompt = role .. " (#RRGGBB): ", default = colors_for(state)[role] }, function(value)
        if not active(state) or state.schema ~= schema or state.revision ~= revision or value == nil then
            return
        end
        value = type(value) == "string" and vim.trim(value) or value
        if not is_hex(value) then
            vim.notify("FlumeTweak expects a six-digit #RRGGBB color.", vim.log.levels.ERROR)
            return
        end
        state.anchors[schema][role] = value:lower()
        state.candidates[schema][role] = 3
        edit_color(state, role, value)
    end)
end

local function choose_ink(state)
    local role = current_role(state)
    if not role then
        return
    end
    local schema, colors, revision = state.schema, colors_for(state), state.revision
    vim.ui.select(vim.deepcopy(state.roles), {
        prompt = "Candidate ink for " .. role,
        format_item = function(candidate)
            return candidate .. " " .. colors[candidate]
        end,
    }, function(candidate)
        if not active(state) or state.schema ~= schema or state.revision ~= revision or not colors[candidate] then
            return
        end
        state.anchors[schema][role] = colors[candidate]
        state.candidates[schema][role] = 3
        edit_color(state, role, colors[candidate])
    end)
end

local function copy_overrides(state)
    local lines = { "schema_overrides = {" }
    for _, schema in ipairs(require("flume.palette").schema_order) do
        local roles = vim.tbl_keys(state.edits[schema])
        table.sort(roles)
        if #roles > 0 then
            lines[#lines + 1] = "    " .. schema .. " = {"
            for _, role in ipairs(roles) do
                lines[#lines + 1] = string.format('        %s = "%s",', role, state.edits[schema][role])
            end
            lines[#lines + 1] = "    },"
        end
    end
    if #lines == 1 then
        vim.notify("FlumeTweak has no edits to copy.", vim.log.levels.INFO)
        return
    end
    lines[#lines + 1] = "},"
    vim.fn.setreg('"', table.concat(lines, "\n"), "v")
    vim.notify(
        "Copied draft schema_overrides to the unnamed register. Merge them into setup to keep them.",
        vim.log.levels.INFO
    )
end

local function cycle_palette(state, direction)
    local order = require("flume.palette").schema_order
    local index = 1
    for position, schema in ipairs(order) do
        if schema == state.schema then
            index = position
            break
        end
    end
    state.schema = order[(index - 1 + direction) % #order + 1]
    render(state)
end

local function cycle_sample(state, direction)
    state.sample = (state.sample - 1 + direction) % #samples + 1
    load_sample(state)
    render(state)
end

local function scratch(state, name)
    local buffer = vim.api.nvim_create_buf(false, true)
    state.buffers[#state.buffers + 1] = buffer
    vim.api.nvim_buf_set_name(buffer, "flume-tweak://" .. name)
    vim.bo[buffer].bufhidden = "wipe"
    vim.bo[buffer].swapfile = false
    vim.bo[buffer].undofile = false
    return buffer
end

local function configure_window(state, buffer)
    local window = vim.api.nvim_get_current_win()
    state.windows[#state.windows + 1] = window
    vim.api.nvim_win_set_buf(window, buffer)
    vim.api.nvim_win_set_hl_ns(window, namespace)
    set_window_options(window, preview_options)
    return window
end

local function map_actions(state)
    local common = {
        q = function()
            close(state)
        end,
        ["<Esc>"] = function()
            close(state)
        end,
        p = function()
            cycle_palette(state, 1)
        end,
        P = function()
            cycle_palette(state, -1)
        end,
        s = function()
            cycle_sample(state, 1)
        end,
        S = function()
            cycle_sample(state, -1)
        end,
        y = function()
            copy_overrides(state)
        end,
    }
    for _, buffer in ipairs(state.buffers) do
        for key, action in pairs(common) do
            local run = action
            vim.keymap.set("n", key, function()
                if active(state) then
                    run()
                end
            end, { buffer = buffer, silent = true, nowait = true })
        end
    end
    local roles = {
        h = function()
            change_shade(state, -1)
        end,
        l = function()
            change_shade(state, 1)
        end,
        c = function()
            choose_ink(state)
        end,
        ["<CR>"] = function()
            enter_color(state)
        end,
        r = function()
            local role = current_role(state)
            if role then
                state.anchors[state.schema][role], state.candidates[state.schema][role] = nil, nil
                state.edits[state.schema][role] = nil
                render(state)
            end
        end,
    }
    for key, action in pairs(roles) do
        local run = action
        vim.keymap.set("n", key, function()
            if active(state) then
                run()
            end
        end, { buffer = state.roles_buffer, silent = true, nowait = true })
    end
end

---Open a scratch-tab preview. Drafts only affect its highlight namespace.
---@param schema? string
---@return boolean opened
function M.open(schema)
    if not vim.o.termguicolors then
        vim.notify("FlumeTweak needs true-color rendering. Enable :set termguicolors first.", vim.log.levels.WARN)
        return false
    end
    local palettes = require("flume.palette")
    if session and active(session) and vim.api.nvim_tabpage_is_valid(session.tab) then
        vim.api.nvim_set_current_tabpage(session.tab)
        if schema then
            session.schema = palettes.resolve(schema)
            render(session)
        end
        return true
    end
    if session then
        close(session)
    end
    schema = palettes.resolve(schema or require("flume").config.schema)
    if vim.o.columns < 80 or vim.o.lines < 22 then
        vim.notify("FlumeTweak needs at least 80 columns and 22 rows.", vim.log.levels.WARN)
        return false
    end
    local state = {
        schema = schema,
        revision = 0,
        sample = 1,
        base = {},
        edits = {},
        anchors = {},
        candidates = {},
        roles = {},
        buffers = {},
        windows = {},
        origin = vim.api.nvim_get_current_win(),
        origin_buffer = vim.api.nvim_get_current_buf(),
        origin_options = {},
        styles = vim.deepcopy(require("flume").config.styles),
    }
    for name in pairs(preview_options) do
        state.origin_options[name] = vim.wo[state.origin][name]
    end
    local known = {}
    for _, role in ipairs(priority_roles) do
        state.roles[#state.roles + 1], known[role] = role, true
    end
    local remaining = vim.tbl_keys(palettes.get(schema).colors)
    table.sort(remaining)
    for _, role in ipairs(remaining) do
        if not known[role] then
            state.roles[#state.roles + 1] = role
        end
    end
    for _, name in ipairs(palettes.schema_order) do
        local canonical = palettes.get(name).colors
        local resolved = require("flume").get_colors(name)
        state.base[name], state.edits[name], state.anchors[name], state.candidates[name] = {}, {}, {}, {}
        for role, value in pairs(canonical) do
            state.base[name][role] = is_hex(resolved[role]) and resolved[role]:lower() or value
        end
    end
    session = state
    local ok, failure = xpcall(function()
        -- Reuse the invoking buffer in a new tab before substituting scratch
        -- buffers, so opening the tool does not leave a listed empty buffer.
        vim.cmd("tab split")
        state.tab = vim.api.nvim_get_current_tabpage()
        state.roles_buffer = scratch(state, "roles")
        state.roles_window = configure_window(state, state.roles_buffer)
        vim.cmd("rightbelow vsplit")
        state.sample_buffer = scratch(state, "sample")
        state.sample_window = configure_window(state, state.sample_buffer)
        vim.wo[state.sample_window].number = true
        vim.wo[state.sample_window].cursorline = true
        vim.wo[state.sample_window].signcolumn = "yes"
        vim.cmd("rightbelow split")
        local states_buffer = scratch(state, "states")
        local states_window = configure_window(state, states_buffer)
        local lines = { "UI swatches (not live popups)" }
        for _, group in ipairs(state_groups) do
            lines[#lines + 1] = group .. ": sample text"
        end
        set_lines(states_buffer, lines)
        for index, group in ipairs(state_groups) do
            vim.api.nvim_buf_add_highlight(states_buffer, namespace, group, index, #group + 2, -1)
        end
        vim.api.nvim_win_set_height(states_window, #lines)
        vim.api.nvim_win_set_width(state.roles_window, 40)
        vim.wo[state.roles_window].cursorline = true
        load_sample(state)
        render(state)
        map_actions(state)
        state.group = vim.api.nvim_create_augroup("FlumeTweak", { clear = true })
        vim.api.nvim_create_autocmd("ColorScheme", {
            group = state.group,
            callback = function()
                close(state)
            end,
        })
        vim.api.nvim_create_autocmd({ "TabClosed", "BufWipeout" }, {
            group = state.group,
            callback = function(event)
                if event.event == "TabClosed" and vim.api.nvim_tabpage_is_valid(state.tab) then
                    return
                end
                if event.event == "BufWipeout" and not vim.tbl_contains(state.buffers, event.buf) then
                    return
                end
                state.closing = true
                vim.schedule(function()
                    close(state)
                end)
            end,
        })
        vim.api.nvim_set_current_win(state.roles_window)
        vim.api.nvim_win_set_cursor(state.roles_window, { header_lines + 1, 0 })
    end, debug.traceback)
    if not ok then
        close(state)
        error(failure)
    end
    return true
end

---Import validated colors as preview edits, retaining the resolved starting palette.
---Existing edits for the target schema require explicit replacement. Other drafts survive.
---@param path string
---@param replace? boolean
---@return boolean imported
function M.import_file(path, replace)
    local draft, failure = require("flume.tweak_draft").read(path)
    if not draft then
        vim.notify("FlumeTweak import: " .. failure, vim.log.levels.ERROR)
        return false
    end
    if session and active(session) and next(session.edits[draft.schema]) and not replace then
        vim.notify(
            "FlumeTweak import: this palette already has edits. Use :FlumeTweakImport! to replace its draft.",
            vim.log.levels.WARN
        )
        return false
    end
    if not M.open(draft.schema) then
        return false
    end

    local state = session
    state.revision = state.revision + 1
    state.edits[draft.schema], state.anchors[draft.schema], state.candidates[draft.schema] = {}, {}, {}
    for role, value in pairs(draft.colors) do
        if value ~= state.base[draft.schema][role] then
            state.edits[draft.schema][role] = value
        end
        state.anchors[draft.schema][role] = value
    end
    render(state)
    return true
end

return M
