#!/usr/bin/env bash
set -euo pipefail
image="${1:?Usage: verify-image.sh IMAGE}"
size="$(docker image inspect --format '{{.Size}}' "$image")"
user="$(docker image inspect --format '{{.Config.User}}' "$image")"
test "$size" -lt 60000000
test "$user" = '65532:65532'
name="agentbench-hexclock-check-$$"
probe="agentbench-hexclock-probe-$$"
trap 'docker rm -f "$probe" "$name" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$name" --read-only --cap-drop ALL --security-opt no-new-privileges "$image" >/dev/null
# Probe inside the Docker network so this also works with a remote daemon.
request() {
  docker run --rm --name "$probe" --network "container:$name" \
    --read-only --cap-drop ALL --security-opt no-new-privileges \
    golang:1.26-alpine@sha256:8ac98ca534ac3f51e1f420a1dd2c15e74c75cfa0f23f3ad27eb5d7236c349a0c \
    wget -qO- -T 5 "http://127.0.0.1:8080$1"
}
for attempt in {1..30}; do
  if request /healthz > /dev/null; then break; fi
  sleep 1
done
health="$(request /healthz)"
test "$health" = '{"status":"ok"}'
clock="$(request /)"
pattern='^\{"time":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z"\}$'
[[ "$clock" =~ $pattern ]]
printf 'Verified %s: %s bytes, user %s, health %s, clock %s\n' "$image" "$size" "$user" "$health" "$clock"
