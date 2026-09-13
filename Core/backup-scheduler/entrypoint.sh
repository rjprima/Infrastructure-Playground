#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="mock_key"
export AWS_SECRET_ACCESS_KEY="mock_secret"
export AWS_DEFAULT_REGION="us-west-1"

until aws --endpoint-url="http://s3-emulator:4566" s3 ls >/dev/null 2>&1; do
    sleep 2
done

aws --endpoint-url="http://s3-emulator:4566" s3 mb "s3://db-backups"

exec "$@"