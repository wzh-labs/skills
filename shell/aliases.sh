#!/usr/bin/env bash

alias ga="git add"
alias gas="gh auth switch"
alias gb="git branch"
alias gbd="git branch -D"
alias gbdr="git push origin --delete"
alias gc="git commit"
alias gcm="git commit -m"
alias gco="git checkout"
alias gd="git diff"
alias gdhm="gd head main"
alias gds="git diff --staged"
alias gf="git fetch"
alias gl="git log"
alias glo="git log --oneline"
alias gp="git pull"
alias gpom="gp origin main"
alias gpu="git push"
alias gpu2="gas && gpu && gas"
alias gr="git restore"
alias gs="git status"
alias gst="git stash"
alias gsw="git switch"
alias m="gco main && gp"

gsm() {
  if [ -z "$1" ]; then
    echo "Usage: gsm <branch-name>"
    return 1
  fi
  local branch="$1"
  git checkout main && git pull || return 1
  git checkout "$branch" && git pull origin main --no-edit || return 1
  git diff HEAD main
  if [ -z "$(git diff HEAD main)" ]; then
    git checkout main
    git branch -D "$branch"
  fi
}

athena() {
  local sql="$1"
  if [ -z "$sql" ]; then
    echo "usage: athena \"SELECT ...\"  (or pipe SQL via stdin: athena < query.sql)" >&2
    return 2
  fi
  # Support stdin SQL too: `athena - < file.sql` or `echo ... | athena -`
  if [ "$sql" = "-" ]; then sql=$(cat); fi

  local profile="${ATHENA_PROFILE:-Vercel-Engineering-Athena-977805900156}"
  local region="${ATHENA_REGION:-us-west-2}"
  local results="${ATHENA_RESULTS:-s3://next-telemetry-results-us-west-2/}"
  local database="${ATHENA_DATABASE:-next_telemetry}"

  # Show first ~140 chars of the SQL as it will be sent — surfaces quoting bugs
  local oneline
  oneline=$(printf '%s' "$sql" | tr '\n' ' ' | tr -s ' ' | sed 's/^ //; s/ $//')
  echo "→ SQL: ${oneline:0:140}$([ ${#oneline} -gt 140 ] && echo ' …')" >&2

  local qid
  qid=$(aws athena start-query-execution \
    --query-string "$sql" \
    --query-execution-context "Database=$database" \
    --result-configuration "OutputLocation=$results" \
    --region "$region" --profile "$profile" \
    --query QueryExecutionId --output text) || return 1
  echo "→ QID: $qid" >&2

  local state
  while :; do
    state=$(aws athena get-query-execution --query-execution-id "$qid" \
      --region "$region" --profile "$profile" \
      --query 'QueryExecution.Status.State' --output text 2>/dev/null)
    case "$state" in
      SUCCEEDED) break ;;
      FAILED|CANCELLED)
        echo "→ Query $state:" >&2
        aws athena get-query-execution --query-execution-id "$qid" \
          --region "$region" --profile "$profile" \
          --query 'QueryExecution.Status.StateChangeReason' --output text >&2
        return 1 ;;
    esac
    sleep 1
  done

  # Stats line: runtime + bytes scanned
  local stats exec_ms scanned
  stats=$(aws athena get-query-execution --query-execution-id "$qid" \
    --region "$region" --profile "$profile" \
    --query 'QueryExecution.Statistics.[EngineExecutionTimeInMillis,DataScannedInBytes]' \
    --output text)
  exec_ms=${stats%%[[:space:]]*}
  scanned=${stats##*[[:space:]]}
  echo "→ Done in ${exec_ms}ms, ${scanned} bytes scanned" >&2

  # Fetch results as TSV: header row first (column names from ColumnInfo),
  # then data rows. Render as a bordered table via awk.
  {
    aws athena get-query-results --query-execution-id "$qid" \
      --region "$region" --profile "$profile" \
      --query 'ResultSet.ResultSetMetadata.ColumnInfo[*].Name' --output text
    aws athena get-query-results --query-execution-id "$qid" \
      --region "$region" --profile "$profile" \
      --query 'ResultSet.Rows[1:].Data[*].VarCharValue' --output text
  } | awk -F'\t' '
    {
      n = NF
      if (n > maxcols) maxcols = n
      for (i = 1; i <= n; i++) {
        cell[NR, i] = $i
        if (length($i) > w[i]) w[i] = length($i)
      }
      nrows = NR
    }
    END {
      if (nrows == 0) { print "(no results)"; exit }
      sep = "+"
      for (i = 1; i <= maxcols; i++) {
        pad = ""
        for (j = 0; j < w[i] + 2; j++) pad = pad "-"
        sep = sep pad "+"
      }
      print sep
      for (r = 1; r <= nrows; r++) {
        line = "|"
        for (i = 1; i <= maxcols; i++) {
          line = line sprintf(" %-*s |", w[i], cell[r, i])
        }
        print line
        if (r == 1) print sep
      }
      print sep
    }
  '
}
