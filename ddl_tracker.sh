#!/bin/bash

# Check if the current node is the leader (primary)
IS_LEADER=$(psql -U postgres -d postgres -tAc "SELECT pg_is_in_recovery()")

# If not in recovery, it is the primary (leader)
if [[ "$IS_LEADER" == "f" ]]; then
  echo "This is the primary node. Setting up the DDL tracker..."

  # Create a trigger function to log all DDL changes with full statements
  psql -U postgres -d postgres -c "
  CREATE OR REPLACE FUNCTION log_full_ddl_changes() RETURNS event_trigger AS \$\$
  DECLARE
    ddl_query TEXT;
  BEGIN
    -- Get the exact DDL command that was just executed (terminated by a semicolon)
    SELECT current_query() INTO ddl_query
    FROM pg_stat_activity
    WHERE pid = pg_backend_pid();

    -- Insert the full DDL statement into the log
    INSERT INTO ddl_log (command_tag, full_ddl_query, event_time)
    VALUES (TG_TAG, ddl_query, CURRENT_TIMESTAMP);
  END;
  \$\$ LANGUAGE plpgsql;
  "

  # Create a table to store the DDL logs with full queries
  psql -U postgres -d postgres -c "
  CREATE TABLE IF NOT EXISTS ddl_log (
      id SERIAL PRIMARY KEY,
      command_tag TEXT,
      full_ddl_query TEXT,
      event_time TIMESTAMP
  );
  "

  # Set the event trigger to capture all DDL statements
  psql -U postgres -d postgres -c "
  CREATE EVENT TRIGGER capture_all_ddl ON ddl_command_end
    EXECUTE FUNCTION log_full_ddl_changes();
  "

  echo "DDL tracker is set up and ready to log full-length DDL queries."
else
  echo "This is a replica node, skipping DDL tracker setup."
fi
