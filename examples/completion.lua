-- Real gopls completion, using Blink's bordered menu and highlighted documentation.
vim.opt.runtimepath:prepend(assert(vim.env.FLUME_BLINK_RUNTIME, 'Set FLUME_BLINK_RUNTIME to a blink.cmp checkout'))
local blink = require('blink.cmp')
local window_highlights = 'Normal:Normal,FloatBorder:FloatBorder,CursorLine:Visual,Search:None'
blink.setup({
    keymap = { preset = 'none' },
    fuzzy = { implementation = 'lua', prebuilt_binaries = { download = false } },
    appearance = { use_nvim_cmp_as_default = true, nerd_font_variant = 'mono' },
    sources = { default = { 'lsp' } },
    completion = {
        list = { selection = { preselect = false, auto_insert = true } },
        menu = {
            border = 'single', winhighlight = window_highlights, scrolloff = 2,
            draw = {
                columns = { { 'kind_icon' }, { 'label', 'label_description', gap = 1 } },
                components = { kind_icon = { text = function() return '' end } },
            },
        },
        documentation = {
            auto_show = true, auto_show_delay_ms = 200,
            window = { border = 'single', winhighlight = window_highlights },
        },
        ghost_text = { enabled = false },
    },
    signature = { enabled = false },
})
if vim.env.FLUME_TS_RUNTIME and vim.env.FLUME_TS_RUNTIME ~= '' then
    vim.opt.runtimepath:prepend(vim.env.FLUME_TS_RUNTIME)
end
local workspace = vim.fn.tempname()
vim.fn.mkdir(workspace, 'p')
local source = vim.fn.readfile('completion.go')
local row, column
for index, line in ipairs(source) do
    if line:find('name := strings.TrimSpace', 1, true) then
        source[index] = line:gsub('TrimSpace', 'TrimS')
        row = index
        column = assert(source[index]:find('(input)', 1, true)) - 1
    end
end
assert(row and column, 'Completion fixture must contain its editing point')
local file = workspace .. '/main.go'
vim.fn.writefile(source, file)
vim.fn.writefile({ 'module flume.fixture', '', 'go 1.23' }, workspace .. '/go.mod')
vim.cmd('edit ' .. vim.fn.fnameescape(file))
local buf = vim.api.nvim_get_current_buf()
vim.bo.filetype = 'go'
vim.bo.swapfile = false
vim.wo.number = true
vim.wo.cursorline = true
vim.wo.signcolumn = 'no'
vim.wo.wrap = false
vim.o.showmode = false
vim.o.ruler = false
vim.wo.statusline = '  INSERT  gopls completion  %t%=line %l  col %c  '
vim.treesitter.start(buf, 'go')
vim.diagnostic.enable(false, { bufnr = buf })
vim.api.nvim_win_set_cursor(0, { row, column })
vim.api.nvim_create_autocmd('VimLeavePre', { once = true, callback = function()
    vim.fn.delete(workspace, 'rf')
end })
local executable = vim.fn.exepath('gopls')
assert(executable ~= '', 'Install gopls')
local version = vim.fn.system({ 'gopls', 'version' })
assert(vim.v.shell_error == 0, 'Cannot identify gopls version')
local client_id = assert(vim.lsp.start({
    name = 'gopls', cmd = { 'gopls' }, root_dir = workspace,
    capabilities = blink.get_lsp_capabilities(),
    settings = { gopls = { semanticTokens = true } },
}, { bufnr = buf }))
assert(vim.wait(45000, function()
    local client = vim.lsp.get_client_by_id(client_id)
    return client and client.initialized
end, 50), 'gopls must initialize before completion')
vim.api.nvim_create_autocmd('InsertEnter', { once = true, callback = function()
    vim.schedule(function()
        -- Manual show selects documentation without changing the incomplete call.
        blink.show({ callback = function() blink.select_next({ auto_insert = false }) end })
        local deadline = vim.uv.now() + 45000
        local timer = vim.uv.new_timer()
        local reported = false
        timer:start(50, 50, vim.schedule_wrap(function()
            if reported then return end
            if vim.uv.now() > deadline then
                reported = true
                timer:stop()
                timer:close()
                error('gopls must render completion candidates and documentation')
            end
            local items = blink.get_items()
            local selected = blink.get_selected_item()
            if blink.is_menu_visible() and #items >= 2 and selected and blink.is_documentation_visible() then
                local docs = require('blink.cmp.completion.windows.documentation')
                local documentation = table.concat(vim.api.nvim_buf_get_lines(docs.win:get_buf(), 0, -1, false), '\n')
                if not documentation:find('TrimSpace', 1, true) then return end
                local highlights = 0
                for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(docs.win:get_buf(),
                    require('blink.cmp.config').appearance.highlight_ns, 0, -1, { details = true })) do
                    if mark[4].hl_group then highlights = highlights + 1 end
                end
                if highlights == 0 then return end
                reported = true
                timer:stop()
                timer:close()
                local candidates = {}
                for _, item in ipairs(items) do
                    candidates[#candidates + 1] = item.label
                end
                assert(table.concat(candidates, ' '):find('TrimSpace', 1, true), 'gopls must offer TrimSpace')
                -- Clear startup messages only after the server-backed UI is ready.
                vim.api.nvim_echo({}, false, {})
                vim.cmd('redraw')
                if vim.env.FLUME_SHOWCASE_METADATA then
                    vim.fn.writefile({ vim.json.encode({
                        nvim = tostring(vim.version()), language = 'go', kind = 'completion',
                        parser = assert(vim.api.nvim_get_runtime_file('parser/go.*', false)[1]),
                        queries = vim.treesitter.query.get_files('go', 'highlights'),
                        completion = true, candidates = candidates, documentation = documentation,
                        frontend = { name = 'blink.cmp', border = 'single', treesitter_highlighting = true },
                        documentation_highlights = highlights,
                        server = { name = 'gopls', version = vim.trim(version), executable = executable,
                            settings = { gopls = { semanticTokens = true } } },
                    }) }, vim.env.FLUME_SHOWCASE_METADATA)
                end
            end
        end))
    end)
end })
vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = function()
    vim.cmd('startinsert')
end })
