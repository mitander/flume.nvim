# Testing

Choose observations that can expose the changed behavior. Defined highlight roles do not prove what
a parser emits. Exact pixels preserve a captured result, but do not decide whether it is readable.
[Development](DEVELOPMENT.md) owns prerequisites and commands.

## Required checks for a change

| Change                                                                               | Checks and observations                                                     |
| ------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| Ordinary source or documentation                                                     | `./scripts/check` and inspection of the finished diff                       |
| Palette roles or exporters                                                           | Ordinary gate, artifact regeneration and validation of generated outputs    |
| Language-provider mapping                                                            | Ordinary gate and the affected real parser/LSP observation                  |
| Named lualine integration                                                            | Ordinary gate and installed-plugin check                                    |
| Capture pipeline, scene, visual baseline or changed visual claims                    | Applicable checks and the affected snapshot lane, followed by visual review |
| External application reload behavior                                                 | Applicable checks and observation in the actual application                 |
| Authorization, durable ordering, recovery, hostile input or frozen external contract | Applicable checks plus independent read-only review                         |

Missing required evidence leaves the change incomplete. Do not activate shared themes or update a
baseline just to make a check pass. Editorial-only changes with unchanged capture inputs and visual
claims do not need new screenshots.

## Test boundaries

The ordinary gate checks Lua formatting/behavior, generated artifacts and manifests, links,
whitespace, syntax and Python tooling. It launches headless Neovim but needs no language parsers,
language servers or external application instances. Preflight validates existing screenshot
provenance and dimensions. It does not capture a new scene.

Cross-process sync checks keep one editor running while a separate headless Neovim publishes with
`FlumeSync`. They inspect the receiver's live global highlight RGB values, not just its schema name.
They cover same-schema color edits, fresh colors on schema switches, local options, unchanged
palettes, failed reads/applications and retrying the same published set. Host reload adapters are
disabled and shared state, source edits and the publisher's home stay private. These checks do not
qualify different installed palette versions or external-application reloads.

