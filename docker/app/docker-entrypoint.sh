#!/bin/bash
set -e

export PATH="/app/node_modules/.bin:/app/vendor/bundle/$RUBY_VERSION/bin:$PATH"

function findEnvConfig() {
  wget https://github.com/mikefarah/yq/releases/download/3.3.2/yq_linux_amd64 -o /dev/null -O ~/yq
  chmod +x ~/yq
  ~/yq r /app/config.yml ":${MAGMA_ENV:development}"
}

if [ -z "$SKIP_RUBY_SETUP" ]; then
  bundle check || bundle install -j "$(nproc)"
  rm -f tmp/pids/*.pid

  mkdir -p tmp/pids

  if [ -z "$SKIP_DB_WAIT" ]; then
    dockerize -wait tcp://magma_db:5432 -timeout 60s

    for project in $(findEnvConfig | grep ':project_path:' | sed -e 's/.*:project_path:\s*//g'); do
      echo "Initializing $project..."
      bin/magma create_db "$(basename $project)"
    done

    bin/magma global_migrate
    bin/magma migrate
  fi
fi

exec "$@"
