#!/usr/bin/env bash
# Maps the opentdf and opentdf-sdk clients onto acme.com attribute values, so
# GetEntitlements and GetDecision have something to show. Run after seed.sh.
set -euo pipefail

PLATFORM=${PLATFORM:-http://localhost:8080}
OIDC=${OIDC:-http://localhost:8888/auth/realms/opentdf}
TOKEN=$(curl -sf -X POST "$OIDC/protocol/openid-connect/token" \
  -d "client_id=${CLIENT_ID:-opentdf}&client_secret=${CLIENT_SECRET:-secret}&grant_type=client_credentials" | jq -r .access_token)

rpc() {
  curl -sf -X POST "$PLATFORM/$1" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d "$2"
}

ATTRS=$(rpc policy.attributes.AttributesService/ListAttributes '{"namespace":"acme.com","pagination":{"limit":100}}')

value_id() { # attribute value
  jq -r --arg a "$1" --arg v "$2" '.attributes[] | select(.name == $a) | .values[] | select(.value == $v) | .id' <<<"$ATTRS"
}

map() { # attribute value actions(csv) clients(csv)
  local id actions clients
  id=$(value_id "$1" "$2")
  [ -n "$id" ] || { echo "no value $1/$2" >&2; return; }
  actions=$(jq -c -n --arg a "$3" '$a | split(",") | map({name: .})')
  clients=$(jq -c -n --arg c "$4" '$c | split(",")')
  rpc policy.subjectmapping.SubjectMappingService/CreateSubjectMapping "$(jq -c -n \
    --arg id "$id" --argjson actions "$actions" --argjson clients "$clients" '{
      attributeValueId: $id,
      actions: $actions,
      newSubjectConditionSet: { subjectSets: [ { conditionGroups: [ {
        booleanOperator: "CONDITION_BOOLEAN_TYPE_ENUM_AND",
        conditions: [ {
          subjectExternalSelectorValue: ".clientId",
          operator: "SUBJECT_MAPPING_OPERATOR_ENUM_IN",
          subjectExternalValues: $clients
        } ]
      } ] } ] }
    }')" >/dev/null || echo "failed $1/$2" >&2
}

map classification confidential read opentdf
map classification public read opentdf-sdk
map clearance s read opentdf
map clearance c read opentdf-sdk
for d in engineering finance legal security; do map department "$d" read,update opentdf; done
map department engineering read opentdf-sdk
for r in us-east us-west eu-west; do map region "$r" read opentdf; done
map region us-east read opentdf-sdk
for n in alpha bravo charlie; do map need-to-know "$n" read opentdf; done
map need-to-know alpha read opentdf-sdk
for c in usa gbr can; do map releasable-to "$c" read opentdf; done
for n in $(seq -f "prj-%03g" 1 40); do map project "$n" read,update,delete opentdf; done
echo done
