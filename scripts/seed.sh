#!/usr/bin/env bash
# Seeds a local OpenTDF platform with enough policy data to page through.
set -euo pipefail

PLATFORM=${PLATFORM:-http://localhost:8080}
OIDC=${OIDC:-http://localhost:8888/auth/realms/opentdf}
CLIENT_ID=${CLIENT_ID:-opentdf}
CLIENT_SECRET=${CLIENT_SECRET:-secret}

TOKEN=""
TOKEN_AT=0
token() {
  if [ -z "$TOKEN" ] || [ $(($(date +%s) - TOKEN_AT)) -gt 200 ]; then
    TOKEN=$(curl -sf -X POST "$OIDC/protocol/openid-connect/token" \
      -d "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&grant_type=client_credentials" | jq -r .access_token)
    TOKEN_AT=$(date +%s)
  fi
}

rpc() {
  token
  local out code
  out=$(curl -s -w '\n%{http_code}' -X POST "$PLATFORM/$1" \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d "$2")
  code=${out##*$'\n'}
  out=${out%$'\n'*}
  if [ "$code" != 200 ]; then
    echo "$1 $2 -> $code $out" >&2
    return 1
  fi
  printf '%s' "$out"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$TMP/rsa2048" 2>/dev/null
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$TMP/rsa4096" 2>/dev/null
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "$TMP/ec256" 2>/dev/null
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 -out "$TMP/ec384" 2>/dev/null
pem() { openssl pkey -in "$TMP/$1" -pubout 2>/dev/null | base64 -w0; }
declare -A PEM=(
  [ALGORITHM_RSA_2048]=$(pem rsa2048)
  [ALGORITHM_RSA_4096]=$(pem rsa4096)
  [ALGORITHM_EC_P256]=$(pem ec256)
  [ALGORITHM_EC_P384]=$(pem ec384)
)
ALGS=(ALGORITHM_RSA_2048 ALGORITHM_EC_P256 ALGORITHM_RSA_4096 ALGORITHM_EC_P384)

COMPANIES=(acme globex initech umbrella hooli stark wayne wonka cyberdyne tyrell
  soylent massive oscorp aperture blackmesa vandelay dunder prestige monarch gringotts
  pied-piper nakatomi weyland octan sirius virtucon zorg rekall veidt ingen
  axiom bluth krusty duff contoso fabrikam northwind tailspin adatum litware
  fourth-coffee wingtip proseware lucerne woodgrove alpine margie trey coho relecloud
  southridge humongous graphic-design wide-world blue-yonder datum consolidated
  treyresearch fineart school-of-fine-art)
TLDS=(com net org io dev)

echo "namespaces"
NS_IDS=()
for i in "${!COMPANIES[@]}"; do
  name="${COMPANIES[$i]}.${TLDS[$((i % ${#TLDS[@]}))]}"
  id=$(rpc policy.namespaces.NamespaceService/CreateNamespace "{\"name\":\"$name\"}" | jq -r .namespace.id) || continue
  NS_IDS+=("$id")
done

DEPARTMENTS=(engineering finance legal marketing sales support hr security operations research
  design product data platform infra mobile web qa compliance procurement
  facilities logistics manufacturing quality treasury tax audit risk strategy partnerships
  communications brand content events education training recruiting payroll benefits analytics
  growth billing fraud trust-safety privacy governance architecture devrel docs localization
  hardware firmware networking sre dba it helpdesk vendor-management real-estate sustainability
  investor-relations corporate-development public-policy government-affairs customer-success
  solutions-engineering professional-services channel-sales inside-sales field-marketing
  demand-gen pricing revenue-ops sales-ops biz-ops people-ops workplace security-ops red-team blue-team)

attr() { # namespace_id name rule values...
  local ns=$1 name=$2 rule=$3
  shift 3
  local id
  id=$(rpc policy.attributes.AttributesService/CreateAttribute \
    "{\"namespaceId\":\"$ns\",\"name\":\"$name\",\"rule\":\"ATTRIBUTE_RULE_TYPE_ENUM_$rule\"}" | jq -r .attribute.id) || return 0
  for v in "$@"; do
    rpc policy.attributes.AttributesService/CreateAttributeValue "{\"attributeId\":\"$id\",\"value\":\"$v\"}" >/dev/null || true
  done
}

echo "attributes"
projects=()
for n in $(seq -w 1 140); do projects+=("prj-$n"); done
regions=(us-east us-west eu-central eu-west ap-south ap-northeast sa-east af-south me-central ca-central)
for k in 0 1 2 3 4 5 6 7 8 9 10 11; do
  ns=${NS_IDS[$k]}
  attr "$ns" classification HIERARCHY top-secret secret confidential internal public
  attr "$ns" department ANY_OF "${DEPARTMENTS[@]:0:$((8 + k * 7))}"
  attr "$ns" region ANY_OF "${regions[@]}"
  attr "$ns" clearance HIERARCHY ts-sci ts s c u
  attr "$ns" need-to-know ALL_OF alpha bravo charlie delta echo foxtrot
  attr "$ns" releasable-to ANY_OF usa gbr can aus nzl fra deu jpn kor nld
  [ "$k" -lt 3 ] && attr "$ns" project ANY_OF "${projects[@]}"
  [ "$k" -lt 2 ] && for extra in tenant partner program contract cohort; do
    attr "$ns" "$extra" ANY_OF $(seq -f "$extra-%02g" 1 $((6 + k * 4)))
  done
done

echo "kas"
KAS_IDS=()
cloud_regions=(us-east-1 us-east-2 us-west-1 us-west-2 eu-west-1 eu-west-2 eu-central-1 eu-north-1
  ap-south-1 ap-southeast-1 ap-southeast-2 ap-northeast-1 ap-northeast-2 ca-central-1 sa-east-1 me-south-1 af-south-1)
for i in $(seq 0 44); do
  org=${COMPANIES[$((i % ${#COMPANIES[@]}))]}
  region=${cloud_regions[$((i % ${#cloud_regions[@]}))]}
  src=SOURCE_TYPE_INTERNAL
  [ $((i % 3)) -eq 2 ] && src=SOURCE_TYPE_EXTERNAL
  body="{\"uri\":\"https://kas.$region.$org.com\",\"name\":\"$org-$region\",\"sourceType\":\"$src\"}"
  id=$(rpc policy.kasregistry.KeyAccessServerRegistryService/CreateKeyAccessServer "$body" | jq -r .keyAccessServer.id) || continue
  KAS_IDS+=("$id")
done

key() { # kas_id key_id alg
  rpc policy.kasregistry.KeyAccessServerRegistryService/CreateKey \
    "{\"kasId\":\"$1\",\"keyId\":\"$2\",\"keyAlgorithm\":\"$3\",\"keyMode\":\"KEY_MODE_PUBLIC_KEY_ONLY\",\"publicKeyCtx\":{\"pem\":\"${PEM[$3]}\"}}" >/dev/null || true
}

echo "keys"
for n in $(seq 1 85); do
  alg=${ALGS[$((n % 4))]}
  key "${KAS_IDS[0]}" "$(printf 'k%03d-%s' "$n" "${alg#ALGORITHM_}" | tr 'A-Z_' 'a-z-')" "$alg"
done
for n in $(seq 1 30); do
  key "${KAS_IDS[1]}" "$(printf 'r%02d' "$n")" ALGORITHM_RSA_2048
done
for i in $(seq 2 $((${#KAS_IDS[@]} - 1))); do
  for n in $(seq 1 $((i % 6))); do
    alg=${ALGS[$(((i + n) % 4))]}
    key "${KAS_IDS[$i]}" "$(printf 'key-%d-%s' "$n" "${alg#ALGORITHM_}" | tr 'A-Z_' 'a-z-')" "$alg"
  done
done

echo "actions"
verbs=(approve archive audit classify copy declassify download edit export forward
  import index label lock move notify print publish purge redact
  release restore review rotate scan share sign stamp transfer unlock
  upload verify view watermark annotate attach backup comment escalate flag
  grant link merge mirror pin quarantine replay retain revoke snapshot
  subscribe summarize sync tag translate)
for k in 0 1; do
  for v in "${verbs[@]:0:$((25 + k * 30))}"; do
    rpc policy.actions.ActionService/CreateAction "{\"name\":\"$v\",\"namespaceId\":\"${NS_IDS[$k]}\"}" >/dev/null || true
  done
done

echo "done"
