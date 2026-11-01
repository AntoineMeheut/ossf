FROM debian:trixie-slim@sha256:f6b08b09a05725f9431502d3b5714f5c4576e82c1a84fa1debe0c24a7e0c3ec4
ARG C_EXECUTABLE=/usr/local/bin/app
ENV C_EXECUTABLE=${C_EXECUTABLE}
COPY .ci-dist/ /
COPY ci/entrypoint.sh /usr/local/bin/application-entrypoint
USER 10001:10001
ENTRYPOINT ["sh", "/usr/local/bin/application-entrypoint"]
