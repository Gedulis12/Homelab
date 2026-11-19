#!/bin/sh
set -eu
bucket=maistokainos.lt-scraping-data-processed
root=${SNAPSHOT_SYNC_ROOT:-/localdata}
if [ "${SYNC_SNAPSHOT_HEADS:-false}" = true ]; then
    # Publish payloads before their pointers. Out-of-order network deliveries are
    # retried by the reader, which verifies the compressed SHA before importing.
    mkdir -p "$root/_snapshots/payloads"
    state="$root/_snapshots/.head-etags"
    work=$(mktemp -d "$root/_snapshots/.sync.XXXXXX")
    trap 'rm -rf "$work"' EXIT
    touch "$state"
    aws s3api list-objects-v2 --bucket "$bucket" --prefix _snapshots/heads/ \
        --query 'Contents[].[Key,ETag]' --output text > "$work/list"
    aws s3 sync "s3://$bucket/_snapshots/payloads/" "$root/_snapshots/payloads/" --only-show-errors
    # Same-size replacements can share a timestamp. Compare S3 ETags, then
    # bind each GET to that identity. The rename keeps partial JSON invisible.
    awk 'FILENAME==ARGV[1] {old[$1]=$2;next} NF==2 {print $1,$2,(old[$1]==$2 ? "same":"new")}' "$state" "$work/list" > "$work/changed"
    # A later GET can fail after an earlier rename. Force a full recheck on
    # the next pass rather than trust the previous batch's now-stale cache.
    mv "$state" "$work/old-etags"
    while read -r key etag status; do
        case "$key" in _snapshots/heads/*/*.json) ;; *) continue ;; esac
        if [ "$status" = same ] && [ -s "$root/$key" ]; then continue; fi
        printf '%s\n' "$key" | grep -Eq '^_snapshots/heads/[A-Za-z][A-Za-z0-9]*/[0-9]{8}\.json$' || exit 1
        mkdir -p "$(dirname "$root/$key")"
        aws s3api get-object --bucket "$bucket" --key "$key" --if-match "$etag" "$work/head" > /dev/null
        mv "$work/head" "$root/$key"
    done < "$work/changed"
    mv "$work/list" "$state"
fi
aws s3 sync "s3://$bucket/" "$root/" --exclude '_snapshots/*' --only-show-errors
