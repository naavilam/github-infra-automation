#!/usr/bin/env bash
set -euo pipefail

DEBUG="${DEBUG:-0}"
dbg() { [[ "${DEBUG:-0}" == "1" ]] && echo "[debug] $*" >&2 || true; }
die() { echo "[error] $*" >&2; exit 1; }

AUTO_APPLY="false"
VARS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org) ORG="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --auto-apply) AUTO_APPLY="true"; shift 1 ;;
    --var) VARS+=("$2"); dbg "parsed --var: $2"; shift 2 ;;
    *) die "Unknown arg: $1" ;;
  esac
done

[[ -z "${ORG:-}" || -z "${WORKSPACE:-}" || -z "${TOKEN:-}" ]] && die "Missing --org/--workspace/--token"

API="https://app.terraform.io/api/v2"

dbg "AUTO_APPLY=$AUTO_APPLY"
dbg "VARS count=${#VARS[@]}"

# ---------- robust HTTP helpers ----------

# Prints body to stdout on success (2xx). On error: prints diagnostics to stderr and exits 1.
api_call() {
  local method="$1"; shift
  local url="$1"; shift
  local data="${1:-}" # optional JSON body

  dbg "api_call method=$method url=$url"
  local resp status body

  if [[ -n "$data" ]]; then
    resp="$(curl -sS -w "\nHTTP_STATUS=%{http_code}\n" \
      -X "$method" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/vnd.api+json" \
      --data "$data" \
      "$url")"
  else
    resp="$(curl -sS -w "\nHTTP_STATUS=%{http_code}\n" \
      -X "$method" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Content-Type: application/vnd.api+json" \
      "$url")"
  fi

  status="$(printf '%s' "$resp" | sed -n 's/^HTTP_STATUS=//p' | tail -n1)"
  body="$(printf '%s' "$resp" | sed '/^HTTP_STATUS=/d')"

  # Some APIs may return 204 with empty body (OK).
  if [[ "$status" -ge 200 && "$status" -lt 300 ]]; then
    printf '%s' "$body"
    return 0
  fi

  echo "[tfc] HTTP error" >&2
  echo "[tfc] $method $url" >&2
  echo "[tfc] status=$status" >&2
  echo "[tfc] body:" >&2
  echo "$body" >&2
  return 1
}

# PUT binary to signed upload URL. Fails with diagnostics if non-2xx.
put_binary() {
  local url="$1"
  local file="$2"

  dbg "put_binary url=$url file=$file"
  local resp status body

  resp="$(curl -sS -w "\nHTTP_STATUS=%{http_code}\n" \
    -X PUT \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"$file" \
    "$url")"

  status="$(printf '%s' "$resp" | sed -n 's/^HTTP_STATUS=//p' | tail -n1)"
  body="$(printf '%s' "$resp" | sed '/^HTTP_STATUS=/d')"

  if [[ "$status" -ge 200 && "$status" -lt 300 ]]; then
    # usually empty
    return 0
  fi

  echo "[tfc] Upload error" >&2
  echo "[tfc] PUT $url" >&2
  echo "[tfc] status=$status" >&2
  echo "[tfc] body:" >&2
  echo "$body" >&2
  return 1
}

# JSON extractor with good error messages (prints whole JSON if key path missing)
json_get() {
  local json="$1"
  local expr="$2"
  python3 - "$expr" <<'PY' <<<"$json" || exit 1
import json,sys
expr=sys.argv[1]

raw=sys.stdin.read()
try:
  j=json.loads(raw) if raw.strip() else None
except Exception as e:
  print("[tfc] ERROR: response is not valid JSON:", e, file=sys.stderr)
  print("[tfc] RAW BODY:", file=sys.stderr)
  print(raw, file=sys.stderr)
  sys.exit(2)

if j is None:
  print("[tfc] ERROR: empty JSON body", file=sys.stderr)
  sys.exit(2)

# evaluate a safe path expression like: data.id or data.attributes.upload-url etc.
# We accept dot-separated keys; for keys with hyphen, keep as-is (we treat as dict keys).
path = expr.split(".")
cur = j
try:
  for p in path:
    if isinstance(cur, dict):
      cur = cur[p]
    else:
      raise KeyError(p)
except Exception as e:
  print(f"[tfc] ERROR: missing key path '{expr}': {e}", file=sys.stderr)
  print("[tfc] FULL JSON:", file=sys.stderr)
  print(json.dumps(j, indent=2), file=sys.stderr)
  sys.exit(3)

if isinstance(cur, (dict,list)):
  print(json.dumps(cur))
else:
  print(cur)
PY
}

# ---------- 1) workspace id ----------
WS_JSON="$(api_call GET "${API}/organizations/${ORG}/workspaces/${WORKSPACE}")"
WS_ID="$(json_get "$WS_JSON" "data.id")"
echo "Workspace id: $WS_ID"

# ---------- 2) create config version ----------
CV_JSON="$(api_call POST "${API}/workspaces/${WS_ID}/configuration-versions" \
  '{"data":{"type":"configuration-versions","attributes":{"auto-queue-runs":false}}}')"

UPLOAD_URL="$(json_get "$CV_JSON" "data.attributes.upload-url")"
CV_ID="$(json_get "$CV_JSON" "data.id")"
echo "Config version id: $CV_ID"

# ---------- 3) tar.gz do repo inteiro ----------
TMP_TGZ="$(mktemp /tmp/tfc-config.XXXXXX.tgz)"
tar -czf "$TMP_TGZ" .

put_binary "$UPLOAD_URL" "$TMP_TGZ"

# ---------- 4) run payload (com vars) ----------
RV="[]"
if [[ ${#VARS[@]} -gt 0 ]]; then
  RV="$(python3 - "${VARS[@]}" <<'PY'
import json,sys,re
vars=sys.argv[1:]
out=[]
for v in vars:
  k,val=v.split("=",1)
  val_strip=val.strip()
  is_hcl = val_strip.lower() in ("true","false","null") or re.fullmatch(r"-?\d+(\.\d+)?", val_strip) is not None
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
)"
fi

PY_AUTO_APPLY="False"
[[ "$AUTO_APPLY" == "true" ]] && PY_AUTO_APPLY="True"

RUN_PAYLOAD="$(python3 - <<PY
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
)"

FINAL_RUN_PAYLOAD="$(python3 - <<PY
import json
run=json.loads('''$RUN_PAYLOAD''')
included=json.loads('''$RV''')
if included:
  run["included"]=included
print(json.dumps(run))
PY
)"

dbg "FINAL_RUN_PAYLOAD=$FINAL_RUN_PAYLOAD"

RUN_JSON="$(api_call POST "${API}/runs" "$FINAL_RUN_PAYLOAD")"
RUN_ID="$(json_get "$RUN_JSON" "data.id")"
RUN_URL="$(json_get "$RUN_JSON" "data.links.self")"

echo "Run: ${RUN_ID}"
echo "Run URL: https://app.terraform.io${RUN_URL}"

# ---------- 5) wait loop ----------
while true; do
  R="$(api_call GET "${API}/runs/${RUN_ID}")"
  STATUS="$(json_get "$R" "data.attributes.status")"
  echo "Status: $STATUS"
  case "$STATUS" in
    applied|planned_and_finished) echo "OK: applied"; exit 0 ;;
    errored|canceled|discarded) echo "FAILED: $STATUS"; exit 1 ;;
  esac
  sleep 10
done