[Native language checks](color-system.md#verify-language-highlighting) open representative fixtures
with real Tree-sitter parsers and queries in all four palettes. They do not run language servers.
LSP checks additionally need the relevant server and inspection of semantic-token modifiers.

For the named lualine integration, supply an installed checkout explicitly:

```sh
FLUME_LUALINE_RUNTIME=/path/to/lualine.nvim nvim --headless --clean -c "lua dofile('tests/lualine.lua')"
```

This supplements the parser-free gate. It does not qualify another plugin version or external-app
reload.

## Native shell-tool integration

With Fish 3.5+, fzf, LSD 1.2+, Lazygit, Git, Neovim and Python already installed, run:

```sh
bash tests/fish-tools.sh
```

This copies the plugin into a disposable home before using the public installer. It checks Fish
startup, the installer's exact one-command adoption of stale session exports, real Lazygit
config-directory discovery, fzf's active options file, LSD filename colors and stable Git/Tmux/Pi
file paths. It does not target a live shell, select a shared theme or prove that running Tmux/Pi
instances reloaded. The ordinary gate syntax-checks the script and runs focused Fish setup tests
when Fish is available, without requiring the other applications. Those tests also check
preservation mode, persistent-variable isolation, quoted paths and stale-helper refresh with an
independent editor palette.

Application configuration repositories should test only their own composition, such as retaining
inherited colors and tool settings. Product installation and native tool checks belong here rather
than requiring a particular dotfiles checkout.

### Lazygit selected rows

For Lazygit active-row changes, also run the installed application with Git and Tmux available:

```sh
FLUME_NATIVE_LAZYGIT=1 python3 -m unittest discover -s tests -p 'integration_review.py'
```

This uses a private Tmux server and Git fixture to observe selected-folder foreground and background
RGB values in all four palettes. It retains ANSI captures and the application version in the printed
temporary directory. A negative control restores the old unreadable foreground, so a binary that
ignores `selectedLineFgColor` cannot pass this lane. Lazygit 0.66.2 supports the setting. The gallery's
pinned 0.55.1 does not. These are native terminal-cell observations, not macOS renderer screenshots.
No shared theme or user repository is changed.

## Native theme qualification

Use an isolated trial to inspect Ghostty or Kitty rendering and Pi's live theme reload. Have Neovim,
Python 3.11+ and the application you want to check installed first. The harness installs nothing
and does not activate your normal shared themes.

```sh
./scripts/native-themes prepare
```

The command copies Flume into a new temporary directory, prepares private configuration and prints
the available applications and one launch command. It does not launch applications. Follow the
printed `cd` command, then launch an available app:

```sh
cd /absolute/path/to/flume-native-...
./control launch ghostty
# Or: ./control launch kitty
# Or: ./control launch pi
```

These commands work in Fish, Bash and Zsh without a shell-specific variable assignment. Preparation
only offers launch commands for applications on `PATH`.

The terminal launch opens a new app instance with an ANSI color fixture. Pi opens a fixed synthetic
transcript with no extensions, tools, context files or inherited provider credentials. It disables
automatic network activity. This is not an OS network sandbox: do not sign in or submit prompts.
The transcript's text is fixed, not a report of the current shared state.

In a second terminal, change to the same trial directory and switch palettes:

```sh
cd /absolute/path/to/flume-native-...
./control switch opal
./control show
```

- **Ghostty/Kitty:** while the trial window is focused, use the application's native configuration
  reload action. Inspect background, ANSI colors, cursor and mouse selection. Open a second trial
  tab to inspect active/inactive tab colors. Switch back to a dark palette and repeat. The fixture's
  changing palette label is not repaint evidence. In Kitty, also compare `tab_bar_style powerline`
  with `tab_powerline_style slanted` in the private `kitty.conf`, then reload that trial instance.
  Check active-tab recognition as well as inactive-label readability. Text contrast alone does not
  establish that adjacent tab backgrounds communicate the active state.
- **Pi:** keep the same process open and check that message/tool panels and text change without a
  restart. Leave the host terminal's theme unchanged, so its background cannot account for the result.
  If the running UI keeps its old colors, record that failure before reselecting the theme or
  restarting Pi. Then check that the fallback reads the new palette through the same installed link.
  A successful restart is not hot-reload evidence. Watcher behavior can differ by version and platform.

Switching publishes only into the copied trial and runs Pi's filesystem notification adapter.
Ghostty and Tmux reload commands are disabled. Do not use your normal `:FlumeSync` for this test:
its Ghostty adapter addresses running terminals globally. This trial does not qualify that adapter.

`native-theme-trial.json` records the prepared source hashes. Keep the workspace with application
versions, platform and before/after observations or captures when retaining evidence. `show` prints
expected colors, not a visual pass/fail result. Close trial apps before deleting the printed
workspace. There is no automatic cleanup of running apps or user configuration.

For a deterministic check of installed Pi's live output without opening a desktop window:

```sh
FLUME_NATIVE_PI=1 python3 -m unittest discover -s tests -p native_themes.py
```

This starts the private Pi fixture in a PTY and requires Dusk then Opal panel RGB output from the
same running trial. It sends no model prompt. It proves Pi's theme watcher emitted new colors,
not that a particular terminal painted them correctly. The ordinary gate runs only the fast
isolation/command checks and skips this installed-application lane.

## Snapshot and color evidence

[Showcase](showcase.md) owns the pinned capture environment, scene inventory, source/image sidecars,
exact comparisons and update rules. Linux Ghostty captures do not qualify macOS Ghostty or Kitty
rendering. Selection, tabs and live reload remain separate native observations.

[Integration review](integration-review.md) measures actual exported foreground/background pairs and
contrast targets. HTML color previews are not native screenshots or automatic aesthetic approval.
Review selected/matched text, inactive controls, diffs and light palettes in context.

Delta and Lazygit snapshot captures also run `tests/snapshots/check_delta.py` against native Delta
output before taking the image. The checker resolves emitted SGR foregrounds, backgrounds and
underlines independently of exporter style parsing. It checks normal and emphasized additions and
deletions, including colored strings and default-foreground identifiers. Run it separately with an
installed Delta:

```sh
python3 tests/snapshots/check_delta.py
```

`--app delta --schema dusk` selects one adapter/palette pair. The checker isolates Git configuration
and does not open a live application. Its fixture probes supplement the export-wide contrast tests,
not every possible syntax theme or terminal configuration.

The generated [palette manifest](palette-manifest.md) owns exact canonical roles and tested contrast
pairs. Preserve it as generated output rather than reformatting or hand-editing it.

## Hosted CI

[Quality](../.github/workflows/quality.yml) runs `./scripts/check` on Neovim 0.9.5 and stable.
Snapshots run once in a separate Linux job, not once per Neovim version. Before editor captures,
that lane runs the full native highlight checker and the installed-lualine check in the pinned
runtime. It retains `native.log` with the comparison
report for seven days. These checks do not observe external application reloads. A workflow
definition or local commit is not evidence that a hosted run passed.

Report the source or artifact, command, observed result and missing evidence. Configuration-contract
checks, parser captures, native rendering and actual reload observations establish different facts.
