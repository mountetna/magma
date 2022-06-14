FROM etna-base
# Perform these steps first to allow better caching behavior
RUN bundle config set --local no_prune 'true'
RUN bundle config set --local deployment 'true'
COPY . /app/
ARG APP_NAME
ARG FULL_BUILD=1
RUN /entrypoints/build.sh
