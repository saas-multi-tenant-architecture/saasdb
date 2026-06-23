#!/usr/bin/env bash
# Ensures the pgcrypto secrets impl stays identical across non-supabase adapters.
set -euo pipefail
diff packages/better-auth/sql/init/secrets_pgcrypto_impl.sql \
     packages/payload/sql/init/secrets_pgcrypto_impl.sql \
  && echo "OK: pgcrypto secrets impl in sync"
