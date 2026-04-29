### Set the file once, never `cd` per call

```sh
F="/abs/path/to/file.jsonl"
jq '...' "$F"
```

Don't write `cd "<long path>" && jq …` on every call — that's pure prefix bytes the model has to author each time.

### Inspect a specific turn range without reading the whole file

```sh
# Show the 50th–60th assistant turns as compact JSON
jq -c 'select(.type=="assistant")' "$F" | sed -n '50,60p'
```

### Find Read pairs that re-read the same file within N assistant turns

`txstats` only counts total redundancy. Use this when proximity matters.

```sh
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Read") | .input.file_path' "$F" \
  | awk -v N=20 '
      { if (last[$0] > 0 && (NR - last[$0]) <= N) close++; last[$0]=NR }
      END { print "close-window repeated reads (≤"N" calls apart):", close+0 }
    '
```

### Find Edit→Edit chains with no test in between

```sh
jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$F" \
  | awk 'BEGIN{p=""} {if(p=="Edit"&&$0=="Edit")c++; p=$0} END{print "Edit→Edit chains:",c+0}'
```

### Sample one full bash command (when txstats truncated to 120 chars)

```sh
jq -r --arg q "<substring>" '
  select(.type=="assistant") | .message.content[]?
  | select(.type=="tool_use" and .name=="Bash" and (.input.command | contains($q)))
  | .input.command' "$F" | head -1
```

### Match a tool_use id back to its result text

```sh
ID="toolu_01XXXXXX"
jq -r --arg id "$ID" '
  select(.type=="user") | .message.content[]?
  | select(.type=="tool_result" and .tool_use_id==$id)
  | (.content | if type=="array" then map(.text // "") | join("") else . end)
' "$F"
```

### Sub-agent invocation prompts (debug heavy delegation)

```sh
jq -r 'select(.type=="assistant") | .message.content[]?
  | select(.type=="tool_use" and (.name=="Task" or .name=="Agent"))
  | "\(.input.subagent_type // "?") :: \((.input.description // "") | .[0:120])"' "$F"
```

## Hard rules

- Never `Read` an entire `.jsonl` file. Either narrow with `jq` first, or use `Read` with `offset`/`limit` on a specific turn range.
- When the user gives a folder, run `txstats <folder>` once; don't loop `for f in *.jsonl` running the same pipeline.
- Cite turn numbers and `.message.usage` figures in findings. Estimates without numbers fail the proposal standard.
- If a question doesn't fit `txstats` *and* doesn't fit a recipe here, write the new pipeline once, then tell the user it should be added to this file.
