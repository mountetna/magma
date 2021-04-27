FROM etna-base
# Perform these steps first to allow better caching behavior
COPY src/Gemfile src/Gemfile.lock /app/
RUN bundle config set --local no_prune 'true'
RUN bundle config set --local deployment 'true'
RUN bundle install
COPY src /app/
ARG APP_NAME
ARG RUN_NPM_INSTALL
ARG SKIP_RUBY_SETUP=1
RUN /entrypoints/build.sh
