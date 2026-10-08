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
            end
            if vim.env.FLUME_NEOTREE == '1' then
                dofile('/repo/tests/snapshots/fixtures/neotree.lua')
            end
            vim.cmd('redraw')
        end
    end))
end })
