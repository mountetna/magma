#!/bin/bash
set -e

export PATH="/app/node_modules/.bin:/app/vendor/bundle/$RUBY_VERSION/bin:$PATH"

if [ -z "$SKIP_RUBY_SETUP" ]; then
  bundle check || bundle install -j "$(nproc)"

  rm -f tmp/pids/*.pid
  if [ -z "$SKIP_DB_WAIT" ]; then
    dockerize -wait tcp://magma_db:5432 -timeout 60s

    for project in $(cat config.yml | grep ':project_path:' | sed -e 's/.*:project_path:\s*//g'); do
      echo $project
      bin/magma create_db "$(basename $project)"
      MAGMA_ENV=test bin/magma create_db "$(basename $project)"
      bin/magma migrate "$(basename $project)"
      MAGMA_ENV=test bin/magma migrate "$(basename $project)"
    done

    bin/magma migrate
    bin/magma global_migrate
  fi
fi

exec "$@"
