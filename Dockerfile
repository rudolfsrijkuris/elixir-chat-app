# Build stage — use an explicit hexpm/elixir tag (they use full tags with date, e.g. ...-bookworm-20240513-slim)
FROM hexpm/elixir:1.16.2-erlang-26.2.5-debian-bookworm-20240513-slim AS builder

RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

# Install Tailwind CLI (used by mix assets.deploy)
RUN mix tailwind.install
RUN mix esbuild.install

RUN mix compile
RUN mix assets.deploy
RUN mix release

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody:nogroup /app

USER nobody

ENV MIX_ENV="prod"

COPY --from=builder --chown=nobody:nogroup /app/_build/${MIX_ENV}/rel/chat_api ./

# Set env for Phoenix
ENV PHX_SERVER=true

# Coolify and most PaaS set PORT
ENV PORT=4000

EXPOSE ${PORT}

CMD ["/app/bin/server"]
