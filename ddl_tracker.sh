#!/bin/bash

# Define the DDL log file
DDL_LOG="/home/postgres/pgdata/pgroot/data/ddl_log.sql"

# Create a trigger function to track all DDL changes
psql -U postgres -d postgres -c "
CREATE OR REPLACE FUNCTION log_ddl_changes() RETURNS event_trigger AS \$\$
BEGIN
  IF TG_TAG IN ('CREATE TABLE', 'ALTER TABLE', 'DROP TABLE', 'CREATE INDEX', 'DROP INDEX') THEN
    -- Insert the changes into the ddl_log table
    EXECUTE format('INSERT INTO ddl_log (command_tag, object_name, event_time) VALUES (''%s'', ''%s'', CURRENT_TIMESTAMP);', TG_TAG, current_schema());
    
    -- Log the changes to the ddl_log.sql file
    PERFORM pg_notify('ddl_log', TG_TAG || ' on schema ' || current_schema());
  END IF;
END;
\$\$ LANGUAGE plpgsql;
"

# Create a table to store the DDL logs if it doesn't already exist
psql -U postgres -d postgres -c "
CREATE TABLE IF NOT EXISTS ddl_log (
    id SERIAL PRIMARY KEY,
    command_tag TEXT,
    object_name TEXT,
    event_time TIMESTAMP
);
"

# Set the event trigger to fire on any DDL statement
psql -U postgres -d postgres -c "
CREATE EVENT TRIGGER ddl_trigger ON ddl_command_end
  EXECUTE FUNCTION log_ddl_changes();
"

# Monitor the DDL event log and append to the ddl_log.sql file
psql -U postgres -d postgres -c "LISTEN ddl_log;" &
while true; do
  read -r -t 5 LINE
  if [[ ! -z "$LINE" ]]; then
    echo "$LINE" >> $DDL_LOG
  fi
done
