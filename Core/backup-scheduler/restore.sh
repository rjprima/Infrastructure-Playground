#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="mock_key"
export AWS_SECRET_ACCESS_KEY="mock_secret"
export AWS_DEFAULT_REGION="us-west-1"

trap 'rm -f "/tmp/backup.sql"' EXIT

for ((i = 0; i < $worker_count; i++)); do
    curl -X POST http://worker-$i:$worker_port \
    -H "Content-Type: application/json" \
    -d '{"purpose": "pause"}';
done

aws --endpoint-url="http://s3-emulator:4566" s3 cp s3://db-backups/backup.sql /tmp/backup.sql
psql -d simplified_expressions -U $postgres_user -p $postgres_port -h database -f /tmp/backup.sql

for ((i = 0; i < $worker_count; i++)); do
    curl -X POST http://worker-$i:$worker_port \
    -H "Content-Type: application/json" \
    -d '{"purpose": "restore"}';
done    