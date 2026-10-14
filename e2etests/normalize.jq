def severity_rank:
  if . == "error" then 0 else
    if . == "warning" then 1 else
      if . == "info" then 2 else
        if . == "style" then 3 else 4 end
      end
    end
  end;

map({
  line,
  endLine,
  column,
  endColumn,
  level,
  code,
  message,
  fix: (if .fix == null then null else {
    replacements: (.fix.replacements
      | map({line, endLine, column, endColumn, insertionPoint, precedence, replacement})
      | sort_by([.line, .endLine, .column, .endColumn, .precedence, .insertionPoint, .replacement]))
  } end)
})
| sort_by([.line, .endLine, .column, .endColumn, (.level | severity_rank), (.code == null), .code, .message])
