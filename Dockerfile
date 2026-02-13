# syntax=docker/dockerfile:1
FROM ruby:3.4.1-slim AS base

ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH=/usr/local/bundle

WORKDIR /app

FROM base AS build
ARG SECRET_KEY_BASE=dummy

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      curl \
      gnupg \
      libsqlite3-dev \
      pkg-config \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && npm install -g corepack \
  && corepack enable \
  && corepack prepare yarn@4.2.2 --activate \
  && rm -rf /var/lib/apt/lists/*

COPY Gemfile* ./
RUN bundle install && bundle clean --force
RUN rm -rf /usr/local/bundle/cache /usr/local/bundle/ruby/*/cache

COPY package.json yarn.lock .yarnrc.yml ./
RUN yarn install --immutable

COPY . .
RUN SECRET_KEY_BASE=${SECRET_KEY_BASE} bundle exec rails vite:build \
  && rm -rf node_modules tmp/cache log/*

FROM base AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
      gnupg \
      libsqlite3-0 \
  && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && corepack enable \
  && corepack prepare yarn@4.2.2 --activate \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app/app /app/app
COPY --from=build /app/bin /app/bin
COPY --from=build /app/config /app/config
COPY --from=build /app/db /app/db
COPY --from=build /app/lib /app/lib
COPY --from=build /app/public /app/public
COPY --from=build /app/Gemfile* /app/
COPY --from=build /app/package.json /app/package.json
COPY --from=build /app/yarn.lock /app/yarn.lock
COPY --from=build /app/.yarnrc.yml /app/.yarnrc.yml
COPY --from=build /app/Rakefile /app/Rakefile
COPY --from=build /app/config.ru /app/config.ru

RUN mkdir -p /app/tmp /app/log /app/storage

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
