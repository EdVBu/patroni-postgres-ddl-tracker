# Patroni-Postgres: Easy-to-Use PostgreSQL Cluster with DDL Tracking

This repository provides an easy-to-deploy PostgreSQL cluster running in Kubernetes using Patroni for high availability. It includes a built-in mechanism to track all Data Definition Language (DDL) queries for auditing or recovery purposes.

## Features

- **Highly Available PostgreSQL**: Powered by Patroni, the cluster uses Kubernetes to ensure automatic failover and redundancy.
- **DDL Query Logging**: Automatically logs full DDL queries (e.g., `CREATE TABLE`, `CREATE INDEX`, `DROP TABLE`) to help track schema changes.
- **Easy Kubernetes Setup**: The repository includes all necessary Kubernetes manifests to quickly deploy the cluster in a local or cloud Kubernetes environment.

## Repository Structure

```bash
.
├── Dockerfile           # Builds the custom Postgres + Patroni image
├── ddl_tracker.sh       # Script for setting up the DDL tracking mechanism
├── entrypoint.sh        # Custom entrypoint to initialize the cluster and DDL tracking
└── patroni_k8s.yaml     # Kubernetes manifest for deploying the Postgres cluster
```

## DDL Logging
This solution captures full-length DDL queries executed on the database for auditing purposes. All tracked queries are stored in the `ddl_log` table.

### Example of a logged entry in `ddl_log`:

| id  | command_tag  | full_ddl_query                                        | event_time          |
|-----|--------------|-------------------------------------------------------|---------------------|
| 1   | CREATE SCHEMA | `CREATE SCHEMA IF NOT EXISTS example_schema;`         | 2024-09-16 12:00:00 |
| 2   | CREATE TABLE  | `CREATE TABLE example_schema.example_table (...);`    | 2024-09-16 12:00:05 |
| 3   | CREATE INDEX  | `CREATE INDEX idx_example_col ON example_table (...);`| 2024-09-16 12:00:10 |

### Enabling DDL Logging
The logging mechanism is enabled by the `ddl_tracker.sh` script. This script creates a trigger that logs all DDL commands into a dedicated table:

```sql
CREATE OR REPLACE FUNCTION log_full_ddl_changes() RETURNS event_trigger AS $$
DECLARE
  ddl_record RECORD;
BEGIN
  FOR ddl_record IN
    SELECT command_tag, object_type, schema_name, object_identity, statement
    FROM pg_event_trigger_ddl_commands()
  LOOP
    INSERT INTO ddl_log (command_tag, full_ddl_query, event_time)
    VALUES (ddl_record.command_tag, ddl_record.statement, CURRENT_TIMESTAMP);
  END LOOP;
END;
$$ LANGUAGE plpgsql;
```

## Quick Start Guide

### Requirements
- **Kubernetes** (tested with Minikube)
- **Docker** (for building the custom image)
- **kubectl** (to deploy the cluster)

### Setup and Deployment
Follow these steps to build the Docker image and deploy the cluster in Minikube:

1. **Start Minikube and build the image**:
```bash
minikube start
docker build -t patroni-postgres .
minikube image load patroni-postgres
```

2. **Deploy the Kubernetes configuration**:
```bash
kubectl apply -f patroni_k8s.yaml
```

3. **Check the status of the pods**:
```bash
kubectl get pods -l application=patroni
```

4. **Verify the logs of the leader pod**:
```bash
kubectl logs pod/patroni-postgres-0
kubectl logs pod/patroni-postgres-1
kubectl logs pod/patroni-postgres-2
```

5. **Execute SQL queries using the leader pod**:
```bash
kubectl exec -ti pod/patroni-postgres-0 -- psql -U postgres
```

### Testing DDL Tracking
After deploying the cluster, you can test the DDL tracking feature by running the following SQL commands:

```sql
CREATE SCHEMA IF NOT EXISTS example_schema;

CREATE TABLE IF NOT EXISTS example_schema.example_table (
    id SERIAL PRIMARY KEY,
    name TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_example_col ON example_schema.example_table (name);
```

To check the DDL log, run:
```bash
kubectl exec -ti pod/patroni-postgres-0 -- psql -U postgres -d postgres -c "SELECT * FROM ddl_log;"
```

### DDL Log Table Structure
The DDL changes are stored in the `ddl_log` table with the following structure:

```sql
CREATE TABLE ddl_log (
    id SERIAL PRIMARY KEY,
    command_tag TEXT,
    full_ddl_query TEXT,
    event_time TIMESTAMP
);
```

This table stores each executed DDL query along with its timestamp, providing a clear audit trail of all changes made to the database structure.

###Contributing
Feel free to submit issues, feature requests, and pull requests to enhance this project. Contributions are welcome to improve the ease of use, feature set, and documentation.
