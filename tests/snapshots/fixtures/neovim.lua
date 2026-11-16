vim.opt.runtimepath:prepend('/repo')
vim.opt.runtimepath:prepend('/opt/treesitter')
vim.opt.swapfile = false
vim.opt.shadafile = 'NONE'
vim.opt.guicursor = 'n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,a:blinkon0'
require('flume').setup({ schema = vim.env.FLUME_SHOWCASE_SCHEMA, watch_sync = false, follow_sync = false })
-- Keep the statusline hidden during renderer startup, including LSP attachment.
vim.o.laststatus = 0
vim.env.FLUME_BLINK_RUNTIME = '/opt/tools/blink'
local renderers = { syntax = 'showcase.lua', selection = 'states.lua', completion = 'completion.lua', lsp = 'lsp-showcase.lua' }
dofile(assert(renderers[vim.env.FLUME_CAPTURE_KIND]))

-- Reveal real status information only after parser/state/server readiness.
-- The capture waits for the location field, not a decorative readiness label.
vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = function()
    local timer = vim.uv.new_timer()
    local ready = false
    timer:start(20, 20, vim.schedule_wrap(function()
        if ready then return end
        if vim.fn.filereadable(vim.env.FLUME_SHOWCASE_METADATA) == 1 then
            ready = true
            timer:stop()
            timer:close()
            vim.o.laststatus = 2
            if vim.env.FLUME_LUALINE == '1' then
                vim.opt.runtimepath:append('/opt/tools/devicons')
                vim.opt.runtimepath:append('/opt/tools/lualine')
                require('nvim-web-devicons').setup()
                require('lualine').setup({
                    options = { theme = 'flume', icons_enabled = true },
                    sections = { lualine_a = { 'mode' }, lualine_b = { 'filename' },
                        lualine_c = {}, lualine_x = { 'filetype' },
                        lualine_y = { 'progress' }, lualine_z = { 'location' } },
                })
                -- Lualine queues its first refresh. Observe it without forcing a redraw or theme.
                local attempts = 0
                local function observe_lualine()
                    local rendered = vim.api.nvim_eval_statusline(vim.wo.statusline, { highlights = true })
                    if rendered.str == '' then
                        attempts = attempts + 1
                        assert(attempts < 100, 'Lualine did not render a statusline')
                        vim.defer_fn(observe_lualine, 20)
                        return
                    end
                    local highlights = {}
                    for _, span in ipairs(rendered.highlights) do
                        for _, group in ipairs(span.groups or { span.group }) do
                            if group:match('^lualine_') then
                                highlights[group] = vim.api.nvim_get_hl(0, { name = group, link = false })
                            end
                        end
                    end
                    vim.fn.writefile({ vim.json.encode({
                        plugin = 'lualine', theme = require('lualine').get_config().options.theme,
                        statusline = rendered.str, highlights = highlights,
                    }) }, '/tmp/lualine-ready.json')
                end
                observe_lualine()
            end
            if vim.env.FLUME_NEOTREE == '1' then
                dofile('/repo/tests/snapshots/fixtures/neotree.lua')
            end
            vim.cmd('redraw')
        end
    end))
end })
