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

## Cache-shaped recipes

`txstats` already surfaces session cache-hit rate, invalidation events, top
cache-creation turns, and 20-block lookback-risk turns by default. Use these
recipes when you need to drill into the *content* behind one of those flags —
i.e. "what changed at turn 14 that broke the cache?"

### Per-turn usage stream (every assistant turn's cache numbers)

Each row: `idx | input | cache_creation | cache_read | output | n_tool_blocks`.
Useful for spotting patterns `txstats`'s top-N tables truncate.

```sh
jq -r 'select(.type=="assistant") | .message
  | (.usage.input_tokens // 0) as $i
  | (.usage.cache_creation_input_tokens // 0) as $cc
  | (.usage.cache_read_input_tokens // 0) as $cr
  | (.usage.output_tokens // 0) as $o
  | ([.content[]? | select(.type=="tool_use")] | length) as $tb
  | "\($i)\t\($cc)\t\($cr)\t\($o)\t\($tb)"' "$F" \
  | awk 'BEGIN{FS=OFS="\t"; print "idx\tinput\tcreate\tread\toutput\tblocks"} {print NR, $0}'
```

### What system-reminders are being injected (cache-buster suspect #1)

Dynamic content in `<system-reminder>` blocks (current date, session id, todo
list) re-rendered every turn near the front of the prompt invalidates the
system cache. Count and dedupe what's there:

```sh
jq -r 'select(.type=="user") | .message.content
  | if type=="array" then .[] else . end
  | (if type=="object" then (.text // "") else . end)
  | tostring
  | scan("<system-reminder>[\\s\\S]*?</system-reminder>")' "$F" \
  | sort | uniq -c | sort -rn | head -20
```

If the same reminder appears N times verbatim → fine, it caches. If similar-
looking reminders appear once each (different timestamps, different todo
contents, different ids) → that's the invalidator.

### Inspect a specific cache invalidation event (turn N's tool_use prompt)

When `txstats` flags an invalidation event at turn N, look at what the previous
assistant turn did and what content the user message *between* them carried —
that diff is what changed the prefix.

```sh
N=14
# Show the assistant content just before the invalidation
jq -c 'select(.type=="assistant") | {idx: input_line_number, content: .message.content}' "$F" \
  | sed -n "$((N-1))p,${N}p"
# Show the user/tool-result content between them (ids, reminders, todos)
jq -c 'select(.type=="user") | {idx: input_line_number, content: .message.content}' "$F" \
  | sed -n "$((N-1))p,${N}p"
```

### Tool-use blocks per assistant turn (lookback-risk drill)

`txstats` reports `next_cache_read` for each >20-block turn so you can confirm
silent miss. Use this when you want a full distribution.

```sh
jq -r 'select(.type=="assistant") | .message.content
  | [.[]? | select(.type=="tool_use")] | length' "$F" \
  | awk '{ if($1>m)m=$1; if($1>20)over++; n++; sum+=$1 } END {
      printf "turns=%d  mean=%.1f  max=%d  over_20=%d\n", n, sum/n, m, over+0 }'
```

### Sub-agent prefix audit (folder of jsonl files)

Sub-agent transcripts live alongside the parent in the same project folder.
Match invocations to their child sessions and check whether each child's
own session shares its prefix across calls (look for `cache_read > 0` on
turns 2+ of the same agent).

```sh
# All sub-agent invocations in the parent + their subagent_type
jq -r 'select(.type=="assistant") | .message.content[]?
  | select(.type=="tool_use" and (.name=="Task" or .name=="Agent"))
  | "\(.input.subagent_type // "?")"' "$F" | sort | uniq -c | sort -rn
```

If the same `subagent_type` is invoked many times AND the corresponding child
transcripts each show low `cache_read_input_tokens` on their own first few
turns, the sub-agent's system prompt isn't byte-stable → fix.

### Cost-impact ranking of cached vs. uncached work

```sh
jq -r 'select(.type=="assistant") | .message.usage
  | "\(.input_tokens // 0)\t\(.cache_creation_input_tokens // 0)\t\(.cache_read_input_tokens // 0)\t\(.output_tokens // 0)"' "$F" \
  | awk 'BEGIN{FS=OFS="\t"} {
      i+=$1; cc+=$2; cr+=$3; o+=$4
    } END {
      # base-input-equivalent cost: input + 1.25*cc + 0.1*cr (5m TTL)
      printf "input=%d  cache_creation=%d  cache_read=%d  output=%d\n", i, cc, cr, o
      printf "cost (input-equiv): uncached=%d  with_cache=%.0f  savings=%.0f (%.1f%%)\n",
        i + cc + cr,
        i + 1.25*cc + 0.1*cr,
        (i + cc + cr) - (i + 1.25*cc + 0.1*cr),
        100 * ((i + cc + cr) - (i + 1.25*cc + 0.1*cr)) / (i + cc + cr)
    }'
```

## Hard rules

- Never `Read` an entire `.jsonl` file. Either narrow with `jq` first, or use `Read` with `offset`/`limit` on a specific turn range.
- When the user gives a folder, run `txstats <folder>` once; don't loop `for f in *.jsonl` running the same pipeline.
- Cite turn numbers and `.message.usage` figures in findings. Estimates without numbers fail the proposal standard.
- If a question doesn't fit `txstats` *and* doesn't fit a recipe here, write the new pipeline once, then tell the user it should be added to this file.
