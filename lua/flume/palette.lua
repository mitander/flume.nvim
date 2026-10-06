local M = {}

M.dusk = {
    -- Base UI
    bg = "#232136",
    terminal_bg = "#232136",
    fg = "#c9c5d9",
    text = "#d6d2e8",
    muted = "#a6a2bb",
    placeholder = "#67627d",
    active_line = "#2a273f",
    line_number = "#52596b",
    active_line_number = "#d6d2e8",
    indent_guide = "#303545",
    border = "#464c5e",
    border_variant = "#343949",
    border_focused = "#7dacbb",
    accent = "#7dacbb",
    surface = "#262938",
    surface_alt = "#302c43",
    element = "#232136",
    element_hover = "#262938",
    element_active = "#2f2c40",
    on_accent = "#232136",

    -- Semantic states
    error = "#f08692",
    warning = "#dfb86b",
    success = "#a4b78a",
    info = "#7dacbb",
    match = "#dfb86b",
    diff_add = "#a4b78a",
    diff_change = "#dfb86b",
    diff_delete = "#f08692",

    -- Terminal / Base 16 Palette
    black = "#343949",
    bright_black = "#464c5e",
    dim_black = "#262938",
    red = "#ee7583",
    bright_red = "#f48a94",
    dim_red = "#b65360",
    green = "#a4b78a",
    bright_green = "#b0ca9b",
    dim_green = "#71885f",
    yellow = "#dfb86b",
    bright_yellow = "#edc87e",
    dim_yellow = "#a58049",
    blue = "#6fa8dc",
    bright_blue = "#7eb6e8",
    dim_blue = "#4f789f",
    magenta = "#b99add",
    bright_magenta = "#c6a8e8",
    dim_magenta = "#846ca2",
    cyan = "#8fc9d2",
    bright_cyan = "#9bd6df",
    dim_cyan = "#659199",
    white = "#d6d2e8",
    bright_white = "#e0dcf0",
    dim_white = "#8a85a6",

    -- Syntax Highlighting
    syntax_attribute = "#73a6b6",
    syntax_boolean = "#ea9f8c",
    syntax_comment = "#9995a8",
    syntax_doc_comment = "#9297a9",
    syntax_constant = "#73a6b6",
    syntax_function = "#73a6b6",
    syntax_type = "#dfb86b",
    syntax_keyword = "#b391d6",
    syntax_namespace = "#ca838c",
    syntax_primary = "#c9c5d9",
    syntax_property = "#ce818d",
    syntax_punctuation = "#9899b5",
    syntax_punctuation_bracket = "#9396ae",
    syntax_punctuation_special = "#bd8b85",
    syntax_string = "#a4b78a",
    syntax_special = "#73a6b6",
    predictive = "#536178",

    -- Git Diff / Diagnostics
    diff_add_bg = "#293028",
    diff_add_emphasis = "#71885f",
    diff_change_bg = "#292e3d",
    diff_text_bg = "#302c43",
    diff_delete_bg = "#392831",
    diff_delete_emphasis = "#b65360",
    hint = "#8fc9d2",
    hint_bg = "#273343",
    warn_bg = "#3b3429",
}

