local M = {}

function M.register(test, equal, truthy)
    if vim.fn.executable("fish") ~= 1 then
        return
    end

    test("installed Fish tool setup uses shared state and preserves personal choices", function()
        local extras = require("flume.extras")
        local state = require("flume.state")
        local app = extras.get_apps().fish_tools
        local original_data, original_dest = vim.env.FLUME_DATA_DIR, app.dest
        local original_select, original_notify = vim.ui.select, vim.notify
        local flume = require("flume")
        local original_schema = flume.config.schema
        local root = vim.fn.tempname() .. " space's"
        vim.fn.mkdir(root, "p")
        root = assert((vim.uv or vim.loop).fs_realpath(root))
        local config = root .. "/config"
        local current = root .. "/shared/current"
        local result
        vim.fn.mkdir(config .. "/fish", "p")
        vim.fn.mkdir(config .. "/lazygit", "p")
        vim.fn.mkdir(root .. "/bin", "p")
        vim.fn.writefile({
            "#!/bin/sh",
            '[ "$1" = --print-config-dir ] || exit 2',
            'printf "%s\\n" "${FLUME_TEST_LAZY_DIR:-$XDG_CONFIG_HOME/lazygit}"',
        }, root .. "/bin/lazygit")
        assert(vim.fn.setfperm(root .. "/bin/lazygit", "rwx------") == 1)
        vim.fn.writefile({ "gui: {}" }, config .. "/lazygit/config.yml")
        vim.env.FLUME_DATA_DIR = root .. "/shared"
        app.dest = config .. "/fish/conf.d/flume-tools.fish"
        local choice = "Use Flume settings"
        vim.ui.select = function(items, _, callback)
            equal(
                table.concat(items, ","),
                "Use Flume settings,Keep existing settings,Do not install",
                "adoption choices"
            )
            callback(choice)
        end
        vim.notify = function() end

        local function run(script, overrides)
            local command = {
                "env",
                "-u",
                "FZF_DEFAULT_OPTS_FILE",
                "-u",
                "LG_CONFIG_FILE",
                "HOME=" .. root,
                "PATH=" .. root .. "/bin:" .. vim.env.PATH,
                "XDG_CONFIG_HOME=" .. config,
                "LS_COLORS=di=01;34:ow=30;42:tw=30;43:*.rs=35",
            }
            vim.list_extend(command, overrides or {})
            vim.list_extend(command, { "fish", "--private", "-c", script })
            local output = vim.fn.system(command)
            equal(vim.v.shell_error, 0, "Fish tool startup")
            return output
        end

        local ok, err = xpcall(function()
            state.activate("dusk")
            extras.install("fish_tools", function(completed)
                result = completed
            end)
            equal(result.status, "linked", "tool setup installation")
            equal(result.settings, "adopt", "explicit adoption selection")
            truthy(result.reload_command:match(" %-%-adopt$"), "one-command session adoption")
            truthy(vim.fn.filereadable(app.dest) == 1, "installed tool fragment readable")
            equal(
                run("printf '%s\\n' $FZF_DEFAULT_OPTS_FILE $LG_CONFIG_FILE $LS_COLORS"),
                current
                    .. "/fzf.opts\n"
                    .. config
                    .. "/lazygit/config.yml,"
                    .. current
                    .. "/lazygit.yml\n"
                    .. "di=01;34:tw=30;43:*.rs=35:ow=0;35\n",
                "stable paths and targeted filename override"
            )
            equal(
                run(
                    'source "$__fish_config_dir/conf.d/flume-tools.fish"; '
                        .. "source \"$__fish_config_dir/conf.d/flume-tools.fish\"; printf '%s\\n' $LS_COLORS"
                ),
                "di=01;34:tw=30;43:*.rs=35:ow=0;35\n",
                "repeated sourcing is idempotent"
            )
            equal(
                run("printf '%s\\n' $FZF_DEFAULT_OPTS_FILE $LG_CONFIG_FILE", {
                    "FZF_DEFAULT_OPTS_FILE=/custom/fzf",
                    "LG_CONFIG_FILE=/custom/lazygit",
                }),
                "/custom/fzf\n/custom/lazygit\n",
                "caller tool choices preserved"
            )
            equal(
                run(result.reload_command .. "; printf '%s\\n' $FZF_DEFAULT_OPTS_FILE $LG_CONFIG_FILE", {
                    "FZF_DEFAULT_OPTS_FILE=/old/fzf",
                    "LG_CONFIG_FILE=/old/lazygit",
                }),
                current .. "/fzf.opts\n" .. config .. "/lazygit/config.yml," .. current .. "/lazygit.yml\n",
                "printed command replaces stale session exports without restarting Fish"
            )
            equal(
                run(
                    "set -U FZF_DEFAULT_OPTS_FILE /persistent/fzf; set -U LG_CONFIG_FILE /persistent/lazygit; "
                        .. result.reload_command
                        .. "; printf '%s\\n' $FZF_DEFAULT_OPTS_FILE $LG_CONFIG_FILE; "
                        .. "set -e -g FZF_DEFAULT_OPTS_FILE; set -e -g LG_CONFIG_FILE; "
                        .. "printf '%s\\n' $FZF_DEFAULT_OPTS_FILE $LG_CONFIG_FILE; "
                        .. "set -e -U FZF_DEFAULT_OPTS_FILE; set -e -U LG_CONFIG_FILE"
                ),
                current
                    .. "/fzf.opts\n"
                    .. config
                    .. "/lazygit/config.yml,"
                    .. current
                    .. "/lazygit.yml\n"
                    .. "/persistent/fzf\n/persistent/lazygit\n",
                "adoption shadows but does not erase persistent universal choices"
            )
            choice = "Keep existing settings"
            extras.install("fish_tools", function(completed)
                result = completed
            end)
            equal(result.status, "already_linked", "preserving selection is idempotent")
            equal(result.settings, "preserve", "explicit preservation selection")
            truthy(not result.reload_command:find("--adopt", 1, true), "preservation command has no takeover flag")
            truthy(result.next_step:find("not been taken over", 1, true), "preservation is not reported as takeover")
            equal(
                run(result.reload_command .. "; printf '%s\\n' $FZF_DEFAULT_OPTS_FILE $LG_CONFIG_FILE", {
                    "FZF_DEFAULT_OPTS_FILE=/custom/fzf",
                    "LG_CONFIG_FILE=/custom/lazygit",
                }),
                "/custom/fzf\n/custom/lazygit\n",
                "printed preservation command respects tool settings"
            )
            vim.fn.mkdir(root .. "/native config", "p")
            vim.fn.writefile({ "gui: {}" }, root .. "/native config/config.yml")
            equal(
                run("printf '%s\\n' $LG_CONFIG_FILE", { "FLUME_TEST_LAZY_DIR=" .. root .. "/native config" }),
                root .. "/native config/config.yml," .. current .. "/lazygit.yml\n",
                "application owns native config discovery"
            )
            equal(run("printf '%s\\n' $LS_COLORS", { "LS_COLORS=" }), "ow=0;35\n", "empty filename rules")
            vim.fn.writefile(
                { "set -gx LS_COLORS personal", "set -gx FZF_DEFAULT_OPTS_FILE /personal/fzf" },
                config .. "/fish/config.fish"
            )
            equal(
                run("printf '%s\\n' $LS_COLORS $FZF_DEFAULT_OPTS_FILE"),
                "personal\n/personal/fzf\n",
                "later config wins"
            )
            vim.fn.delete(config .. "/fish/config.fish")
            vim.fn.delete(config .. "/lazygit/config.yml")
            equal(run("printf '%s\\n' $LG_CONFIG_FILE"), current .. "/lazygit.yml\n", "absent base config is optional")

            state.activate("opal")
            equal(
                run("printf '%s\\n' $FZF_DEFAULT_OPTS_FILE"),
                current .. "/fzf.opts\n",
                "switch retains stable tool path"
            )
            equal(vim.fn.readfile(current .. "/schema")[1], "opal", "actual shared switch")

            local uv = vim.uv or vim.loop
            local old_set = assert(uv.fs_readlink(current))
            vim.fn.writefile({ "# older tool setup" }, current .. "/fish-tools.fish")
            flume.config.schema = "mesa"
            extras.install("fish_tools", function(completed)
                result = completed
            end)
            equal(result.status, "already_linked", "refresh retains the stable install link")
            equal(
                vim.fn.readfile(current .. "/schema")[1],
                "opal",
                "refresh preserves shared palette, not editor choice"
            )
            truthy(uv.fs_readlink(current) ~= old_set, "stale helper published through a new complete set")
            equal(
                vim.fn.readfile(root .. "/shared/" .. old_set .. "/fish-tools.fish")[1],
                "# older tool setup",
                "old set retained"
            )
            equal(
                table.concat(vim.fn.readfile(current .. "/fish-tools.fish"), "\n"),
                table.concat(vim.fn.readfile(extras.get_plugin_dir() .. "/extras/fish/flume-tools.fish"), "\n"),
                "reinstall publishes the shipped helper"
            )
        end, debug.traceback)

        flume.config.schema = original_schema
        vim.env.FLUME_DATA_DIR, app.dest = original_data, original_dest
        vim.ui.select, vim.notify = original_select, original_notify
        vim.fn.delete(root, "rf")
        if not ok then
            error(err)
        end
    end)
end

return M
