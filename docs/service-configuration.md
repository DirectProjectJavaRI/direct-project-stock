---
title: Modify Service Default Configuration
---

# Modify Service Default Configuration

Each service ships with a default set of configuration values; however, you may want or need to override these settings to suit your deployment needs. For example, the configuration service and James use a local, file-based database with
default credentials. You'll likely want to use a "real" database running on a dedicated machine, such as MySQL or Postgres. The same goes for RabbitMQ, where you probably won't want to use the local RabbitMQ instance running
with the guest/guest credentials.

These are ordinary Spring Boot applications, so Spring supports [several ways](https://docs.spring.io/spring-boot/reference/features/external-config.html) to supply configuration. The property names and defaults below are the same for every deployment model; only the mechanism for applying an override differs:

* **[Machine Deployment (Fat Jars)](cloud-native-machine-deployment)** — place an `application.yml` (or `application.properties`) file in each service's directory, next to the jar/war.
* **[Kubernetes Deployment](cloud-native-kubernetes-deployment)** — supply values as environment variables or mounted `Secret`/`ConfigMap` entries on each Deployment.

The following tables list some of the common application settings that you may want to customize depending on your needs. Some of these properties are not defined in the micro-service's own `application.yml` — they're contributed by auto-configuration classes in
internal library JARs on the service's classpath, so they won't be visible just by looking at the jar's bundled config file.

## Configuration Service

| Name | Description | Default Value |
| :---         | :---           | :---          |
| `spring.r2dbc.*`                | Database connection configuration. See Spring [data properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.data) settings for full details. | url: `r2dbc:h2:file:///./embedded-db/nhindconfig;NON_KEYWORDS=VALUE;CASE_INSENSITIVE_IDENTIFIERS=TRUE`<br> username: `sa`<br>password: `""`  |
| `spring.sql.init.platform`      | Platform to use in the default schema generation script. Supported options are `h2`, `mysql`, and `postgresql`. | `h2`  |
| `spring.security.user.name`     | The basic auth username to access the configuration service API. | `admin`  |
| `spring.security.user.password` | The basic auth password to access the configuration service API. Stored in `application.yml` as a bcrypt hash (`{bcrypt}...`) — the value shown here is the decoded plaintext. | `d1r3ct;`  |
| `direct.trustbundles.refresh.period` | Interval, in milliseconds, at which a scheduled task checks all configured trust bundles for updates. | `3600000` |
| `direct.config.keystore.hsmpresent` | Enables HSM-backed (PKCS#11) protection for the keystore holding Direct signing/decryption certificates and keys. When `false`, the software passphrase settings below are used instead. | `false` |
| `direct.config.keystore.bootstrapmanager` | Enables the software "bootstrapped" keystore protection manager (used when no HSM is present) to protect/encrypt the keystore and private key passphrases. | `false` |
| `direct.config.keystore.keyStorePassPhrase` | Passphrase protecting the software (non-HSM) keystore holding Direct signing/decryption certificates and keys. **Change this for any real deployment.** | `H1TBr0s!` |
| `direct.config.keystore.privateKeyPassPhrase` | Passphrase protecting private keys in the software (non-HSM) keystore. **Change this for any real deployment.** | `H1TCh1ckS!` |
| `direct.config.keystore.initOnStart` | Whether to initialize the keystore/HSM token store on application startup. | `true` |
| `direct.config.keystore.{keyStorePin, keyStoreType, keyStoreSourceAsString, keyStoreProviderName, keyStorePassPhraseAlias, privateKeyPassPhraseAlias}` | Additional PKCS#11 HSM connection settings, only used when `hsmpresent=true`. | `som3randomp!n`<br>`Luna`<br>`slot:0`<br>`com.safenetinc.luna.provider.LunaProvider`<br>`keyStorePassPhrase`<br>`privateKeyPassPhrase` |

## Configuration UI

| Name | Description | Default Value |
| :---         | :---           | :---          |
| `direct.webservices.security.basic.user.name`     | Basic auth user name to access the configuration service API. | `admin` |
| `direct.webservices.security.basic.user.password` | Basic auth password to access the configuration service API. |`d1r3ct;` |
| `direct.webservices.connect.timeout`              | Connect timeout, in milliseconds, for the REST client used to call the configuration service API. | `5000` |
| `direct.webservices.response.timeout`             | Response/read timeout, in milliseconds, for the REST client used to call the configuration service API. | `10000` |
| `direct.config.service.url`                      | URL of the configuration service API. | `http://localhost:8082/` |
| `direct.configui.security.user.name`             | Username to log in to the configuration UI web application. | `admin` |
| `direct.configui.security.user.password`         | Password to log in to the configuration UI web application. | `direct` |
| `direct.config.keystore.hsmpresent` | Enables HSM-backed (PKCS#11) protection for the keystore holding Direct signing/decryption certificates and keys. When `false`, the software passphrase settings below are used instead. | `false` |
| `direct.config.keystore.keyStorePassPhrase` | Passphrase protecting the software (non-HSM) keystore holding Direct signing/decryption certificates and keys. **Change this for any real deployment.** | `H1TBr0s!` |
| `direct.config.keystore.privateKeyPassPhrase` | Passphrase protecting private keys in the software (non-HSM) keystore. **Change this for any real deployment.** | `H1TCh1ckS!` |
| `direct.config.keystore.initOnStart` | Whether to initialize the keystore/HSM token store on application startup. | `true` |
| `direct.config.keystore.{keyStorePin, keyStoreType, keyStoreSourceAsString, keyStoreProviderName, keyStorePassPhraseAlias, privateKeyPassPhraseAlias}` | Additional PKCS#11 HSM connection settings, only used when `hsmpresent=true`. | `som3randomp!n`<br>`Luna`<br>`slot:0`<br>`com.safenetinc.luna.provider.LunaProvider`<br>`keyStorePassPhrase`<br>`privateKeyPassPhrase` |

## DNS Service

| Name | Description | Default Value |
| :---         | :---           | :---          |
| `direct.webservices.security.basic.user.name`     | Basic auth user name to access the configuration service API. | `admin` |
| `direct.webservices.security.basic.user.password` | Basic auth password to access the configuration service API. | `d1r3ct;` |
| `direct.config.service.url`                       | URL of the configuration service API. | `http://localhost:8082/` |
| `direct.dns.binding.port`    | UDP/TCP port the DNS server listens on for incoming DNS queries. Port 53 is privileged on most systems — see the note in [Launch Microservices](cloud-native-machine-deployment#launch-microservices). | `53` |
| `direct.dns.binding.address` | Local IP address the DNS server binds to. By default it binds to all interfaces. | `0.0.0.0` |
| `direct.dns.binding.maxReconnectAttempts` | Number of times the server attempts to re-bind its listener socket after an I/O failure before giving up. | `10` |
| `direct.dns.certPolicyName`  | Name of a certificate policy (defined in the Configuration Service) used to filter CERT record query responses — typically used for single-use certificate deployments. When empty or unresolvable, no filtering is applied. | *(empty — no filtering)* |

## Message Monitor

| Name | Description | Default Value |
| :---         | :---           | :---          |
| `spring.datasource.*`                | Database connection configuration. See Spring [data properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.data) settings for full details. | url: `jdbc:derby:msgmonitor;create=true`<br> username: `nhind`<br>password: `nhind`  |
| `spring.rabbitmq.*`        | RabbitMQ connection properties. See Spring [integration properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.integration) settings for full details. | host: `localhost`<br>port: `5672`<br>username: `guest`<br>password: `guest` |
| `direct.msgmonitor.condition.generalConditionTimeout`  | Time in milliseconds the system will wait for MDN or DSN notification messages before generating an error message. | `3600000`  |
| `direct.msgmonitor.condition.reliableConditionTimeout`  | Time in milliseconds the system will wait for MDN or DNS notification messages before generating an error message when the original sender invokes the "implementation guide for delivery notification." | `3600000`  |
| `direct.msgmonitor.dupStateDAO.retensionTime`  | Time in days the tracking information will be stored in the system before being purged. | `7`  |
| `direct.msgmonitor.dsnSender.useStreamsSender` | When `true`, generated DSN/error notifications are published back into the message broker instead of being sent directly over SMTP. Mutually exclusive with `useSMTPGatewaySender`. | `true` |
| `direct.msgmonitor.dsnSender.useSMTPGatewaySender` | When `true`, generated DSN/error notifications are sent directly via SMTP to `dsnSender.gatewayURL` instead of the message broker. Mutually exclusive with `useStreamsSender`. | `false` |
| `direct.msgmonitor.dsnSender.gatewayURL` | SMTP gateway URL used to send DSNs when `useSMTPGatewaySender=true`. | `smtp://localhost:25` |
| `direct.msgmonitor.dsnGenerator.postmasterName` | "From" display name used as the postmaster identity when generating DSN error messages. | `postmaster` |
| `direct.msgmonitor.dsnGenerator.mtaName` | MTA name reported in generated DSNs. | `DirectProject Message Monitor` |
| `direct.msgmonitor.dsnGenerator.subjectPrefix` | Subject line prefix on generated DSN error messages. | `Not Delivered:` |
| `direct.msgmonitor.dsnGenerator.failedRecipientsTitle` | Body text introducing the list of recipients for whom no timely notification was received. | `We have not received a delivery notification in 1 hour for the following recipient(s) because the receiving system may be down or configured incorrectly:` |
| `direct.msgmonitor.dsnGenerator.errorMessageTitle` | Title/heading text prepended to the error message body. | *(empty)* |
| `direct.msgmonitor.dsnGenerator.defaultErrorMessage` | Default explanatory error text included in the generated DSN. | `<b>Your message most likely was not delivered.</b> Please confirm your recipient email addresses are correct. If the addresses are correct, consider a different communication method.<br/><br/>If you continue to receive this message, please have the recipient check with their system administrator and include the "Troubleshooting Information" below.` |
| `direct.msgmonitor.dsnGenerator.header` | Header template prepended to the DSN body. Supports `%original_sender_tag%` substitution. | `%original_sender_tag%,<br/>` |
| `direct.msgmonitor.dsnGenerator.footer` | Footer template appended to the DSN body. Supports `%headers_tag%` substitution. | `<b><u>Troubleshooting Information</u></b><br/><br/>%headers_tag%` |
| `direct.msgmonitor.recovery.retryInterval` | Milliseconds between recovery attempts for the message aggregation repository after a failure. | `30000` |
| `direct.msgmonitor.recovery.maxRetryAttemps` | Maximum redelivery attempts for aggregation repository recovery. (This is the actual property name in code, including the missing "t" in "Attempts".) | `12` |
| `direct.msgmonitor.recovery.deadLetterUri` | Dead-letter destination for aggregation entries that exhaust recovery retries. | `file:recovery/directMonitorDeadLetter` |
| `monitor.aggregatorRepository.recoveryLockInterval` | Seconds an in-recovery aggregation entry is locked before being eligible for another recovery attempt. (Note: this property uses the `monitor.*` prefix rather than `direct.msgmonitor.*`.) | `120` |

## SMTP/MQ Gateway

| Name | Description | Default Value |
| :---         | :---           | :---          |
| `spring.rabbitmq.*`                 | RabbitMQ connection properties. See Spring [integration properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.integration) settings for full details. | host: `localhost`<br>port: `5672`<br>username: `guest`<br>password: `guest` |
| `direct.smtpmqgateway.binding.port` | The port that the server will listen on for incoming SMTP traffic. If you intend to make this server your primary SMTP interface to the internet, you should change this value to `25`. | `1025` |
| `direct.smtpmqgateway.binding.host` | The local IP address that this server will bind to. By default, it will bind to all addresses. | `0.0.0.0` |
| `direct.smtpmqgateway.message.maxHeaderSize` | The maximum size in bytes that the MIME header may be in incoming messages. | `262144` |
| `direct.smtpmqgateway.message.maxMessageSize` | The maximum size in bytes allowed for incoming messages. | `39845888` |
| `direct.smtpmqgateway.clientwhitelist.cidr` | Comma-separated list of CIDR blocks allowed to open SMTP connections to the listener. When unset, all client IPs are accepted. | *(empty — no restriction)* |

## Security and Trust Agent

| Name | Description | Default Value |
| :---         | :---           | :---          |
| `spring.rabbitmq.*`                 | RabbitMQ connection properties. See Spring [integration properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.integration) settings for full details. | host: `localhost`<br>port: `5672`<br>username: `guest`<br>password: `guest` |
| `direct.webservices.security.basic.user.name`     | Basic auth user name to access the configuration service API. | `admin` |
| `direct.webservices.security.basic.user.password` | Basic auth password to access the configuration service API. |`d1r3ct;` |
| `direct.config.service.url`                      | URL of the configuration service API. | `http://localhost:8082/` |
| `direct.msgmonitor.service.url` | URL of the Message Monitor service, used to report and track tx/notification status. | `http://localhost:8081/` |
| `direct.gateway.xd.enabled` | Master switch for XD routing. When `false`, all incoming mail is routed to last-mile delivery (James) regardless of the recipient address's endpoint type. | `true` |
| `direct.gateway.postprocess.routeLocalRecipientToGateway` | For outgoing (encrypted) mail whose recipients are also local domains, loop the message directly back into the gateway ingest stream instead of the remote-delivery/SMTP-relay path. | `true` |
| `direct.gateway.postprocess.ConsumeMDNProcessed` | Suppress an incoming MDN with disposition `processed` instead of forwarding it on to last-mile delivery. | `true` |
| `direct.gateway.remotedelivery.gateway.name` | Comma-separated explicit outbound SMTP relay host(s) for remote delivery. When set, bypasses DNS MX lookup entirely. | *(empty — falls back to DNS MX lookup)* |
| `direct.gateway.remotedelivery.gateway.port` | Port for the explicit outbound SMTP relay host(s) above. | *(empty)* |
| `direct.gateway.remotedelivery.gateway.username` | Username for authenticating to the outbound SMTP relay. | *(empty — no auth)* |
| `direct.gateway.remotedelivery.gateway.password` | Password for outbound SMTP relay authentication. | *(empty)* |
| `direct.gateway.remotedelivery.gateway.connectionTimeout` | SMTP connection timeout, in milliseconds, for outbound relay delivery. | *(empty — JavaMail default)* |
| `direct.gateway.remotedelivery.gateway.supressLocalDomains` | Skip remote delivery when the recipient's domain is local (the post-processor already routes those back into the gateway). | `true` |
| `direct.gateway.remotedelivery.dns.lookup.timeout` | DNS resolver timeout, in seconds, for MX/A record lookups during outbound remote delivery. | `3` |
| `direct.gateway.remotedelivery.dns.lookup.retries` | DNS resolver retry count for the same lookups. | `2` |
| `direct.gateway.remotedelivery.dns.servers` | Comma-separated DNS server list used for outbound remote-delivery MX/A lookups. | *(empty — OS resolver config)* |
| `direct.gateway.certificates.dns.servers` | Comma-separated DNS server list used for DNS-based certificate discovery (separate from the remote-delivery resolver above). | *(empty — OS resolver config)* |
| `direct.gateway.agent.useOutgoingPolicyForIncomingNotifications` | Whether outgoing trust/security policy is also applied to incoming MDN/notification messages. | `true` |
| `direct.gateway.agent.rejectOnTamper` | Reject messages whose routing headers appear tampered with, rather than only logging. | `false` |
| `direct.gateway.agent.jceProviderName` | Explicit JCE provider name for the agent's signing/encryption/decryption operations. | *(empty — platform default)* |
| `direct.gateway.agent.jceSensitiveProviderName` | Explicit JCE provider name for sensitive crypto operations. | *(empty — platform default)* |
| `direct.xd.documents.syntheticdata.classCode` | Synthetic XDS `classCode` applied when a source document/CDA omits it during XD step processing. | `34133-9` |
| `direct.xd.documents.syntheticdata.confidentialityCode` | Synthetic XDS `confidentialityCode` default. | `N` |
| `direct.xd.documents.syntheticdata.healthcareFacilityTypeCode` | Synthetic XDS `healthcareFacilityTypeCode` default. | `Outpatient` |
| `direct.xd.documents.syntheticdata.practiceSettingCode` | Synthetic XDS `practiceSettingCode` default. | `General Medicine` |
| `direct.gateway.keystore.hsmpresent` | Enables HSM-backed (PKCS#11) protection for the STA's signing/decryption keystore. When `false`, the software passphrase settings below are used instead. | `false` |
| `direct.gateway.keystore.keyStorePassPhrase` | Passphrase protecting the software (non-HSM) keystore holding the STA's signing/decryption certificates and keys. **Change this for any real deployment.** | `H1TBr0s!` |
| `direct.gateway.keystore.privateKeyPassPhrase` | Passphrase protecting private keys in the software (non-HSM) keystore. **Change this for any real deployment.** | `H1TCh1ckS!` |
| `direct.gateway.keystore.initOnStart` | Whether to initialize the keystore/HSM token store on application startup. | `true` |
| `direct.gateway.keystore.{keyStorePin, keyStoreType, keyStoreSourceAsString, keyStoreProviderName, keyStorePassPhraseAlias, privateKeyPassPhraseAlias}` | Additional PKCS#11 HSM connection settings, only used when `hsmpresent=true`. | `som3randomp!n`<br>`Luna`<br>`slot:0`<br>`com.safenetinc.luna.provider.LunaProvider`<br>`keyStorePassPhrase`<br>`privateKeyPassPhrase` |

## James

| Name | Description | Default Value |
| :---         | :---           | :---          |
| `spring.datasource.*`          | Database connection settings, read via this module's own `@Value` bindings (not Spring Boot's standard JPA/datasource auto-configuration) to generate James's JPA config at startup: `url`, `username`, `password`, `driver-class-name`, `adapter`, `streaming`. | url: `jdbc:derby:./var/store/derby;create=true`<br> username: `app`<br>password: `app`<br>driver-class-name: `org.apache.derby.jdbc.EmbeddedDriver`<br>adapter: `DERBY`<br>streaming: `false`  |
| `spring.datasource.adapter`    | The OpenJPA vendor adapter identifying the database platform, used to generate the correct SQL dialect for James's JPA-backed mailbox/user stores. This must match the database platform targeted by `spring.datasource.url` and `spring.datasource.driver-class-name` — for example, if the URL/driver point at a PostgreSQL database, `adapter` must be set to `POSTGRESQL`, not left at the `DERBY` default. Acceptable values: `DB2`, `DERBY`, `H2`, `HSQL`, `INFORMIX`, `MYSQL`, `ORACLE`, `POSTGRESQL`, `SQL_SERVER`, `SYBASE`. | `DERBY` |
| `spring.rabbitmq.*`        | RabbitMQ connection properties. See Spring [integration properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.integration) settings for full details. | host: `localhost`<br>port: `5672`<br>username: `guest`<br>password: `guest` |
| `direct.webservices.security.basic.user.name`     | Basic auth user name to access the configuration service API. | `admin` |
| `direct.webservices.security.basic.user.password` | Basic auth password to access the configuration service API. |`d1r3ct;` |
| `direct.webservices.connect.timeout`              | Connect timeout, in milliseconds, for the REST client used to call the configuration service API. | `5000` |
| `direct.webservices.response.timeout`             | Response/read timeout, in milliseconds, for the REST client used to call the configuration service API. | `10000` |
| `direct.config.service.url`                      | URL of the configuration service API. | `http://localhost:8082/` |
| `direct.james.notifications.suppressNotificationsForAddresses` | Comma-separated recipient addresses for which MDN "dispatched" notifications and DSN bounce notifications are never generated. | *(empty — none suppressed)* |
| `direct.james.notifications.dispatchedMDNDelay` | Delay, in milliseconds, before a "dispatched" MDN is released to the outbound stream for recipients listed in `delayedDispatchMDNAddresses`. Can be overridden per-message via the `X-Delay-Dispatched-MDN` mail header (value in minutes). | *(empty — no delay)* |
| `direct.james.notifications.delayedDispatchMDNAddresses` | Comma-separated addresses (matched against the generated notification's `From`) whose "dispatched" MDN is delayed rather than sent immediately. | *(empty — none delayed)* |
| `james.server.webadmin.enabled`                  | Enables the James web admin API. | `true` |
| `james.server.webadmin.username`                 | Basic auth user name to access the James web admin API. | `admin` |
| `james.server.webadmin.password`                 | Basic auth password to access the James web admin API. | `d1r3ct` |
| `james.server.webadmin.port`                     | The HTTP port to access the James web admin API. | `8084` |
| `james.server.smtp.autoAddresses` | Comma-separated IP/CIDR addresses permitted to relay through the SMTP protocol without authentication. | *(empty)* |
| `james.server.config.mailet.configFile` | Path to an external `mailetcontainer.xml` to use in place of the bundled default mailet/processor pipeline config. | *(empty — uses bundled config)* |
| `james.server.config.imap.configFile` | Path to an external `imapserver.xml` to use in place of the bundled default. | *(empty — uses bundled config)* |
| `james.server.config.pop3.configFile` | Path to an external `pop3server.xml` to use in place of the bundled default. | *(empty — uses bundled config)* |
| `james.server.config.smtp.configFile` | Path to an external `smtpserver.xml` to use in place of the bundled default. | *(empty — uses bundled config)* |
| `james.server.imap.bind`                         | The local IP address that this server will bind to for the IMAP protocol. By default, it will bind to all addresses. | `0.0.0.0` |
| `james.server.imap.port`                         | The HTTP port that the IMAP protocol will listen on for incoming connections. | `1143` |
| `james.server.imap.sockettls`                    | Indicates if the initial IMAP connection is done over TLS. | `false` |
| `james.server.imap.starttls`                     | Indicates if the IMAP protocol supports the upgrade option to TLS. | `true` |
| `james.server.imap.imapKeyStore`                 | The key store file used for the IMAP TLS connection. | `/properties/keystore` |
| `james.server.imap.imapKeyStorePassword`         | The password for the IMAP key store file. | `1kingpuff` |
| `james.server.pop3.bind`                         | The local IP address that this server will bind to for the POP3 protocol. By default, it will bind to all addresses. | `0.0.0.0` |
| `james.server.pop3.port`                         | The HTTP port that the POP3 protocol will listen on for incoming connections. | `1110` |
| `james.server.pop3.sockettls`                    | Indicates if the initial POP3 connection is done over TLS. | `false` |
| `james.server.pop3.starttls`                     | Indicates if the POP3 protocol supports the upgrade option to TLS. | `true` |
| `james.server.pop3.imapKeyStore`                 | The key store file used for the POP3 TLS connection. | `/properties/keystore` |
| `james.server.pop3.imapKeyStorePassword`         | The password for the POP3 key store file. | `1kingpuff` |
| `james.server.smtp.bind`                         | The local IP address that this server will bind to for the SMTP protocol. By default, it will bind to all addresses. | `0.0.0.0` |
| `james.server.smtp.port`                         | The HTTP port that the SMTP protocol will listen on for incoming connections. | `1587` |
| `james.server.smtp.sockettls`                    | Indicates if the initial SMTP connection is done over TLS. | `false` |
| `james.server.smtp.starttls`                     | Indicates if the SMTP protocol supports the upgrade option to TLS. | `true` |
| `james.server.smtp.imapKeyStore`                 | The key store file used for the SMTP TLS connection. | `/properties/keystore` |
| `james.server.smtp.imapKeyStorePassword`         | The password for the SMTP key store file. | `1kingpuff` |

## XD

| Name | Description | Default Value |
| :---         | :---           | :---          |
| `spring.rabbitmq.*`        | RabbitMQ connection properties. See Spring [integration properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.integration) settings for full details. | host: `localhost`<br>port: `5672`<br>username: `guest`<br>password: `guest` |
| `server.servlet.context-path`         | The application context path for HTTP requests. | `/xd` |
| `direct.webservices.security.basic.user.name`     | Basic auth user name to access the configuration service API. You will need to set this value. | *(none)* |
| `direct.webservices.security.basic.user.password` | Basic auth password to access the configuration service API. You will need to set this value. | *(none)* |
| `direct.webservices.connect.timeout`              | Connect timeout, in milliseconds, for the REST client used to call the configuration service API. | `5000` |
| `direct.webservices.response.timeout`             | Response/read timeout, in milliseconds, for the REST client used to call the configuration service API. | `10000` |
| `direct.config.service.url`                      | URL of the configuration service API. | `http://localhost:8082` |
| `direct.xd.usestreams` | When `true`, accepted XDR document sets that need to be forwarded to SMTP recipients are sent via the message broker instead of a direct SMTP send. | `true` |
