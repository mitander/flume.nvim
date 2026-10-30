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
    selection_bg = "#857891",
    selection_fg = "#100d15",
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
    selection_bg = "#756681",
    selection_fg = "#fff9ff",
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

    -- Purple types balance red fields on porcelain paper. Keep the trial's hue
    -- relationships, with deeper inks for contrast on raised and diff surfaces.
    -- State colors and ANSI slots remain independent of these text-sized accents.
    syntax_attribute = "#356475",
    syntax_boolean = "#8d513c",
    syntax_comment = "#646064",
    syntax_doc_comment = "#636064",
    syntax_constant = "#356475",
    syntax_function = "#356475",
    syntax_type = "#705883",
    syntax_keyword = "#70558a",
    syntax_namespace = "#9c4260",
    syntax_primary = "#514e57",
    syntax_property = "#9c4260",
    syntax_punctuation = "#615a68",
    syntax_punctuation_bracket = "#615b67",
    syntax_punctuation_special = "#8d513c",
    syntax_string = "#2d6a60",
    syntax_special = "#356475",
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
    warn_bg = "#f3e3a6",
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

-- Mira and Mesa retain related mineral accent families on distinct foundations.
M.mira = complete_palette({
    -- Near-neutral charcoal separates Mira from Dusk's violet atmosphere.
    -- Blue and sea-glass lead; berry and copper remain quieter counterpoints.
    bg = "#242429",
    fg = "#bdc0c8",
    text = "#d5d7dc",
    muted = "#a1a3ad",
    placeholder = "#727580",
    active_line = "#2b2c32",
    line_number = "#5c616d",
    active_line_number = "#d5d7dc",
    indent_guide = "#32343d",
    border = "#494c58",
    border_variant = "#363941",
    border_focused = "#8caabd",
    accent = "#8caabd",
    surface = "#292a30",
    surface_alt = "#303137",
    element_hover = "#292a30",
    element_active = "#303137",
    selection_bg = "#7d808f",
    selection_fg = "#101116",
    on_accent = "#242429",

    -- Semantic states
    error = "#cc91a5",
    warning = "#c5b18d",
    success = "#95b0a2",
    info = "#8caabd",

    -- Terminal / Base 16 Palette
    black = "#494c58",
    bright_black = "#5b5e6b",
    dim_black = "#33353d",
    red = "#c5859e",
    bright_red = "#d499af",
    dim_red = "#945d73",
    green = "#90aa9b",
    bright_green = "#a3baac",
    dim_green = "#637f70",
    yellow = "#bba17e",
    bright_yellow = "#cbb393",
    dim_yellow = "#8c7455",
    blue = "#819fb5",
    bright_blue = "#99b3c5",
    dim_blue = "#58758b",
    magenta = "#a99bbd",
    bright_magenta = "#bbafcb",
    dim_magenta = "#796c8f",
    cyan = "#85aeb2",
    bright_cyan = "#9abfc2",
    dim_cyan = "#5b8085",
    white = "#c5c7cd",
    bright_white = "#d5d7dc",
    dim_white = "#8c909c",

    -- Syntax Highlighting
    syntax_boolean = "#c49c89",
    syntax_comment = "#989ba5",
    syntax_doc_comment = "#989ba5",
    -- Sand keeps types distinct from copper literals without a bright gold accent.
    syntax_type = "#c5b18d",
    syntax_keyword = "#a99bbd",
    syntax_namespace = "#b495a7",
    syntax_primary = "#bdc0c8",
    syntax_property = "#b495a7",
    syntax_punctuation = "#9b9eaa",
    syntax_punctuation_bracket = "#989ba5",
    syntax_punctuation_special = "#c49c89",
    syntax_string = "#95b0a2",
    predictive = "#596474",

    -- Git Diff / Diagnostics
    diff_add_bg = "#29312e",
    diff_add_emphasis = "#465f54",
    diff_change_bg = "#303039",
    diff_text_bg = "#34313c",
    diff_delete_bg = "#352b31",
    diff_delete_emphasis = "#6c4856",
    hint_bg = "#29333d",
    warn_bg = "#373128",
})

M.mesa = complete_palette({
    -- Rose-gray paper removes the yellow cast without duplicating Opal's lilac.
    -- Keep the restrained mineral inks; cool the canvas and its related surfaces.
    bg = "#f0ebef",
    fg = "#58515d",
    text = "#423d47",
    muted = "#5f5964",
    placeholder = "#817988",
    active_line = "#e8e1e7",
    line_number = "#766f7d",
    active_line_number = "#423d47",
    indent_guide = "#d3cbd5",
    border = "#89818d",
    border_variant = "#c7bdc9",
    border_focused = "#2f6271",
    accent = "#2f6271",
    surface = "#e8e1e7",
    surface_alt = "#e2dae2",
    element_hover = "#e8e1e7",
    element_active = "#e2dae2",
    selection_bg = "#766878",
    selection_fg = "#fffaff",
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
    diff_change_bg = "#e6dfe4",
    diff_text_bg = "#dadce7",
    diff_delete_bg = "#ead9e2",
    diff_delete_emphasis = "#d9c0cc",
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
