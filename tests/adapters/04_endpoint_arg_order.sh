#!/usr/bin/env bash
# 04_endpoint_arg_order.sh
#
# Guards every callPublicFn() call site in the better-auth adapter against the
# live signature of the SQL function it targets.
#
# WHY: callPublicFn binds arguments POSITIONALLY ($1, $2, ...). Every handler
# parameter is a `string`, so TypeScript cannot detect a transposition, and a
# mocked test cannot either. When two transposed parameters happen to be
# type-compatible (a uuid is valid `text`), the mis-binding is silent and the
# error surfaces one argument later, looking like a caller problem.
# This is exactly how create_invitation shipped with [orgId, email, roleId]
# against (p_email, p_organization_id, p_role_id).
#
# HOW: extract each call site's argument list, map each JavaScript identifier to
# the SQL parameter name(s) it may legitimately bind to, and compare positionally
# against (proargnames)[1:pronargs] from pg_proc.
#
# Requires a database with the SMTA public.* functions loaded. Connection comes
# from DB_URL, or from the standard PG* environment variables that
# scripts/run_tests.sh exports.
set -uo pipefail

ENDPOINTS_FILE="packages/better-auth/src/plugin/endpoints.ts"
CONN="${DB_URL:-}"
FAILURES=0

if [ ! -f "$ENDPOINTS_FILE" ]; then
  echo "ERROR: $ENDPOINTS_FILE not found (run from the repository root)" >&2
  exit 2
fi

if ! psql "$CONN" -c "SELECT 1" >/dev/null 2>&1; then
  echo "ERROR: cannot connect to database (set DB_URL or PGHOST/PGPORT/PGUSER/...)" >&2
  exit 2
fi

# Which SQL parameter names may a given JS identifier bind to?
# Deliberately permissive about naming (p_org_id vs p_organization_id vs p_id)
# and strict about identity: an id expression can never satisfy p_email, which
# is what makes a transposition detectable.
acceptable_names() {
  case "$1" in
    name)         echo "p_name" ;;
    description)  echo "p_description" ;;
    email)        echo "p_email" ;;
    token)        echo "p_token" ;;
    status)       echo "p_status" ;;
    metadata)     echo "p_metadata" ;;
    orgId)        echo "p_organization_id p_org_id p_id" ;;
    roleId)       echo "p_role_id" ;;
    unitId)       echo "p_unit_id p_id" ;;
    userId)       echo "p_user_id p_id" ;;
    invitationId) echo "p_invitation_id p_id" ;;
    *)            echo "" ;;
  esac
}

echo "Checking callPublicFn() argument order in $ENDPOINTS_FILE ..."

# Each call site is a single line of the form:
#   callPublicFn(client, 'public.<fn>', [<args>])
CALL_SITES=$(grep -oP "callPublicFn\(client, 'public\.\K[a-z_]+(?=', \[)" "$ENDPOINTS_FILE")
# Capture the brackets too, so an empty list ("[]") still produces a line.
ARG_LISTS=$(grep -oP "callPublicFn\(client, 'public\.[a-z_]+', \K\[[^]]*\]" "$ENDPOINTS_FILE")

if [ -z "$CALL_SITES" ]; then
  echo "FAIL: no callPublicFn() call sites found — has the helper been renamed?" >&2
  exit 1
fi

SITE_COUNT=$(printf '%s\n' "$CALL_SITES" | wc -l)
LIST_COUNT=$(printf '%s\n' "$ARG_LISTS" | wc -l)
if [ "$SITE_COUNT" != "$LIST_COUNT" ]; then
  echo "FAIL: parsed $SITE_COUNT function names but $LIST_COUNT argument lists" >&2
  exit 1
fi

for i in $(seq 1 "$SITE_COUNT"); do
  FN=$(printf '%s\n' "$CALL_SITES" | sed -n "${i}p")
  RAW_ARGS=$(printf '%s\n' "$ARG_LISTS" | sed -n "${i}p" | sed -E 's/^\[|\]$//g')

  # Live input-parameter names, in declaration order. RETURNS TABLE columns are
  # OUT parameters and also appear in proargnames, so slice to pronargs.
  SQL_PARAMS=$(psql "$CONN" -t -A -c "
    select coalesce(array_to_string((p.proargnames)[1:p.pronargs], ' '), '')
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = '${FN}'
    order by p.pronargs desc
    limit 1;" 2>/dev/null | tr -d '\r')

  if [ -z "$SQL_PARAMS" ] && [ -n "$RAW_ARGS" ]; then
    echo "  ✗ public.${FN}: function not found in the database (or takes no arguments)"
    FAILURES=$((FAILURES + 1))
    continue
  fi

  # Normalise the JS argument expressions to bare identifiers:
  #   "name, description ?? null"  ->  "name" "description"
  JS_ARGS=()
  if [ -n "${RAW_ARGS// /}" ]; then
    IFS=',' read -r -a RAW_PARTS <<< "$RAW_ARGS"
    for part in "${RAW_PARTS[@]}"; do
      ident=$(printf '%s' "$part" \
        | sed -E 's/\?\?.*$//' \
        | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
      JS_ARGS+=("$ident")
    done
  fi

  read -r -a PARAM_ARR <<< "$SQL_PARAMS"

  if [ "${#JS_ARGS[@]}" -gt "${#PARAM_ARR[@]}" ]; then
    echo "  ✗ public.${FN}: passes ${#JS_ARGS[@]} argument(s) but the function accepts ${#PARAM_ARR[@]}"
    FAILURES=$((FAILURES + 1))
    continue
  fi

  SITE_OK=1
  for idx in "${!JS_ARGS[@]}"; do
    JS_IDENT="${JS_ARGS[$idx]}"
    EXPECTED="${PARAM_ARR[$idx]}"
    ALLOWED=$(acceptable_names "$JS_IDENT")

    if [ -z "$ALLOWED" ]; then
      echo "  ✗ public.${FN}: \$$((idx + 1)) is '${JS_IDENT}', which this guard does not know."
      echo "      Add it to acceptable_names() so the binding stays checked."
      SITE_OK=0
      continue
    fi

    if ! printf '%s\n' $ALLOWED | grep -qx "$EXPECTED"; then
      echo "  ✗ public.${FN}: \$$((idx + 1)) binds '${JS_IDENT}' to parameter '${EXPECTED}'"
      echo "      '${JS_IDENT}' may only bind to: ${ALLOWED}"
      echo "      live signature: ${SQL_PARAMS}"
      SITE_OK=0
    fi
  done

  if [ "$SITE_OK" = 1 ]; then
    echo "  ✓ public.${FN}(${SQL_PARAMS// /, }) ← [${JS_ARGS[*]}]"
  else
    FAILURES=$((FAILURES + 1))
  fi
done

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "OK: all ${SITE_COUNT} callPublicFn() call sites match their SQL signatures"
  exit 0
fi

echo "FAIL: ${FAILURES} call site(s) disagree with the live SQL signature" >&2
exit 1
