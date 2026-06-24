#!/usr/bin/env bash
# Ensures the roles.sql stays identical across non-supabase adapters.
set -euo pipefail
diff packages/better-auth/sql/init/roles.sql \
     packages/payload/sql/init/roles.sql \
  && echo "OK: roles.sql in sync"
