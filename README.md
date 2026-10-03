# hexclock

A tiny Go HTTP service. `GET /` returns the current UTC time as JSON
(`{"time":"2026-10-03T16:30:45.123456789Z"}`); `GET /healthz` returns
`{"status":"ok"}`. It listens on port 8080 and disables response caching.
Unknown paths return 404; unsupported methods return 405.

Run the published image (Linux AMD64 or ARM64):

```sh
docker run --rm --name agentbench-hexclock -p 8080:8080 ghcr.io/fregas/agentbench-hexclock-v3-17-a:0.1.1
curl http://localhost:8080/
curl http://localhost:8080/healthz
```

The GHCR package is private. First run `docker login ghcr.io` with your
GitHub username and a token with `read:packages` access. Tags `0.1.0` and
`latest` are also published.

Test locally with Go 1.26+ using `go test -v ./...` and `go vet ./...`, or use
Docker (the build runs both):

```sh
docker build -t agentbench-hexclock .
./scripts/verify-image.sh agentbench-hexclock
```

The multi-stage build produces a static binary in a `scratch` image, running
as UID/GID 65532. The smoke test enforces the 60 MB limit and checks both
endpoints in a read-only container.

Pushing a Git tag matching `v*` triggers `.github/workflows/publish.yml`.
The workflow tests and checks the image, then publishes AMD64 and ARM64 images
to GHCR, stripping the leading `v` from the image tag and updating `latest`.
It uses its own `GITHUB_TOKEN` with `contents: read` and `packages: write`;
no personal token is stored in Actions. `secrets/` is excluded from git and
the Docker build context.
