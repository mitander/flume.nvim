local flume = require("flume")
local schema = flume.config.schema
flume.load(schema, require("flume.palette").get(schema).colorscheme)
vim.notify_once(
    "Flume: colorscheme flume is a compatibility alias. Use setup({ schema = ... }) or a named colorscheme. See :help flume-migration.",
    vim.log.levels.WARN
)
