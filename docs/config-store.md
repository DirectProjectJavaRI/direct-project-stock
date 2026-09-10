---
title: Configuration, Message Monitor, and Mail Storage
---

# Configuration, Message Monitor, and Mail Storage

By default, the services that make up a Health Information Service Provider (HISP) persist their state using an embedded, file-based database — Derby or H2 in the Cloud Native deployment model, and Derby in the Legacy deployment model (Reference Implementation, or RI, 8.1.x and previous). Although this simplifies an out-of-the-box deployment, it has several disadvantages:

* It only allows one process to access it at any given time, limiting the ability to run multiple instances of a service for high availability and load balancing.
* Unless mounted on a network share, it is only available on the local machine.
* It is not redundant and provides no failover options.

These are only a small collection of issues, and it becomes obvious that an enterprise/distributed database solution is needed for a robust production deployment.

How you migrate a service off its embedded database differs between the two deployment models, and — for Apache James specifically — differs again from every other service in the system, in both deployment models. This document is organized by deployment model to keep the two configuration mechanisms separate.

## Cloud Native Deployment Model

The [Cloud Native deployment model](cloud-native-deployment) — the only supported model starting with RI 9.0 — runs the configuration service, message monitor, and James as a set of independent Spring Boot micro-services. Each service manages its own datasource configuration independently; there is no shared bootstrap.properties file, and settings are overridden per service (see [Modify Service Default Configuration](service-configuration)).

### Configuration Service and Message Monitor

The Configuration Service and Message Monitor are standard Spring Boot applications, so their persistence is fully wired into Spring's own datasource/JPA auto-configuration:

* **Configuration Service** connects via reactive `spring.r2dbc.*` properties, defaulting to an embedded, file-based H2 database. Set `spring.sql.init.platform` to `mysql` or `postgresql` to match the bundled schema-generation script to your target database. See the [Configuration Service settings table](service-configuration#configuration-service) for the full list of properties.
* **Message Monitor** connects via standard `spring.datasource.*` properties, defaulting to an embedded Derby database. See the [Message Monitor settings table](service-configuration#message-monitor) for the full list of properties.

After migrating to a distributed data source, it is recommended that you run multiple instances of each service behind a load balancer for high availability.

### James Mail and User Storage

In the Cloud Native deployment model, James is repackaged as its own Spring Boot fat jar and stores both mail (mailboxes/message content) and user/domain data in the same embedded database. However, even though James now ships as a Spring Boot jar, its persistence layer is still **not** wired into Spring Boot's standard datasource/JPA auto-configuration. Instead, James reads a small, fixed set of `spring.datasource.*` values via its own `@Value` bindings and uses them to build its JPA configuration at startup: `url`, `username`, `password`, `driver-class-name`, `adapter`, and `streaming`. See the [James settings table](service-configuration#james) for the default values of each.

Setting `spring.datasource.url`, `username`, `password`, and `driver-class-name` to point at a PostgreSQL or MySQL instance, along with the matching `spring.datasource.adapter` value (e.g. `POSTGRESQL` or `MYSQL`), is enough for James to connect. However, because James does not go through Spring's own Java Persistence API (JPA)/Hibernate auto-configuration, it does not get the automatic schema generation that the Configuration Service gets from `spring.sql.init.platform`. You are responsible for provisioning the schema James's JPA layer expects for the chosen adapter. If you need to go beyond what the `spring.datasource.*` overrides expose — for example, JPA/OpenJPA-level tuning — you'll need to supply your own James configuration files rather than relying on Spring configuration; this is James-specific behavior that the Direct reference implementation does not control.

Consult the Apache James project's own documentation if you need configuration beyond what's described above.

## Legacy Deployment Model (RI 8.1.x and Previous)

The Legacy deployment model (RI 8.1.x and previous) runs the configuration service and message monitor as web applications inside Apache Tomcat, with Apache James (`james-jpa-guice`) running as its own, separate process. See the [Legacy Deployment](legacy-deployment) document for full deployment steps.

### Configuration Service and Message Monitor

The configuration and message monitoring services' database configuration is held in a file named *bootstrap.properties* under the `<tomcat home>/webapps/<app name>/WEB-INF/classes` directory. They use the standard Spring datasource properties. To connect to a different database, update these properties with settings appropriate to your target database:

* spring.datasource.url=
* spring.datasource.username=
* spring.datasource.password=

Additional settings are documented in Spring [appendix A](https://docs.spring.io/spring-boot/docs/current/reference/html/common-application-properties.html) under the DATASOURCE section.

Other databases, such as Oracle, allow for finer-grained tuning via properties; consult your database vendor for more information.

After you migrate the services to your new distributed data source, we recommend deploying multiple instances of the Tomcat server behind a fault-tolerant, load-balanced configuration (instructions are beyond the scope of this document).

### Apache James Mail Storage

Unlike the configuration and message monitor services, the legacy Apache James server (`james-jpa-guice`) is not a Spring application — it is wired together with Guice and persists mail and user/domain data through its own JPA (OpenJPA) layer. None of the `spring.datasource.*` properties above apply to James, and there is no bootstrap.properties file to edit.

By default, James stores everything — mailboxes, message content, and the user/domain repository — in an embedded Derby database under the `james-jpa-guice-3.2.0` install directory. To point James at a different database (such as PostgreSQL or MySQL), you cannot simply override a handful of properties; James requires you to supply your own JPA persistence configuration:

* Create/replace James's own JPA/persistence configuration files under `$DIRECT_HOME/james-jpa-guice-3.2.0/conf` with the JDBC driver class, connection URL, credentials, and dialect for your target database.
* Copy the target database's JDBC driver JAR into `$DIRECT_HOME/james-jpa-guice-3.2.0/james-server-jpa-guice.lib` (the same directory referenced for PKCS11 provider JARs in the [Enhanced Private Key Security](enhanced-key-security) document) so it is on James's classpath.
* Provision the schema James expects for your chosen dialect yourself — James's JPA layer does not run the kind of automatic schema-initialization that the Spring-based configuration and message monitor services do.

Because this configuration is internal to Apache James rather than something the Direct reference implementation controls, consult the Apache James project's own documentation for the specifics of JPA/OpenJPA database configuration that apply to the James version (3.2.0) bundled with the Legacy assembly.
