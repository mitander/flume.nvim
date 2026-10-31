# Optional Flume tool setup for Fish 3.5+. Installed separately from syntax colors.
# Resolve the conf.d symlink, then keep the stable current path rather than a set.
set -l flume_file (path resolve -- (status filename))
set -l flume_current (path dirname -- (path dirname -- "$flume_file"))/current

# Normal startup preserves caller choices. --adopt explicitly replaces session exports.
# Global variables shadow persistent universal choices without modifying them.
set -l flume_adopt 0
if test "$argv[1]" = --adopt
    set flume_adopt 1
end
if test "$flume_adopt" = 1; or not set -q FZF_DEFAULT_OPTS_FILE
    set -gx FZF_DEFAULT_OPTS_FILE "$flume_current/fzf.opts"
end
if command -q lazygit
    if test "$flume_adopt" = 1; or not set -q LG_CONFIG_FILE
        # Ask the application rather than duplicating its OS, XDG and legacy-path rules.
        set -l lazygit_dir (command lazygit --print-config-dir)
        if test $status -eq 0; and test -n "$lazygit_dir"
            set -l lazygit_config "$lazygit_dir/config.yml"
            if test -f "$lazygit_config"
                set -gx LG_CONFIG_FILE "$lazygit_config,$flume_current/lazygit.yml"
            else
                set -gx LG_CONFIG_FILE "$flume_current/lazygit.yml"
            end
        else
            printf 'Flume: could not locate Lazygit config. LG_CONFIG_FILE was left unchanged.\n' >&2
        end
    end
end

# Override only non-sticky world-writable directories. Keep all other rules.
# Replacing this one key, rather than appending on every source, is idempotent.
set -l flume_ls_colors
for entry in (string split : -- "$LS_COLORS")
    if test -n "$entry"; and not string match -q 'ow=*' -- "$entry"
        set -a flume_ls_colors "$entry"
    end
end
set -gx LS_COLORS (string join : -- $flume_ls_colors 'ow=0;35')
