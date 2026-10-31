# Style

Make semantic color decisions and their effects easy to follow. Use the same palette roles in
highlights, exporters, tests and explanations. [Design](docs/DESIGN.md) assigns responsibilities,
and the [color system](docs/color-system.md) defines role meanings and mapping rules.

## Names and control flow

Use domain names such as palette, schema, role, integration and active set consistently. Preserve
Neovim highlight names, external configuration keys and serialized fields. Do not replace a semantic
role with a literal color merely to repair one consumer.

Keep validation, color resolution, output construction and publication visibly grouped. Helpers
should hide a rule or mechanism, not just add a forwarding hop. Keep failure and recovery ordering
visible, especially when paths or shared state change.

## Lua

Use Lua 5.1 syntax compatible with Neovim 0.9+. Keep ordinary local names in snake_case and preserve
host APIs at their boundaries. Prefer tables, functions and existing module owners over a generic
integration framework. Preserve meaningful require order.

Comments explain role choices, ownership, ordering or compatibility that names and control flow
cannot show. Caller documentation should explain consequential options, effects and failure behavior
rather than repeat the signature.

## Formatting and lints

Use StyLua 2.5.2 and `stylua.toml`: Lua 5.1 syntax, four spaces, Unix endings and a 120-column
wrapping guide. Prefer double quotes, retain call parentheses and leave require order unchanged.

`.styluaignore` excludes highlighting examples, exact snapshot fixtures and generated extras. Do not
format them as ordinary Lua. Editor integrations should pass `--respect-ignores` so explicit file
paths retain the exclusions. Formatting verification does not replace runtime tests. The gate also
rejects trailing whitespace.

The portable shell gate uses POSIX `sh` and two-space indentation. ANSI examples and snapshot
scripts are exact rendering fixtures. Optional shell checks must not rewrite their output. Generated
palette tables and extras retain their generators' byte layout.

## Tests and review

Choose expected roles and values independently of the implementation being checked. Keep actual
parser output, language-server tokens, exported pairs and native renderer observations distinct. Do
not recolor pixels or manually assign syntax colors to approximate a parser. A new screenshot
baseline is a candidate to review, not its own expected answer.

Use isolated homes, application state and fixtures. Preserve existing working user configuration.
[Testing](docs/TESTING.md) selects the required observations and records their limits.

## Documentation responsibilities

README owns orientation and quick start. CONTRIBUTING is the change entry point. AGENTS keeps
repository-specific agent constraints. DEVELOPMENT owns setup and commands. TESTING owns check
selection and evidence. DESIGN owns architecture and points to the color-system and semantic-export
contracts. This guide owns code expression. The help file owns the complete user command/options
reference. Gallery, language and palette pages own visual navigation. Showcase owns capture
procedures. CHANGELOG records released and unreleased changes, not current implementation details.

Use sentence-case ATX headings, language-tagged fences and a 100-column prose target. Keep exact
code, format examples and generated tables intact. Update one owner per fact and repair links
together. Do not add private workflow, tracker routes or personal paths to public documentation.
