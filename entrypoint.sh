#!/bin/bash

if [[ $UID -ge 10000 ]]; then
    GID=$(id -g)
    sed -e "s/^postgres:x:[^:]*:[^:]*:/postgres:x:$UID:$GID:/" /etc/passwd > /tmp/passwd
    cat /tmp/passwd > /etc/passwd
    rm /tmp/passwd
fi

# Ensure the data directory has the correct permissions
if [ ! -d "/home/postgres/pgdata/pgroot/data" ]; then
    mkdir -p /home/postgres/pgdata/pgroot/data
fi
chown -R postgres:postgres /home/postgres/pgdata/pgroot/data
chmod 0700 /home/postgres/pgdata/pgroot/data

cat > /home/postgres/patroni.yml <<__EOF__
bootstrap:
  dcs:
    postgresql:
      use_pg_rewind: true
      pg_hba:
      - host all all 0.0.0.0/0 md5
      - host replication ${PATRONI_REPLICATION_USERNAME} ${PATRONI_KUBERNETES_POD_IP}/16 md5
      - host replication ${PATRONI_REPLICATION_USERNAME} ${PATRONI_KUBERNETES_POD_IP}/16 md5
      - local all all trust  # Allow local connections for all users
      - host replication ${PATRONI_REPLICATION_USERNAME} 127.0.0.1/32 trust  # Allow localhost for replication
      - host replication ${PATRONI_REPLICATION_USERNAME} ::1/128 trust  # IPv6 localhost
  initdb:
  - auth-host: md5
  - auth-local: trust
  - encoding: UTF8
  - locale: en_US.UTF-8
  - data-checksums
restapi:
  connect_address: '${PATRONI_KUBERNETES_POD_IP}:8008'
postgresql:
  connect_address: '${PATRONI_KUBERNETES_POD_IP}:5432'
  data_dir: '${PATRONI_POSTGRESQL_DATA_DIR}'  # Set the data_dir from the environment variable
  authentication:
    superuser:
      password: '${PATRONI_SUPERUSER_PASSWORD}'
    replication:
      password: '${PATRONI_REPLICATION_PASSWORD}'
kubernetes:
  namespace: '${PATRONI_KUBERNETES_NAMESPACE}'
  labels:
    application: patroni
    cluster-name: patroni-postgres
  role_label: role
  pod_ip: ${PATRONI_KUBERNETES_POD_IP}
  name: ${PATRONI_NAME}  # Ensure the pod name is passed correctly
__EOF__

unset PATRONI_SUPERUSER_PASSWORD PATRONI_REPLICATION_PASSWORD

exec /usr/bin/python3 /usr/local/bin/patroni /home/postgres/patroni.yml