M.opal = {
    -- Base UI
    bg = "#f2eff7",
    terminal_bg = "#f2eff7",
    fg = "#554e5d",
    text = "#413b49",
    muted = "#615a68",
    placeholder = "#817987",
    active_line = "#ebe6f0",
    line_number = "#766f7d",
    active_line_number = "#413b49",
    indent_guide = "#d3ccd5",
    border = "#8b8491",
    border_variant = "#c8c0ca",
    border_focused = "#00667e",
    accent = "#00667e",
    surface = "#ebe6f0",
    surface_alt = "#e4dee9",
    element = "#f2eff7",
    element_hover = "#ebe6f0",
    element_active = "#e4dee9",
    on_accent = "#fbf8fa",

    -- Semantic states
    error = "#9d395e",
    warning = "#7e5500",
    success = "#246b23",
    info = "#00667e",
    match = "#7e5500",
    diff_add = "#246b23",
    diff_change = "#7e5500",
    diff_delete = "#9d395e",

    -- Terminal / Base 16 Palette
    black = "#413b49",
    bright_black = "#706878",
    dim_black = "#817987",
    red = "#a43b62",
    bright_red = "#b5365b",
    dim_red = "#7e304b",
    green = "#256f24",
    bright_green = "#397515",
    dim_green = "#1c5a18",
    yellow = "#895c00",
    bright_yellow = "#965900",
    dim_yellow = "#6e4700",
    blue = "#006b9d",
    bright_blue = "#0071a3",
    dim_blue = "#00567f",
    magenta = "#7540a3",
    bright_magenta = "#873a9d",
    dim_magenta = "#5c3283",
    cyan = "#006b85",
    bright_cyan = "#00728c",
    dim_cyan = "#00566c",
    -- ANSI white must remain visible on a light terminal background. Programs
    -- commonly use slots 7/15 as foregrounds rather than literal paper white.
    white = "#554e5d",
    bright_white = "#413b49",
    dim_white = "#706878",

    -- Syntax Highlighting
    syntax_attribute = "#00667e",
    syntax_boolean = "#9e3f2f",
    syntax_comment = "#646064",
    syntax_doc_comment = "#636064",
    syntax_constant = "#00667e",
    syntax_function = "#00667e",
    syntax_type = "#7e5500",
    syntax_keyword = "#7540a3",
    syntax_namespace = "#9d395e",
    syntax_primary = "#514e57",
    syntax_property = "#9d395e",
    syntax_punctuation = "#615a68",
    syntax_punctuation_bracket = "#615b67",
    syntax_punctuation_special = "#9e3f2f",
    syntax_string = "#246b23",
    syntax_special = "#00667e",
    predictive = "#817987",

    -- Git Diff / Diagnostics
    diff_add_bg = "#e0e8dc",
    diff_add_emphasis = "#cadbc3",
    diff_change_bg = "#e8e0cf",
    diff_text_bg = "#dbdfe9",
    diff_delete_bg = "#eadadd",
    diff_delete_emphasis = "#dfc4ca",
    hint = "#00667e",
    hint_bg = "#dce7e9",
    warn_bg = "#e8e0cf",
}

local function complete_palette(colors)
    colors.terminal_bg = colors.bg
    colors.element = colors.bg
    colors.match = colors.warning
    colors.diff_add = colors.success
    colors.diff_change = colors.warning
    colors.diff_delete = colors.error
    colors.syntax_attribute = colors.accent
    colors.syntax_constant = colors.accent
    colors.syntax_function = colors.accent
    colors.syntax_special = colors.accent
    colors.hint = colors.info
    return colors
end

-- Mira and Mesa borrow Kapsel's accent relationships, not its public identity or
-- large-field website canvases. Neutral foundations preserve Flume's hierarchy.
M.mira = complete_palette({
    -- Base UI: violet-charcoal rather than the website's green-slate canvas.
    bg = "#24212f",
    fg = "#cbc5d2",
    text = "#d9d4df",
    muted = "#a6a0ad",
    placeholder = "#746d7c",
    active_line = "#2b2838",
    line_number = "#5b6070",
    active_line_number = "#d9d4df",
    indent_guide = "#323043",
    border = "#4b485a",
    border_variant = "#383547",
    border_focused = "#72b5bf",
    accent = "#72b5bf",
    surface = "#292634",
    surface_alt = "#302b3c",
    element_hover = "#292634",
    element_active = "#312d3e",
    on_accent = "#24212f",

    -- Semantic states: softened source-logo accents.
    error = "#e187a6",
    warning = "#d8a36b",
    success = "#84b39f",
    info = "#73a9c8",

    -- Terminal / Base 16 Palette
    black = "#4b485a",
    bright_black = "#5f596b",
    dim_black = "#353142",
    red = "#dd789b",
    bright_red = "#e88eaa",
    dim_red = "#a95873",
    green = "#84b39f",
    bright_green = "#98c5b2",
    dim_green = "#5e8578",
    yellow = "#d8a36b",
    bright_yellow = "#e5b77f",
    dim_yellow = "#9f754c",
    blue = "#72a8c7",
    bright_blue = "#88b9d3",
    dim_blue = "#527b99",
    magenta = "#b69bd2",
    bright_magenta = "#c7afe0",
    dim_magenta = "#806c99",
    cyan = "#72b5bf",
    bright_cyan = "#8ac8cf",
    dim_cyan = "#50858e",
    white = "#cbc5d2",
    bright_white = "#d9d4df",
    dim_white = "#918a9a",

    -- Syntax Highlighting
    syntax_boolean = "#e49a7b",
    syntax_comment = "#9b94a4",
    syntax_doc_comment = "#9b94a3",
    syntax_type = "#d8a36b",
    syntax_keyword = "#b69bd2",
    syntax_namespace = "#dd789b",
    syntax_primary = "#cbc5d2",
    syntax_property = "#d18099",
    syntax_punctuation = "#9d96aa",
    syntax_punctuation_bracket = "#9b94a4",
    syntax_punctuation_special = "#e49a7b",
    syntax_string = "#84b39f",
    predictive = "#596073",

    -- Git Diff / Diagnostics
    diff_add_bg = "#2b302d",
    diff_add_emphasis = "#47665d",
    diff_change_bg = "#342c28",
    diff_text_bg = "#312b3e",
    diff_delete_bg = "#362830",
    diff_delete_emphasis = "#754355",
    hint_bg = "#293441",
    warn_bg = "#3a302b",
})

