#!/usr/bin/env bash
set -euo pipefail

AUTO_APPLY="false"

VARS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org) ORG="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --auto-apply) AUTO_APPLY="true"; shift 1 ;;
    --var) VARS+=("$2"); shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

[[ -z "${ORG:-}" || -z "${WORKSPACE:-}" || -z "${TOKEN:-}" ]] && {
  echo "Missing --org/--workspace/--token"; exit 1;
}

API="https://app.terraform.io/api/v2"

# 1) workspace id
WS_JSON=$(curl -sS \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  "${API}/organizations/${ORG}/workspaces/${WORKSPACE}")

WS_ID=$(echo "$WS_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')

echo "Workspace id: $WS_ID"

# 2) create config version
CV_JSON=$(curl -sS \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{"data":{"type":"configuration-versions","attributes":{"auto-queue-runs":false}}}' \
  "${API}/workspaces/${WS_ID}/configuration-versions")

UPLOAD_URL=$(echo "$CV_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["attributes"]["upload-url"])')
CV_ID=$(echo "$CV_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')

echo "Config version id: $CV_ID"

# 3) tar.gz do repo inteiro (TFC usa working directory do workspace)
TMP_TGZ="$(mktemp /tmp/tfc-config.XXXXXX.tgz)"
tar -czf "$TMP_TGZ" .

curl -sS -X PUT \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"$TMP_TGZ" \
  "$UPLOAD_URL" >/dev/null

# 4) run payload (com vars)
PYVARS='import json,sys; vars=sys.argv[1:]; out=[]; 
for v in vars:
  k,val=v.split("=",1)
  out.append({"type":"run-variables","attributes":{"key":k,"value":val,"category":"terraform","hcl":False,"sensitive":False}})
print(json.dumps(out))'
RUN_VARS_JSON=$(python3 -c "$PYVARS" "${VARS[@]/#/}" 2>/dev/null || true)

# Converte ["a=b","c=d"] -> objects
RV="[]"
if [[ ${#VARS[@]} -gt 0 ]]; then
  RV=$(python3 - "${VARS[@]}" <<'PY'
import json,sys
vars=sys.argv[1:]
out=[]
for v in vars:
  k,val=v.split("=",1)
  out.append({
    "type":"run-variables",
    "attributes":{
      "key":k,"value":val,
      "category":"terraform",
      "hcl":False,
      "sensitive":False
    }
  })
print(json.dumps(out))
PY
)
fi

# --- converte boolean bash -> boolean python ---
PY_AUTO_APPLY="False"
[[ "$AUTO_APPLY" == "true" ]] && PY_AUTO_APPLY="True"

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

# injeta run-variables como relationships (TFC aceita via "included")
RUN_JSON=$(curl -sS \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  -d "$(python3 - <<PY
import json
run=json.loads('''$RUN_PAYLOAD''')
included=json.loads('''$RV''')
if included:
  run["included"]=included
print(json.dumps(run))
PY
)" \
  "${API}/runs")

RUN_ID=$(echo "$RUN_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["id"])')
RUN_URL=$(echo "$RUN_JSON" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["links"]["self"])')

echo "Run: ${RUN_ID}"
echo "Run URL: https://app.terraform.io${RUN_URL}"

# 5) wait loop
while true; do
  R=$(curl -sS \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/vnd.api+json" \
    "${API}/runs/${RUN_ID}")
  STATUS=$(echo "$R" | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["attributes"]["status"])')
  echo "Status: $STATUS"
  case "$STATUS" in
    applied) echo "OK: applied"; exit 0 ;;
    errored|canceled|discarded) echo "FAILED: $STATUS"; exit 1 ;;
  esac
  sleep 10
done