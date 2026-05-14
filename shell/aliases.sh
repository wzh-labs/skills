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
  local profile="${ATHENA_PROFILE:-Vercel-Engineering-Athena-977805900156}"
  local region="${ATHENA_REGION:-us-west-2}"
  local results="${ATHENA_RESULTS:-s3://next-telemetry-results-us-west-2/}"

  local qid
  qid=$(aws athena start-query-execution \
    --query-string "$sql" \
    --result-configuration "OutputLocation=$results" \
    --region "$region" --profile "$profile" \
    --query QueryExecutionId --output text) || return 1

  while true; do
    local state
    state=$(aws athena get-query-execution --query-execution-id "$qid" \
      --region "$region" --profile "$profile" \
      --query 'QueryExecution.Status.State' --output text)
    case "$state" in
      SUCCEEDED) break ;;
      FAILED|CANCELLED)
        aws athena get-query-execution --query-execution-id "$qid" \
          --region "$region" --profile "$profile" \
          --query 'QueryExecution.Status.StateChangeReason' --output text
        return 1 ;;
    esac
    sleep 2
  done

  aws athena get-query-results --query-execution-id "$qid" \
    --region "$region" --profile "$profile" \
    --query 'ResultSet.Rows[*].Data[*].VarCharValue' --output table
}
