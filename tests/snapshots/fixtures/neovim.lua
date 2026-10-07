vim.opt.runtimepath:prepend('/repo')
vim.opt.runtimepath:prepend('/opt/treesitter')
vim.opt.swapfile = false
vim.opt.shadafile = 'NONE'
vim.opt.guicursor = 'a:block-blinkon0'
require('flume').setup({ schema = vim.env.FLUME_SHOWCASE_SCHEMA, watch_sync = false, follow_sync = false })
local renderers = { syntax = 'showcase.lua', selection = 'states.lua', completion = 'states.lua', lsp = 'lsp-showcase.lua' }
dofile(assert(renderers[vim.env.FLUME_CAPTURE_KIND]))
if vim.env.FLUME_LUALINE == '1' then
    vim.opt.runtimepath:append('/opt/tools/lualine')
    require('lualine').setup({
        options = { theme = 'flume', icons_enabled = false },
        sections = { lualine_a = { 'mode' }, lualine_b = { 'filename' },
            lualine_c = { function() return vim.g.flume_vhs_ready and 'Flume preview' or '' end },
            lualine_x = { 'filetype' }, lualine_y = { 'progress' }, lualine_z = { 'location' } },
    })
end
-- The renderer itself must report parser/state/server readiness before VHS sees this.
vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = function()
    local timer = vim.uv.new_timer()
    local ready = false
    timer:start(20, 20, vim.schedule_wrap(function()
        if ready then return end
        if vim.fn.filereadable(vim.env.FLUME_SHOWCASE_METADATA) == 1 then
            ready = true
            timer:stop()
            timer:close()
            if vim.env.FLUME_LUALINE == '1' then
                vim.g.flume_vhs_ready = true
                require('lualine').refresh()
            else
                vim.wo.statusline = vim.wo.statusline .. '  Flume preview '
            end
            vim.cmd('redraw')
        end
    end))
end })
