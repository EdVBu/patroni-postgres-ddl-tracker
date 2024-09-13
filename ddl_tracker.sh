#!/bin/bash

LOGFILE="/var/log/ddl_tracker.log"

echo "Tracking DDL changes in PostgreSQL..."

psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

while true; do
  DDL_LOG=$(psql -U postgres -c "SELECT query FROM pg_stat_statements WHERE query ~* 'create|alter|drop';")
  if [ ! -z "$DDL_LOG" ]; then
    echo "$(date): $DDL_LOG" >> $LOGFILE
  fi
  sleep 10
done

