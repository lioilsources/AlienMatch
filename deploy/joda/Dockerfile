# Runtime image for JODA. deploy.sh cross-compiles the binary on the Mac
# (CGO_ENABLED=0, linux/amd64), so JODA (3.8 GB RAM) never runs a Go build.
FROM gcr.io/distroless/static-debian12:nonroot
COPY bin/alienmatch-api /usr/local/bin/alienmatch-api
EXPOSE 8080
VOLUME /media
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s CMD ["/usr/local/bin/alienmatch-api", "healthcheck"]
ENTRYPOINT ["/usr/local/bin/alienmatch-api"]
