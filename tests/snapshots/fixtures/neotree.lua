-- Real Neo-tree and devicons, against an isolated project with fixed Git states.
vim.fn.mkdir(vim.fn.stdpath('data'), 'p')
for _, plugin in ipairs({ 'plenary', 'nui', 'devicons', 'neo-tree' }) do
    vim.opt.runtimepath:append('/opt/tools/' .. plugin)
end
require('nvim-web-devicons').setup()
local editor = vim.api.nvim_get_current_win()
vim.api.nvim_buf_set_name(0, '/tmp/flume-demo/src/main.go')
require('neo-tree').setup({
    close_if_last_window = false,
    enable_diagnostics = false,
    git_status_async = false,
    sources = { 'filesystem' },
    source_selector = { winbar = false, statusline = false },
    window = { width = 32 },
    filesystem = {
        bind_to_cwd = false,
        async_directory_scan = 'never',
        use_libuv_file_watcher = false,
        filtered_items = { hide_dotfiles = true, hide_gitignored = true },
    },
    event_handlers = {
        { event = 'after_render', handler = function(state)
            if state.winid and vim.api.nvim_win_is_valid(state.winid) then
                vim.wo[state.winid].statusline = '  Neo-tree %=files  '
            end
            local lines = vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)
            local text = table.concat(lines, '\n')
            if text:find('main.go', 1, true) and text:find('README.md', 1, true)
                and text:find('notes.md', 1, true) then
                vim.fn.writefile({ vim.json.encode({
                    plugin = 'neo-tree', source = 'filesystem', icons = true,
                    git_status = true, selected_file = 'src/main.go',
                    sidebar_lines = lines,
                }) }, '/tmp/neotree-ready.json')
            end
        end },
    },
})
require('neo-tree.command').execute({
    action = 'show', source = 'filesystem', position = 'left',
    dir = '/tmp/flume-demo', reveal_file = '/tmp/flume-demo/src/main.go',
})
vim.api.nvim_set_current_win(editor)
vim.cmd('redraw')