M.mesa = complete_palette({
    -- Base UI: warm rose-mineral paper without the website canvas's olive cast.
    bg = "#f3ede8",
    fg = "#58515d",
    text = "#423d47",
    muted = "#5f5964",
    placeholder = "#817988",
    active_line = "#ebe3de",
    line_number = "#766f7d",
    active_line_number = "#423d47",
    indent_guide = "#d5ccc8",
    border = "#8c837f",
    border_variant = "#c9bfbb",
    border_focused = "#2f6271",
    accent = "#2f6271",
    surface = "#ebe3de",
    surface_alt = "#e5dcd9",
    element_hover = "#ebe3de",
    element_active = "#e5dcd9",
    on_accent = "#fbf8fa",

    -- Semantic states: darker mixtures retain identity and text contrast.
    error = "#89455f",
    warning = "#7d521e",
    success = "#43615a",
    info = "#306077",

    -- Terminal / Base 16 Palette
    black = "#423d47",
    bright_black = "#58515d",
    dim_black = "#706976",
    red = "#974c68",
    bright_red = "#a33d66",
    dim_red = "#7d3f56",
    green = "#4b6d65",
    bright_green = "#3f685f",
    dim_green = "#3d5b55",
    yellow = "#80541f",
    bright_yellow = "#8c4e19",
    dim_yellow = "#684519",
    blue = "#356a83",
    bright_blue = "#286782",
    dim_blue = "#2b576c",
    magenta = "#6c538b",
    bright_magenta = "#764b94",
    dim_magenta = "#594573",
    cyan = "#356f80",
    bright_cyan = "#286c7e",
    dim_cyan = "#2b5b69",
    white = "#58515d",
    bright_white = "#423d47",
    dim_white = "#706976",

    -- Syntax Highlighting
    syntax_boolean = "#8b4940",
    syntax_comment = "#636063",
    syntax_doc_comment = "#626064",
    syntax_type = "#7d521e",
    syntax_keyword = "#695187",
    syntax_namespace = "#89455f",
    syntax_primary = "#524f50",
    syntax_property = "#89455f",
    syntax_punctuation = "#5f5965",
    syntax_punctuation_bracket = "#5f5964",
    syntax_punctuation_special = "#8b4940",
    syntax_string = "#43615a",
    predictive = "#817988",

    -- Git Diff / Diagnostics
    diff_add_bg = "#dce5e0",
    diff_add_emphasis = "#c4d5ce",
    diff_change_bg = "#e9ded1",
    diff_text_bg = "#dfddd4",
    diff_delete_bg = "#ead9de",
    diff_delete_emphasis = "#d9c0c8",
    hint_bg = "#d9e4e7",
    warn_bg = "#e9ded1",
})

M.schema_order = { "dusk", "opal", "mira", "mesa" }
M.schemas = {
    dusk = {
        appearance = "dark",
        colors = M.dusk,
        colorscheme = "flume-dusk",
        display_name = "Dusk",
        integration_name = "flume-dusk",
        suffix = "-dusk",
    },
    opal = {
        appearance = "light",
        colors = M.opal,
        colorscheme = "flume-opal",
        display_name = "Opal",
        integration_name = "flume-opal",
        suffix = "-opal",
    },
    mira = {
        appearance = "dark",
        colors = M.mira,
        colorscheme = "flume-mira",
        display_name = "Mira",
        integration_name = "flume-mira",
        suffix = "-mira",
    },
    mesa = {
        appearance = "light",
        colors = M.mesa,
        colorscheme = "flume-mesa",
        display_name = "Mesa",
        integration_name = "flume-mesa",
        suffix = "-mesa",
    },
}

function M.resolve(schema)
    schema = schema or "dusk"
    assert(M.schemas[schema], "Unknown Flume schema: " .. tostring(schema))
    return schema
end

function M.get(schema)
    return M.schemas[M.resolve(schema)]
end

return M
