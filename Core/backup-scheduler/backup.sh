#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="mock_key"
export AWS_SECRET_ACCESS_KEY="mock_secret"
export AWS_DEFAULT_REGION="us-west-1"

trap 'rm -f "/tmp/backup.sql"' EXIT

pg_dump -h database -U $postgres_user -d simplified_expressions > /tmp/backup.sql -p $postgres_port

aws --endpoint-url="http://s3-emulator:4566" s3 cp /tmp/backup.sql s3://db-backups/