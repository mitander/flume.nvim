; extends

; Upstream exception/debug captures otherwise win over function.macro. Keep
; this capture Flume-specific so other colorschemes retain their own mappings.
(macro_invocation
  macro: [
    (identifier) @flume.macro
    (scoped_identifier
      name: (identifier) @flume.macro)
  ]
  "!" @flume.macro
  (#set! priority 101))
