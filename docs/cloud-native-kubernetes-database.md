---
title: 'Production Kubernetes: Database'
---

# Production Kubernetes: Database

Three services in the deployment persist data: the Configuration Service (domains, trust anchors, certificates, settings), the Message Monitor (transaction and notification tracking), and Apache James (users, mailboxes, message content). By default each uses a file-backed embedded database, which is convenient but not something to run a production HISP on.

## What the default configuration does

In the [`direct-project-k8s`](https://github.com/DirectProjectJavaRI/direct-project-k8s) manifests:

* **Configuration Service** — embedded H2 file database on the `config-service-data` `PersistentVolumeClaim`.
* **Message Monitor** — the stock image runs an in-memory H2 database; the manifest overrides `spring.datasource.url` to an H2 *file* database on the `direct-msg-monitor-data` PVC so data survives restarts.
* **James** — embedded Apache Derby on the `direct-james-server-data` PVC.

Each of these engines takes an exclusive lock on its files, so all three `Deployment`s are pinned to `replicas: 1` with `strategy: Recreate`. Data lives only as long as the PVC, there is no replication or point-in-time recovery, and horizontal scaling of those services is impossible while they stay on the embedded engine.

## Options to consider

Move these services to **MySQL** or **PostgreSQL**:

**Use an existing database.** If your organization already operates a managed MySQL/PostgreSQL platform, create a database (or one per service) and point the RI at it.

**Managed cloud database.** [Amazon RDS](https://aws.amazon.com/rds/) / Aurora, Google Cloud SQL, or Azure Database for PostgreSQL/MySQL give you backups, failover, patching, and monitoring without running a database on the cluster.

**On-cluster operator.** [CloudNativePG](https://cloudnative-pg.io/) runs PostgreSQL on Kubernetes with streaming replication, automated failover, scheduled backups, and point-in-time recovery, all driven by a `Cluster` custom resource. Operators such as the Percona or Bitnami charts offer similar capabilities for MySQL/PostgreSQL if you prefer to keep the database next to the workloads.

A common split is to give the Configuration Service and Message Monitor a shared PostgreSQL instance and James its own, but any topology your database platform supports works.

## What changes in the manifests

All values below live in each service's `<service>-config` `Secret`.

**Configuration Service** (reactive R2DBC):

| Key | Example |
|-----|---------|
| `spring.r2dbc.url` | `r2dbc:postgresql://pg.example:5432/nhindconfig` or `r2dbc:mysql://mysql.example:3306/nhindconfig` |
| `spring.r2dbc.username` / `spring.r2dbc.password` | database credentials |
| `spring.sql.init.platform` | `postgresql` or `mysql` — selects the matching bundled schema-generation script (default `h2`) |

**Message Monitor** (JDBC):

| Key | Example |
|-----|---------|
| `spring.datasource.url` | `jdbc:postgresql://pg.example:5432/msgmonitor` or `jdbc:mysql://mysql.example:3306/msgmonitor` |
| `spring.datasource.username` / `spring.datasource.password` | database credentials |
| `spring.datasource.driver-class-name` | `org.postgresql.Driver` or `com.mysql.cj.jdbc.Driver` |

**James** (JDBC, plus an OpenJPA adapter):

| Key | Example |
|-----|---------|
| `spring.datasource.url` | `jdbc:postgresql://pg.example:5432/james` or `jdbc:mysql://mysql.example:3306/james` |
| `spring.datasource.username` / `spring.datasource.password` | database credentials |
| `spring.datasource.driver-class-name` | `org.postgresql.Driver` or `com.mysql.cj.jdbc.Driver` |
| `spring.datasource.adapter` | `POSTGRESQL` or `MYSQL` — **must** match the target platform; James builds its JPA config from this and defaults to `DERBY` |

The PostgreSQL and MySQL JDBC drivers are already bundled in the service images, so no classpath changes are needed. See [Modify Service Default Configuration](service-configuration) and [Configuration and Message Monitor Storage](config-store) for the full property details.

Once a service is off its embedded database, you can remove its `PersistentVolumeClaim`, raise `replicas` above `1`, and switch `strategy` back to `RollingUpdate`. Keep the `rabbitmq-data` PVC and its `Recreate` strategy unless you have also moved the broker off-cluster ([RabbitMQ](cloud-native-kubernetes-rabbitmq)).
