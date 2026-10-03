FROM --platform=$BUILDPLATFORM golang:1.26-alpine@sha256:8ac98ca534ac3f51e1f420a1dd2c15e74c75cfa0f23f3ad27eb5d7236c349a0c AS build
WORKDIR /src
COPY go.mod *.go ./
RUN go test -v ./... && go vet ./...
ARG TARGETOS
ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -trimpath -ldflags="-s -w" -o /out/hexclock .

FROM scratch
LABEL org.opencontainers.image.title="hexclock" \
      org.opencontainers.image.description="Small UTC JSON clock service" \
      org.opencontainers.image.source="https://github.com/fregas/agentbench-hexclock-v3-17-a"
COPY --from=build /out/hexclock /hexclock
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/hexclock"]
