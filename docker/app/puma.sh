#!/usr/bin/env bash

export METIS_ENV=development

exec puma --bind tcp://0.0.0.0:3000 \
  --threads 3:16 \
  --redirect-append \
  --pidfile tmp/pids/puma.pid \
  --environment development