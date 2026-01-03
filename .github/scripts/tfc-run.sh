#!/usr/bin/env bash
set -euo pipefail

DEBUG="${DEBUG:-0}"
dbg() {
  if [[ "${DEBUG:-0}" == "1" ]]; then
    echo "[debug] $*" >&2
  fi
}

AUTO_APPLY="false"
VARS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org) ORG="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --auto-apply) AUTO_APPLY="true"; shift 1 ;;
    --var) VARS+=("$2"); dbg "parsed --var: $2"; shift 2 ;;
    *) echo "[error] Unknown arg: $1" >&2; exit 1 ;;
  esac
done

dbg "AUTO_APPLY(raw)=$AUTO_APPLY"
dbg "VARS(raw) count=${#VARS[@]}"
for v in "${VARS[@]}"; do dbg "VARS(raw) item=$v"; done

PY_AUTO_APPLY="False"
[[ "$AUTO_APPLY" == "true" ]] && PY_AUTO_APPLY="True"

[[ -z "${ORG:-}" || -z "${WORKSPACE:-}" || -z "${TOKEN:-}" ]] && {
  echo "[error] Missing --org/--workspace/--token" >&2
  exit 1
}

API="https://app.terraform.io/api/v2"

########################################
# 1) workspace id
########################################
WS_JSON=$(curl -sS -w "\nHTTP_STATUS:%{http_code}\n" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  "${API}/organizations/${ORG}/workspaces/${WORKSPACE}")

WS_STATUS=$(echo "$WS_JSON" | sed -n 's/^HTTP_STATUS://p')
WS_BODY=$(echo "$WS_JSON" | sed '/^HTTP_STATUS:/d')

if [[ "$WS_STATUS" -ge 300 ]]; then
  echo "[error] Failed to fetch workspace" >&2
  echo "[error] HTTP $WS_STATUS" >&2
  echo "[error] Body:" >&2
  echo "$WS_BODY" >&2
  exit 1
fi

WS_ID=$(echo "$WS_BODY" | python3 -c '
import sys,json
try:
  print(json.load(sys.stdin)["data"]["id"])
except Exception as e:
  print("[error] JSON parse failed (workspace):", e, file=sys.stderr)
  sys.exit(1)
')

echo "Workspace id: $WS_ID"

########################################
# 2) create config version
########################################
CV_JSON=$(curl -sS -w "\nHTTP_STATUS:%{http_code}\n" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{"data":{"type":"configuration-versions","attributes":{"auto-queue-runs":false}}}' \
  "${API}/workspaces/${WS_ID}/configuration-versions")

CV_STATUS=$(echo "$CV_JSON" | sed -n 's/^HTTP_STATUS://p')
CV_BODY=$(echo "$CV_JSON" | sed '/^HTTP_STATUS:/d')

if [[ "$CV_STATUS" -ge 300 ]]; then
  echo "[error] Failed to create configuration version" >&2
  echo "[error] HTTP $CV_STATUS" >&2
  echo "[error] Body:" >&2
  echo "$CV_BODY" >&2
  exit 1
fi

UPLOAD_URL=$(echo "$CV_BODY" | python3 -c '
import sys,json
try:
  print(json.load(sys.stdin)["data"]["attributes"]["upload-url"])
except Exception as e:
  print("[error] JSON parse failed (upload-url):", e, file=sys.stderr)
  sys.exit(1)
')

CV_ID=$(echo "$CV_BODY" | python3 -c '
import sys,json
try:
  print(json.load(sys.stdin)["data"]["id"])
except Exception as e:
  print("[error] JSON parse failed (cv id):", e, file=sys.stderr)
  sys.exit(1)
')

echo "Config version id: $CV_ID"

########################################
# 3) tar.gz do repo inteiro
########################################
TMP_TGZ="$(mktemp /tmp/tfc-config.XXXXXX.tgz)"
tar -czf "$TMP_TGZ" .

PUT_STATUS=$(curl -sS -w "%{http_code}" -o /dev/null \
  -X PUT \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$TMP_TGZ" \
  "$UPLOAD_URL")

if [[ "$PUT_STATUS" -ge 300 ]]; then
  echo "[error] Failed to upload config archive" >&2
  echo "[error] HTTP $PUT_STATUS" >&2
  exit 1
fi

########################################
# 4) run payload (com vars)
########################################
RV="[]"
if [[ ${#VARS[@]} -gt 0 ]]; then
  RV=$(python3 - "${VARS[@]}" <<'PY'
import json,sys,re
vars=sys.argv[1:]
out=[]
for v in vars:
  k,val=v.split("=",1)
  val_strip=val.strip()
  is_hcl = val_strip.lower() in ("true","false","null") or re.fullmatch(r"-?\d+(\.\d+)?", val_strip)
  out.append({
    "type":"run-variables",
    "attributes":{
      "key":k,
      "value":val_strip,
      "category":"terraform",
      "hcl": bool(is_hcl),
      "sensitive": False
    }
  })
print(json.dumps(out))
PY
)
fi

RUN_PAYLOAD=$(python3 - <<PY
import json
payload={
  "data":{
    "type":"runs",
    "attributes":{"is-destroy":False,"auto-apply":${PY_AUTO_APPLY}},
    "relationships":{
      "workspace":{"data":{"type":"workspaces","id":"${WS_ID}"}},
      "configuration-version":{"data":{"type":"configuration-versions","id":"${CV_ID}"}}
    }
  }
}
print(json.dumps(payload))
PY
)

FINAL_RUN_PAYLOAD="$(python3 - <<PY
import json
run=json.loads('''$RUN_PAYLOAD''')
included=json.loads('''$RV''')
if included:
  run["included"]=included
print(json.dumps(run))
PY
)"

RUN_JSON=$(curl -sS -w "\nHTTP_STATUS:%{http_code}\n" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  -d "$FINAL_RUN_PAYLOAD" \
  "${API}/runs")

RUN_STATUS=$(echo "$RUN_JSON" | sed -n 's/^HTTP_STATUS://p')
RUN_BODY=$(echo "$RUN_JSON" | sed '/^HTTP_STATUS:/d')

if [[ "$RUN_STATUS" -ge 300 ]]; then
  echo "[error] Failed to create run" >&2
  echo "[error] HTTP $RUN_STATUS" >&2
  echo "[error] Body:" >&2
  echo "$RUN_BODY" >&2
  exit 1
fi

RUN_ID=$(echo "$RUN_BODY" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')
RUN_URL=$(echo "$RUN_BODY" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["links"]["self"])')

echo "Run: ${RUN_ID}"
echo "Run URL: https://app.terraform.io${RUN_URL}"

########################################
# 5) wait loop
########################################
while true; do
  R=$(curl -sS \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/vnd.api+json" \
    "${API}/runs/${RUN_ID}")

  STATUS=$(echo "$R" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["attributes"]["status"])')
  echo "Status: $STATUS"

  case "$STATUS" in
    applied|planned_and_finished) echo "OK: applied"; exit 0 ;;
    errored|canceled|discarded)
      echo "[error] Run failed: $STATUS" >&2
      echo "[error] Full run JSON:" >&2
      echo "$R" >&2
      exit 1
      ;;
  esac
  sleep 10
done