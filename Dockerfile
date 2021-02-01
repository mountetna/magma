FROM etna-base
# Perform these steps first to allow better caching behavior
ADD src/Gemfile src/Gemfile.lock /app/
RUN bundle install
ADD src /app/
ARG APP_NAME
ARG RUN_NPM_INSTALL
ARG SKIP_RUBY_SETUP=1
RUN /entrypoints/build.sh
