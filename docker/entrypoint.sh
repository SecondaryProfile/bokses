#!/bin/sh
# Runs the API server and nginx side by side. If either one exits on its own,
# the other is stopped too and the container exits non-zero, so Docker's
# restart policy brings the whole thing back. `docker stop` exits cleanly.
set -u

bokses-server &
api_pid=$!

nginx -g 'daemon off;' &
nginx_pid=$!

stopping=0
stop() {
  stopping=1
  kill -TERM "$api_pid" "$nginx_pid" 2>/dev/null
}
trap stop TERM INT

while [ "$stopping" -eq 0 ] \
  && kill -0 "$api_pid" 2>/dev/null \
  && kill -0 "$nginx_pid" 2>/dev/null; do
  sleep 1
done

if [ "$stopping" -eq 0 ]; then
  if kill -0 "$api_pid" 2>/dev/null; then
    echo "bokses: nginx exited unexpectedly; stopping the API server" >&2
  else
    echo "bokses: API server exited unexpectedly; stopping nginx" >&2
  fi
  kill -TERM "$api_pid" "$nginx_pid" 2>/dev/null
  wait
  exit 1
fi

wait
exit 0
