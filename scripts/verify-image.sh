#!/usr/bin/env bash
set -euo pipefail
image="${1:?Usage: verify-image.sh IMAGE}"
size="$(docker image inspect --format '{{.Size}}' "$image")"
user="$(docker image inspect --format '{{.Config.User}}' "$image")"
test "$size" -lt 60000000
test "$user" = '65532:65532'
name="agentbench-hexclock-check-$$"
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$name" --read-only --cap-drop ALL --security-opt no-new-privileges -p 127.0.0.1::8080 "$image" >/dev/null
address="$(docker port "$name" 8080/tcp)"
for attempt in {1..30}; do
  if curl -fsS "http://$address/healthz" > /dev/null; then break; fi
  sleep 1
done
health="$(curl -fsS "http://$address/healthz")"
test "$health" = '{"status":"ok"}'
clock="$(curl -fsS "http://$address/")"
pattern='^\{"time":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z"\}$'
[[ "$clock" =~ $pattern ]]
printf 'Verified %s: %s bytes, user %s, health %s, clock %s\n' "$image" "$size" "$user" "$health" "$clock"
