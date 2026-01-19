# Build image
FROM alpine:3.22 AS build

ARG REPOSITORY=https://github.com/writefreely/writefreely.git
ARG VERSION=main

RUN apk add --no-cache \
    ca-certificates \
    git \
    go \
    build-base \
    nodejs \
    npm

RUN npm install -g less less-plugin-clean-css

WORKDIR /src

RUN git init writefreely && \
    cd writefreely && \
    git remote add origin "${REPOSITORY}" && \
    git fetch --depth 1 origin "${VERSION}" && \
    git checkout -q FETCH_HEAD

WORKDIR /src/writefreely

RUN go build -trimpath -ldflags "-s -w" -tags='sqlite' -o /out/writefreely ./cmd/writefreely/

RUN cd less && \
    CSSDIR=../static/css && \
    lessc app.less --clean-css="--s1 --advanced" ${CSSDIR}/write.css && \
    lessc fonts.less --clean-css="--s1 --advanced" ${CSSDIR}/fonts.css && \
    lessc icons.less --clean-css="--s1 --advanced" ${CSSDIR}/icons.css && \
    lessc prose.less --clean-css="--s1 --advanced" ${CSSDIR}/prose.css

RUN cd prose && \
    export NODE_OPTIONS=--openssl-legacy-provider && \
    npm ci && \
    npm run-script build

# Final image
FROM alpine:3.22

RUN apk add --no-cache openssl ca-certificates wget

COPY --from=build /out/writefreely /writefreely/writefreely
COPY --from=build /src/writefreely/templates /writefreely/templates
COPY --from=build /src/writefreely/pages /writefreely/pages
COPY --from=build /src/writefreely/static /writefreely/static
COPY bin/entrypoint.sh /writefreely/
RUN chmod +x /writefreely/entrypoint.sh

WORKDIR /writefreely
VOLUME /data
VOLUME /config
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/ >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/writefreely/entrypoint.sh"]