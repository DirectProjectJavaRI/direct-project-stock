---
title: Cloud Native HISP Deployment Model
---

# Cloud Native HISP Deployment Model

The cloud native Health Information Service Provider (HISP) deployment model consists of smaller individual processes (i.e., micro-services) performing specific functional tasks and exposing APIs
either via REST or asynchronous messaging interfaces. Generally, the REST interfaces are used to retrieve and maintain the system's configuration
data, while the messaging interfaces are used to move Direct messages from one processing step to another using a streaming/pipelining paradigm.

Each micro-service is a discrete Spring Boot fat jar application and can be deployed on multiple platforms, ranging from bare metal systems to highly
managed cloud provider runtimes such as Google Cloud Run. This document provides details on how to launch each micro-service as a stand-alone Java process;
however, each micro-service can be deployed using any number of options, such as Docker, Cloud Foundry, Kubernetes, or Google Cloud Run. Instructions
for each targeted platform are out of scope for this document, as they may incur additional platform-specific steps such as containerization.

In addition, this deployment model uses asynchronous messaging to dispatch Direct messages from one processing stage to the next. The deployment requires
a messaging system such as RabbitMQ or Kafka (the default deployment model uses RabbitMQ).

The following is the list of micro-services making up the core of the reference implementation deployment:

* Configuration Service
* Configuration UI
* DNS Service
* Message Monitor
* SMTP/MQ Gateway
* Security and Trust Agent
* Apache James (for message sending/retrieving and last-mile delivery only)
* XD

## Topology Overview

The following diagram illustrates the micro-services in the cloud native deployment model, the network zones they sit in, and how they communicate
with each other. Every connection that runs over the RabbitMQ message broker is labeled with the actual queue/topic (destination) name each
service is configured to use in its `application.yml`, so it's clear which service publishes to which queue and which service consumes it. For
simplicity, the database backing each service has been omitted from the diagram, as is the DNS Service, which reads its records from the Configuration Service's REST API and does not participate in the message broker pipeline.

![Topology diagram of the Cloud Native HISP deployment, showing the Public Network, Internal HISP Network, and HISP Consumer Network zones, the micro-services within them, the labeled RabbitMQ queues/topics connecting them, and the outbound SMTP and XDR flows from the STA](assets/directRICloudNativeOverview.svg)

The STA sits at the center of the messaging pipeline: `direct-smtp-mq-gateway` is the single entry point into the STA, fed by the SMTP/MQ Gateway
(external inbound SMTP), XD (EHR-submitted outbound messages), and James (generated MDN/DSN messages re-entering the pipeline). From there the STA
routes a message to one of three places: `direct-sta-last-mile-delivery` to James for mailbox delivery, `direct-remote-delivery-process` for
outbound SMTP relay to a remote HISP on the public network, or `direct-xd-delivery-process` for an outbound HTTP(S) XDR push to an EHR edge system's
XDR document recipient. The STA reports tx/notification status to Message Monitor via a direct REST call to the Message Monitor service, rather than over the message broker. Because James's generated MDN/DSN messages re-enter the pipeline through the STA's
entry point, their status is captured through this same reporting path.

One thing worth noting early on: unlike the legacy deployment model, the cloud native model uses two different SMTP servers — an externally facing server for
receiving messages from other HISPs, and an internal server for last-mile delivery, message storage at rest, and sending outbound messages.

## Micro-Services List

The following list outlines each micro-service, the jar file that comprises it (each is a single Spring Boot fat jar), and a description of what it does.

| Service | Jar File | Description |
| :---         | :---           | :---          |
| Config Service    | [config-service.jar](https://repo.maven.apache.org/maven2/org/nhind/config-service/9.0.0/config-service-9.0.0.jar) | Holds the configuration service for the HISP, such as domains, DNS entries, trust bundles, and certificates. |
| Config UI         | [config-ui.war](https://repo.maven.apache.org/maven2/org/nhind/config-ui/9.0.0/config-ui-9.0.0.war) | Front-end web UI application to configure the HISP, including domains, DNS entries, trust bundles, and certificates. |
| DNS Service       | [dns-sboot-9.0.0.jar](https://repo.maven.apache.org/maven2/org/nhind/dns-sboot/9.0.0/dns-sboot-9.0.0.jar) | Authoritative-only DNS server that answers DNS queries — most importantly CERT record queries used for Direct certificate discovery — from the DNS and certificate records held in the Configuration Service. Reads records from the Configuration Service REST API; it does not use the message broker. |
| Message Monitor   | [direct-msg-monitor-sboot.jar](https://repo.maven.apache.org/maven2/org/nhind/direct-msg-monitor-sboot/9.0.0/direct-msg-monitor-sboot-9.0.0.jar) | Tracks the status of Direct message notifications and generates error messages if required notifications are not received. Notification statuses are sent from other micro-services (STA and James) via the message broker (e.g., RabbitMQ). |
| SMTP/MQ Gateway   | [direct-smtp-mq-gateway.jar](https://repo.maven.apache.org/maven2/org/nhind/direct-smtp-mq-gateway/9.0.0/direct-smtp-mq-gateway-9.0.0.jar) | Externally facing SMTP server intended to receive Direct messages from external HISPs. It forwards Direct messages into the message processing stream via the system's message broker. **NOTE:** This SMTP server does not provide commercial capabilities such as anti-spam filters or malware detection. If you need those capabilities to control incoming messages, consider fronting this SMTP server with a commercial one. |
| Security and Trust Agent | [direct-sta-sboot.jar](https://repo.maven.apache.org/maven2/org/nhind/direct-sta-sboot/9.0.0/direct-sta-sboot-9.0.0.jar) | Executes the main security and trust agent logic as defined by the Direct specification. Also handles XD step processing and forwards processed messages to either external HISPs or an internal final destination, depending on the sender and receiver of the messages. Internal final destinations are either the James server application or XD endpoints. |
| Apache James      | [direct-james-server](https://repo.maven.apache.org/maven2/org/nhind/direct-james-server/9.0.0/direct-james-server-9.0.0.jar) | Mail server for HISP end users. It allows end users to send and receive messages using mail clients, meaning it is a final destination for incoming Direct messages. It also handles sending MDN-dispatched messages when requested by the original sender. Outgoing and incoming messages are sent to and from the STA via the message broker. |
| XD                | [xd.war](https://repo.maven.apache.org/maven2/org/nhind/xd/9.0.0/xd-9.0.0.war) | Implements an XD endpoint for the purpose of end users sending outgoing messages using the XDR protocol. Outgoing and incoming messages are sent to and from the STA via the message broker. |

## Deploying RabbitMQ

The cloud native deployment implements an asynchronous messaging paradigm to move messages from one micro-service to the next, which requires the introduction of a message broker. The default broker used by the reference implementation is RabbitMQ.

RabbitMQ can be deployed several ways, from multiple sources, using both commercial and open-source offerings. The RabbitMQ documentation provides good [instructions](https://www.rabbitmq.com/docs/download#open-source-rabbitmq-server)
for installing a variety of options. For simplicity, one easy option is to deploy RabbitMQ using a Docker container with the following command:

```
docker run -d --rm --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:4-management
```

This runs RabbitMQ with both the broker and management components, using a username/password of guest/guest (the default credentials used by the Direct micro-services). The `-d` flag runs the container in the background (detached) rather than tying up your terminal in the foreground.

## Download Micro-service Binaries

The deployment in this documentation will download each micro-service jar/war file from Maven and place each in its own directory. You will effectively just be running the micro-services as simple Java applications on a bare metal machine.

Obtain each jar/war file from Maven and place each into its own directory on your target machine. The table below lists each micro-service, along with a link to the jar/war file and a suggested directory name for the service.

| Service | Jar File | Directory |
| :---         | :---           | :---          |
| Config Service    | [config-service.jar](https://repo.maven.apache.org/maven2/org/nhind/config-service/9.0.0/config-service-9.0.0.jar) | `config-service`  |
| Config UI         | [config-ui.war](https://repo.maven.apache.org/maven2/org/nhind/config-ui/9.0.0/config-ui-9.0.0.war) | `config-ui`  |
| DNS Service       | [dns-sboot-9.0.0.jar](https://repo.maven.apache.org/maven2/org/nhind/dns-sboot/9.0.0/dns-sboot-9.0.0.jar) | `dns` |
| Message Monitor   | [direct-msg-monitor-sboot.jar](https://repo.maven.apache.org/maven2/org/nhind/direct-msg-monitor-sboot/9.0.0/direct-msg-monitor-sboot-9.0.0.jar) | `message-monitor` |
| SMTP/MQ Gateway   | [direct-smtp-mq-gateway.jar](https://repo.maven.apache.org/maven2/org/nhind/direct-smtp-mq-gateway/9.0.0/direct-smtp-mq-gateway-9.0.0.jar) | `smtp-gateway`  |
| Security and Trust Agent | [direct-sta-sboot.jar](https://repo.maven.apache.org/maven2/org/nhind/direct-sta-sboot/9.0.0/direct-sta-sboot-9.0.0.jar) | `sta` |
| James             | [direct-james-server](https://repo.maven.apache.org/maven2/org/nhind/direct-james-server/9.0.0/direct-james-server-9.0.0.jar) | `james` |
| XD                | [xd.war](https://repo.maven.apache.org/maven2/org/nhind/xd/9.0.0/xd-9.0.0.war) | `xd` |

## Launch Microservices

You can technically launch each micro-service using a simple `java -jar` command, but this isn't recommended. Instead, use the following scripts: copy the appropriate template to each micro-service's directory
and replace the `<binary>` placeholder with the name of the jar/war file in that directory. We suggest naming the file `service.sh` (Unix/Linux/macOS) or `service.ps1` (Windows), though you can name it whatever you like. The rest of
this section assumes you used those names. You will also need to create a `conf` directory in each micro-service directory and add a `logback.xml` file. The suggested contents of each file are shown below. All three files are generic —
the only per-service edit required is the `<binary>` placeholder.

* Unix/Linux/macOS (service.sh)
```sh
#!/bin/sh
cd "$(dirname "$0")"
mkdir -p ./logs

case "$1" in
    start)
        if [ -f ./pid ] && kill -0 "$(cat ./pid)" 2>/dev/null; then
            echo "Service is already running (pid $(cat ./pid))"
            exit 1
        fi
        echo "Starting Service"
        nohup java -Dworking.directory=. -Dlogging.config=file:conf/logback.xml -jar <binary> > ./logs/console.out 2>&1 &
        echo $! > ./pid
        echo "."
        ;;
    stop)
        if [ ! -f ./pid ]; then
            echo "Service is not running"
            exit 1
        fi
        echo "Stopping Service"
        PID=$(cat ./pid)
        kill "$PID"
        while kill -0 "$PID" 2>/dev/null; do
            sleep 1
        done
        rm -f ./pid
        echo "."
        ;;
    restart)
        "$0" stop
        "$0" start
        ;;
    status)
        if [ -f ./pid ] && kill -0 "$(cat ./pid)" 2>/dev/null; then
            echo "Service is running (pid $(cat ./pid))"
        else
            echo "Service is not running"
        fi
        ;;
    console)
        echo "Starting Service"
        java -Dworking.directory=. -Dlogging.config=file:conf/logback.xml -jar <binary>
        ;;
    *)
        echo "Usage: service start|stop|restart|status|console"
        exit 1
        ;;
esac
```

* Windows (service.ps1)
```powershell
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("start", "stop", "restart", "status", "console")]
    [string]$Action
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir
New-Item -ItemType Directory -Force -Path ".\logs" | Out-Null

$PidFile = ".\pid"
$JavaArgs = @("-Dworking.directory=.", "-Dlogging.config=file:conf/logback.xml", "-jar", "<binary>")

function Get-RunningProcess {
    if (Test-Path $PidFile) {
        $procId = Get-Content $PidFile
        return Get-Process -Id $procId -ErrorAction SilentlyContinue
    }
    return $null
}

switch ($Action) {
    "start" {
        $existing = Get-RunningProcess
        if ($existing) {
            Write-Host "Service is already running (pid $($existing.Id))"
            exit 1
        }
        Write-Host "Starting Service"
        $proc = Start-Process -FilePath "java" -ArgumentList $JavaArgs `
            -RedirectStandardOutput ".\logs\console.out" -RedirectStandardError ".\logs\console.err" `
            -WindowStyle Hidden -PassThru
        $proc.Id | Out-File -FilePath $PidFile -Encoding ascii
        Write-Host "."
    }
    "stop" {
        $proc = Get-RunningProcess
        if (-not $proc) {
            Write-Host "Service is not running"
            exit 1
        }
        Write-Host "Stopping Service"
        Stop-Process -Id $proc.Id
        $proc.WaitForExit()
        Remove-Item $PidFile -ErrorAction SilentlyContinue
        Write-Host "."
    }
    "restart" {
        & $PSCommandPath stop
        & $PSCommandPath start
    }
    "status" {
        $proc = Get-RunningProcess
        if ($proc) { Write-Host "Service is running (pid $($proc.Id))" }
        else { Write-Host "Service is not running" }
    }
    "console" {
        Write-Host "Starting Service"
        & java @JavaArgs
    }
}
```

Run it as `.\service.ps1 start` (and `stop`/`restart`/`status`/`console` the same way) from an elevated or regular PowerShell prompt. This gives Windows the same start/stop/restart/status/console behavior as the Linux script. If your system's execution policy blocks running the script (common for scripts downloaded from the internet), either run
`Unblock-File .\service.ps1` once, or invoke it as `powershell -ExecutionPolicy Bypass -File .\service.ps1 start`. For a production Windows deployment 
where you want the service to auto-start on boot and be manageable from the
Services console, consider wrapping `java -jar <binary> ...` with a tool such as [NSSM](https://nssm.cc/) instead.

* logback.xml
```
<?xml version="1.0" encoding="UTF-8"?>
<configuration>

        <contextListener class="ch.qos.logback.classic.jul.LevelChangePropagator">
                <resetJUL>true</resetJUL>
        </contextListener>

	    <!--  Appenders for console and logs -->

        <appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
                <encoder>
                        <pattern>%d{HH:mm:ss.SSS} %highlight([%-5level]) %logger{15} - %msg%n%rEx</pattern>
                </encoder>
        </appender>

        <appender name="LOG_FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
                <file>./logs/service.log</file>
                <encoder>
                        <pattern>%d{HH:mm:ss.SSS} [%-5level] %logger{15} - %msg%n%rEx</pattern>
                </encoder>

                <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">       
                   <fileNamePattern>./logs/service.%d{yyyy-MM-dd}.log</fileNamePattern>
                   <maxHistory>30</maxHistory>
                   <totalSizeCap>1GB</totalSizeCap>
                </rollingPolicy>
        </appender>


        <root level="INFO">
                <appender-ref ref="CONSOLE" />
                <appender-ref ref="LOG_FILE"/>
        </root>

</configuration>
```


Finally, launch each micro-service. The order mostly doesn't matter, except that `config-service` must be running first. To start the services, run `./service.sh start` (Unix) or `.\service.ps1 start` (Windows) from
each directory. If you need to debug the output interactively, you can run `./service.sh console` or `.\service.ps1 console` to see the logs in your terminal (instead of only seeing them in the log file). To stop the service, simply run
`./service.sh stop` / `.\service.ps1 stop`, or press `CTRL+C` if running interactively.

Once the services are up and running, you can perform a preliminary test to confirm the system is working by accessing the Config UI at `http://<server IP>:8080/`.

Two of the services default to binding a well-known low port and will likely need adjustment for a real deployment. The DNS Service listens on UDP/TCP port `53`, and the SMTP/MQ Gateway defaults to port `1025` but will normally need to run on port `25` when it is exposed directly to the internet as the HISP's primary path for receiving messages from other HISPs. Both `53` and `25` are privileged ports on most operating systems, so for each service either start it with sufficient privileges to bind low ports (run as `root`, or grant the Java executable the `CAP_NET_BIND_SERVICE` capability on Linux), or set its binding port property (`direct.dns.binding.port` / `direct.smtpmqgateway.binding.port`) to a non-privileged port and forward the well-known port to it.

The DNS records the DNS Service serves are managed through the Config UI and Configuration Manager, the same tools used for the rest of the HISP configuration.

### Adding External Jars to a Service's Classpath (e.g., PKCS11 Providers)

Each micro-service jar/war is a Spring Boot fat archive launched via a `Main-Class` of `org.springframework.boot.loader.launch.JarLauncher` (or `WarLauncher` for Config UI) — you can confirm this by inspecting the `META-INF/MANIFEST.MF` inside the archive. This launcher only loads classes bundled inside the archive itself (under `BOOT-INF/lib` or `WEB-INF/lib`); unlike the legacy Tomcat model, there is no directory you can drop an extra jar into and have `java -jar <binary>` pick it up automatically. Common database drivers (MySQL, PostgreSQL) are already bundled where needed, so this normally isn't a concern. However, some scenarios require adding a jar that can't be bundled at build time — most notably a hardware vendor's proprietary PKCS11 JCE provider jar for [Enhanced Private Key Security](enhanced-key-security).

To add such a jar to a service's classpath, replace `-jar <binary>` in the launch command with an explicit invocation of Spring Boot's `PropertiesLauncher`, which supports an additional classpath via the `loader.path` system property:

1. Create a `lib` directory next to the service's jar/war and place the extra jar(s) in it (e.g. `./lib/LunaProvider.jar`).
2. Find the service's `Start-Class` by extracting `META-INF/MANIFEST.MF` from the jar/war (`unzip -p <binary> META-INF/MANIFEST.MF`). For example, the Security and Trust Agent's `Start-Class` is `org.nhindirect.stagent.boot.STAApplication`.
3. Change the `java` invocation to:

```
java -Dworking.directory=. -Dlogging.config=file:conf/logback.xml \
     -Dloader.path=lib -Dloader.main=<Start-Class> \
     -cp <binary> org.springframework.boot.loader.launch.PropertiesLauncher
```

Substitute this line for the `java -jar` line in the `service.sh` / `service.ps1` templates above for any service that needs an external provider jar; services that don't need one can keep using the simpler `-jar <binary>` form.

## Configuration Manager Tool

In addition to the micro-services above, the Cloud Native model ships **Configuration Manager**, a command-line tool for managing configuration service data — domains, addresses, anchors, certificates, DNS records, trust bundles, and certificate policies. It's the Cloud Native replacement for the Legacy model's `ConfigMgmtConsole` tool: both tools are driven by the same interactive commands (`ImportPolicy`, `AddPolicyGroup`, `AddPolicyToGroup`, `AddPolicyGroupToDomain`, `AddPrivateCertWithWrappedKey`, etc. — matched case-insensitively). Only the jar/tool you launch differs by deployment model.

Unlike the other micro-services, Configuration Manager isn't a long-running process — it's a one-shot interactive console (or a scriptable one-off command runner), so it doesn't need the `service.sh`/`service.ps1` start/stop wrapper.

Download the jar from Maven and place it in its own directory, same as the other services:

| Tool | Jar File | Directory |
| :---         | :---           | :---          |
| Configuration Manager | [config-manager.jar](https://repo.maven.apache.org/maven2/org/nhind/config-manager/9.0.0/config-manager-9.0.0.jar) | `config-manager` |

Run it directly with `java -jar`:

```
java -jar config-manager-9.0.0.jar
```

With no arguments, this launches the interactive console. To run a single command non-interactively (for example, from a script), pass the command and its arguments directly on the command line:

```
java -jar config-manager-9.0.0.jar ImportPolicy "Digital Signature" ./DigitalSig.pol
```

Like the other services, Configuration Manager connects to the Configuration Service's REST API and is configured via the same `direct.webservices.security.basic.user.*` and `direct.config.service.url` properties documented in the [Security and Trust Agent](#security-and-trust-agent) settings table — override them with an `application.yml` placed alongside the jar, or with `--property=value` arguments on the command line, for example:

```
java -jar config-manager-9.0.0.jar --direct.config.service.url=http://myconfigservice:8082/
```

## Modify Service Default Configuration

Each service ships with a default set of configuration values; however, you may want or need to override these settings to suit your deployment needs. For example, the configuration service and James use a local, file-based database with
default credentials. You'll likely want to use a "real" database running on a dedicated machine, such as MySQL or Postgres. The same goes for RabbitMQ, where you probably won't want to use the local RabbitMQ instance running
in Docker with the guest/guest credentials.

Spring supports several options for providing application configuration, and a simple way to override the default settings is to use an `application.yml` file placed in each directory that needs custom configuration settings. The following tables
list some of the common application settings that you may want to customize depending on your needs. Some of these properties are not defined in the micro-service's own `application.yml` — they're contributed by auto-configuration classes in
internal library JARs on the service's classpath, so they won't be visible just by looking at the jar's bundled config file.

### Configuration Service

| Name | Description | Default Value |
| :---         | :---           | :---          |
| spring.r2dbc.*                | Database connection configuration. See Spring [data properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.data) settings for full details. | url: `r2dbc:h2:file:///./embedded-db/nhindconfig;NON_KEYWORDS=VALUE;CASE_INSENSITIVE_IDENTIFIERS=TRUE`<br> username: `sa`<br>password: `""`  |
| spring.sql.init.platform      | Platform to use in the default schema generation script. Supported options are `h2`, `mysql`, and `postgresql`. | `h2`  |
| spring.security.user.name     | The basic auth username to access the configuration service API. | `admin`  |
| spring.security.user.password | The basic auth password to access the configuration service API. Stored in `application.yml` as a bcrypt hash (`{bcrypt}...`) — the value shown here is the decoded plaintext. | `d1r3ct;`  |
| direct.trustbundles.refresh.period | Interval, in milliseconds, at which a scheduled task checks all configured trust bundles for updates. | `3600000` |
| direct.config.keystore.hsmpresent | Enables HSM-backed (PKCS#11) protection for the keystore holding Direct signing/decryption certificates and keys. When `false`, the software passphrase settings below are used instead. | `false` |
| direct.config.keystore.bootstrapmanager | Enables the software "bootstrapped" keystore protection manager (used when no HSM is present) to protect/encrypt the keystore and private key passphrases. | `false` |
| direct.config.keystore.keyStorePassPhrase | Passphrase protecting the software (non-HSM) keystore holding Direct signing/decryption certificates and keys. **Change this for any real deployment.** | `H1TBr0s!` |
| direct.config.keystore.privateKeyPassPhrase | Passphrase protecting private keys in the software (non-HSM) keystore. **Change this for any real deployment.** | `H1TCh1ckS!` |
| direct.config.keystore.initOnStart | Whether to initialize the keystore/HSM token store on application startup. | `true` |
| direct.config.keystore.{keyStorePin, keyStoreType, keyStoreSourceAsString, keyStoreProviderName, keyStorePassPhraseAlias, privateKeyPassPhraseAlias} | Additional PKCS#11 HSM connection settings, only used when `hsmpresent=true`. | `som3randomp!n`<br>`Luna`<br>`slot:0`<br>`com.safenetinc.luna.provider.LunaProvider`<br>`keyStorePassPhrase`<br>`privateKeyPassPhrase` |

### Configuration UI

| Name | Description | Default Value |
| :---         | :---           | :---          |
| direct.webservices.security.basic.user.name     | Basic auth user name to access the configuration service API. | `admin` |
| direct.webservices.security.basic.user.password | Basic auth password to access the configuration service API. |`d1r3ct;` |
| direct.webservices.connect.timeout              | Connect timeout, in milliseconds, for the REST client used to call the configuration service API. | `5000` |
| direct.webservices.response.timeout             | Response/read timeout, in milliseconds, for the REST client used to call the configuration service API. | `10000` |
| direct.config.service.url                      | URL of the configuration service API. | `http://localhost:8082/` |
| direct.configui.security.user.name             | Username to log in to the configuration UI web application. | `admin` |
| direct.configui.security.user.password         | Password to log in to the configuration UI web application. | `direct` |
| direct.config.keystore.hsmpresent | Enables HSM-backed (PKCS#11) protection for the keystore holding Direct signing/decryption certificates and keys. When `false`, the software passphrase settings below are used instead. | `false` |
| direct.config.keystore.keyStorePassPhrase | Passphrase protecting the software (non-HSM) keystore holding Direct signing/decryption certificates and keys. **Change this for any real deployment.** | `H1TBr0s!` |
| direct.config.keystore.privateKeyPassPhrase | Passphrase protecting private keys in the software (non-HSM) keystore. **Change this for any real deployment.** | `H1TCh1ckS!` |
| direct.config.keystore.initOnStart | Whether to initialize the keystore/HSM token store on application startup. | `true` |
| direct.config.keystore.{keyStorePin, keyStoreType, keyStoreSourceAsString, keyStoreProviderName, keyStorePassPhraseAlias, privateKeyPassPhraseAlias} | Additional PKCS#11 HSM connection settings, only used when `hsmpresent=true`. | `som3randomp!n`<br>`Luna`<br>`slot:0`<br>`com.safenetinc.luna.provider.LunaProvider`<br>`keyStorePassPhrase`<br>`privateKeyPassPhrase` |

### DNS Service

| Name | Description | Default Value |
| :---         | :---           | :---          |
| direct.webservices.security.basic.user.name     | Basic auth user name to access the configuration service API. | `admin` |
| direct.webservices.security.basic.user.password | Basic auth password to access the configuration service API. | `d1r3ct;` |
| direct.config.service.url                       | URL of the configuration service API. | `http://localhost:8082/` |
| direct.dns.binding.port    | UDP/TCP port the DNS server listens on for incoming DNS queries. Port 53 is privileged on most systems — see the note in [Launch Microservices](#launch-microservices). | `53` |
| direct.dns.binding.address | Local IP address the DNS server binds to. By default it binds to all interfaces. | `0.0.0.0` |
| direct.dns.binding.maxReconnectAttempts | Number of times the server attempts to re-bind its listener socket after an I/O failure before giving up. | `10` |
| direct.dns.certPolicyName  | Name of a certificate policy (defined in the Configuration Service) used to filter CERT record query responses — typically used for single-use certificate deployments. When empty or unresolvable, no filtering is applied. | *(empty — no filtering)* |

### Message Monitor

| Name | Description | Default Value |
| :---         | :---           | :---          |
| spring.datasource.*                | Database connection configuration. See Spring [data properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.data) settings for full details. | url: `jdbc:derby:msgmonitor;create=true`<br> username: `nhind`<br>password: `nhind`  |
| spring.rabbitmq.*        | RabbitMQ connection properties. See Spring [integration properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.integration) settings for full details. | host: `localhost`<br>port: `5672`<br>username: `guest`<br>password: `guest` |
| direct.msgmonitor.condition.generalConditionTimeout  | Time in milliseconds the system will wait for MDN or DSN notification messages before generating an error message. | `3600000`  |
| direct.msgmonitor.condition.reliableConditionTimeout  | Time in milliseconds the system will wait for MDN or DNS notification messages before generating an error message when the original sender invokes the "implementation guide for delivery notification." | `3600000`  |
| direct.msgmonitor.dupStateDAO.retensionTime  | Time in days the tracking information will be stored in the system before being purged. | `7`  |
| direct.msgmonitor.dsnSender.useStreamsSender | When `true`, generated DSN/error notifications are published back into the message broker instead of being sent directly over SMTP. Mutually exclusive with `useSMTPGatewaySender`. | `true` |
| direct.msgmonitor.dsnSender.useSMTPGatewaySender | When `true`, generated DSN/error notifications are sent directly via SMTP to `dsnSender.gatewayURL` instead of the message broker. Mutually exclusive with `useStreamsSender`. | `false` |
| direct.msgmonitor.dsnSender.gatewayURL | SMTP gateway URL used to send DSNs when `useSMTPGatewaySender=true`. | `smtp://localhost:25` |
| direct.msgmonitor.dsnGenerator.postmasterName | "From" display name used as the postmaster identity when generating DSN error messages. | `postmaster` |
| direct.msgmonitor.dsnGenerator.mtaName | MTA name reported in generated DSNs. | `DirectProject Message Monitor` |
| direct.msgmonitor.dsnGenerator.subjectPrefix | Subject line prefix on generated DSN error messages. | `Not Delivered:` |
| direct.msgmonitor.dsnGenerator.failedRecipientsTitle | Body text introducing the list of recipients for whom no timely notification was received. | `We have not received a delivery notification in 1 hour for the following recipient(s) because the receiving system may be down or configured incorrectly:` |
| direct.msgmonitor.dsnGenerator.errorMessageTitle | Title/heading text prepended to the error message body. | *(empty)* |
| direct.msgmonitor.dsnGenerator.defaultErrorMessage | Default explanatory error text included in the generated DSN. | `<b>Your message most likely was not delivered.</b> Please confirm your recipient email addresses are correct. If the addresses are correct, consider a different communication method.<br/><br/>If you continue to receive this message, please have the recipient check with their system administrator and include the "Troubleshooting Information" below.` |
| direct.msgmonitor.dsnGenerator.header | Header template prepended to the DSN body. Supports `%original_sender_tag%` substitution. | `%original_sender_tag%,<br/>` |
| direct.msgmonitor.dsnGenerator.footer | Footer template appended to the DSN body. Supports `%headers_tag%` substitution. | `<b><u>Troubleshooting Information</u></b><br/><br/>%headers_tag%` |
| direct.msgmonitor.recovery.retryInterval | Milliseconds between recovery attempts for the message aggregation repository after a failure. | `30000` |
| direct.msgmonitor.recovery.maxRetryAttemps | Maximum redelivery attempts for aggregation repository recovery. (This is the actual property name in code, including the missing "t" in "Attempts".) | `12` |
| direct.msgmonitor.recovery.deadLetterUri | Dead-letter destination for aggregation entries that exhaust recovery retries. | `file:recovery/directMonitorDeadLetter` |
| monitor.aggregatorRepository.recoveryLockInterval | Seconds an in-recovery aggregation entry is locked before being eligible for another recovery attempt. (Note: this property uses the `monitor.*` prefix rather than `direct.msgmonitor.*`.) | `120` |

### SMTP/MQ Gateway

| Name | Description | Default Value |
| :---         | :---           | :---          |
| spring.rabbitmq.*                 | RabbitMQ connection properties. See Spring [integration properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.integration) settings for full details. | host: `localhost`<br>port: `5672`<br>username: `guest`<br>password: `guest` |
| direct.smtpmqgateway.binding.port | The port that the server will listen on for incoming SMTP traffic. If you intend to make this server your primary SMTP interface to the internet, you should change this value to `25`. | `1025` |
| direct.smtpmqgateway.binding.host | The local IP address that this server will bind to. By default, it will bind to all addresses. | `0.0.0.0` |
| direct.smtpmqgateway.message.maxHeaderSize | The maximum size in bytes that the MIME header may be in incoming messages. | `262144` |
| direct.smtpmqgateway.message.maxMessageSize | The maximum size in bytes allowed for incoming messages. | `39845888` |
| direct.smtpmqgateway.clientwhitelist.cidr | Comma-separated list of CIDR blocks allowed to open SMTP connections to the listener. When unset, all client IPs are accepted. | *(empty — no restriction)* |

### Security and Trust Agent

| Name | Description | Default Value |
| :---         | :---           | :---          |
| spring.rabbitmq.*                 | RabbitMQ connection properties. See Spring [integration properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.integration) settings for full details. | host: `localhost`<br>port: `5672`<br>username: `guest`<br>password: `guest` |
| direct.webservices.security.basic.user.name     | Basic auth user name to access the configuration service API. | `admin` |
| direct.webservices.security.basic.user.password | Basic auth password to access the configuration service API. |`d1r3ct;` |
| direct.config.service.url                      | URL of the configuration service API. | `http://localhost:8082/` |
| direct.msgmonitor.service.url | URL of the Message Monitor service, used to report and track tx/notification status. | `http://localhost:8081/` |
| direct.gateway.xd.enabled | Master switch for XD routing. When `false`, all incoming mail is routed to last-mile delivery (James) regardless of the recipient address's endpoint type. | `true` |
| direct.gateway.postprocess.routeLocalRecipientToGateway | For outgoing (encrypted) mail whose recipients are also local domains, loop the message directly back into the gateway ingest stream instead of the remote-delivery/SMTP-relay path. | `true` |
| direct.gateway.postprocess.ConsumeMDNProcessed | Suppress an incoming MDN with disposition `processed` instead of forwarding it on to last-mile delivery. | `true` |
| direct.gateway.remotedelivery.gateway.name | Comma-separated explicit outbound SMTP relay host(s) for remote delivery. When set, bypasses DNS MX lookup entirely. | *(empty — falls back to DNS MX lookup)* |
| direct.gateway.remotedelivery.gateway.port | Port for the explicit outbound SMTP relay host(s) above. | *(empty)* |
| direct.gateway.remotedelivery.gateway.username | Username for authenticating to the outbound SMTP relay. | *(empty — no auth)* |
| direct.gateway.remotedelivery.gateway.password | Password for outbound SMTP relay authentication. | *(empty)* |
| direct.gateway.remotedelivery.gateway.connectionTimeout | SMTP connection timeout, in milliseconds, for outbound relay delivery. | *(empty — JavaMail default)* |
| direct.gateway.remotedelivery.gateway.supressLocalDomains | Skip remote delivery when the recipient's domain is local (the post-processor already routes those back into the gateway). | `true` |
| direct.gateway.remotedelivery.dns.lookup.timeout | DNS resolver timeout, in seconds, for MX/A record lookups during outbound remote delivery. | `3` |
| direct.gateway.remotedelivery.dns.lookup.retries | DNS resolver retry count for the same lookups. | `2` |
| direct.gateway.remotedelivery.dns.servers | Comma-separated DNS server list used for outbound remote-delivery MX/A lookups. | *(empty — OS resolver config)* |
| direct.gateway.certificates.dns.servers | Comma-separated DNS server list used for DNS-based certificate discovery (separate from the remote-delivery resolver above). | *(empty — OS resolver config)* |
| direct.gateway.agent.useOutgoingPolicyForIncomingNotifications | Whether outgoing trust/security policy is also applied to incoming MDN/notification messages. | `true` |
| direct.gateway.agent.rejectOnTamper | Reject messages whose routing headers appear tampered with, rather than only logging. | `false` |
| direct.gateway.agent.jceProviderName | Explicit JCE provider name for the agent's signing/encryption/decryption operations. | *(empty — platform default)* |
| direct.gateway.agent.jceSensitiveProviderName | Explicit JCE provider name for sensitive crypto operations. | *(empty — platform default)* |
| direct.xd.documents.syntheticdata.classCode | Synthetic XDS `classCode` applied when a source document/CDA omits it during XD step processing. | `34133-9` |
| direct.xd.documents.syntheticdata.confidentialityCode | Synthetic XDS `confidentialityCode` default. | `N` |
| direct.xd.documents.syntheticdata.healthcareFacilityTypeCode | Synthetic XDS `healthcareFacilityTypeCode` default. | `Outpatient` |
| direct.xd.documents.syntheticdata.practiceSettingCode | Synthetic XDS `practiceSettingCode` default. | `General Medicine` |
| direct.gateway.keystore.hsmpresent | Enables HSM-backed (PKCS#11) protection for the STA's signing/decryption keystore. When `false`, the software passphrase settings below are used instead. | `false` |
| direct.gateway.keystore.keyStorePassPhrase | Passphrase protecting the software (non-HSM) keystore holding the STA's signing/decryption certificates and keys. **Change this for any real deployment.** | `H1TBr0s!` |
| direct.gateway.keystore.privateKeyPassPhrase | Passphrase protecting private keys in the software (non-HSM) keystore. **Change this for any real deployment.** | `H1TCh1ckS!` |
| direct.gateway.keystore.initOnStart | Whether to initialize the keystore/HSM token store on application startup. | `true` |
| direct.gateway.keystore.{keyStorePin, keyStoreType, keyStoreSourceAsString, keyStoreProviderName, keyStorePassPhraseAlias, privateKeyPassPhraseAlias} | Additional PKCS#11 HSM connection settings, only used when `hsmpresent=true`. | `som3randomp!n`<br>`Luna`<br>`slot:0`<br>`com.safenetinc.luna.provider.LunaProvider`<br>`keyStorePassPhrase`<br>`privateKeyPassPhrase` |

### James

| Name | Description | Default Value |
| :---         | :---           | :---          |
| spring.datasource.*          | Database connection settings, read via this module's own `@Value` bindings (not Spring Boot's standard JPA/datasource auto-configuration) to generate James's JPA config at startup: `url`, `username`, `password`, `driver-class-name`, `adapter`, `streaming`. | url: `jdbc:derby:./var/store/derby;create=true`<br> username: `app`<br>password: `app`<br>driver-class-name: `org.apache.derby.jdbc.EmbeddedDriver`<br>adapter: `DERBY`<br>streaming: `false`  |
| spring.datasource.adapter    | The OpenJPA vendor adapter identifying the database platform, used to generate the correct SQL dialect for James's JPA-backed mailbox/user stores. This must match the database platform targeted by `spring.datasource.url` and `spring.datasource.driver-class-name` — for example, if the URL/driver point at a PostgreSQL database, `adapter` must be set to `POSTGRESQL`, not left at the `DERBY` default. Acceptable values: `DB2`, `DERBY`, `H2`, `HSQL`, `INFORMIX`, `MYSQL`, `ORACLE`, `POSTGRESQL`, `SQL_SERVER`, `SYBASE`. | `DERBY` |
| spring.rabbitmq.*        | RabbitMQ connection properties. See Spring [integration properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.integration) settings for full details. | host: `localhost`<br>port: `5672`<br>username: `guest`<br>password: `guest` |
| direct.webservices.security.basic.user.name     | Basic auth user name to access the configuration service API. | `admin` |
| direct.webservices.security.basic.user.password | Basic auth password to access the configuration service API. |`d1r3ct;` |
| direct.webservices.connect.timeout              | Connect timeout, in milliseconds, for the REST client used to call the configuration service API. | `5000` |
| direct.webservices.response.timeout             | Response/read timeout, in milliseconds, for the REST client used to call the configuration service API. | `10000` |
| direct.config.service.url                      | URL of the configuration service API. | `http://localhost:8082/` |
| direct.james.notifications.suppressNotificationsForAddresses | Comma-separated recipient addresses for which MDN "dispatched" notifications and DSN bounce notifications are never generated. | *(empty — none suppressed)* |
| direct.james.notifications.dispatchedMDNDelay | Delay, in milliseconds, before a "dispatched" MDN is released to the outbound stream for recipients listed in `delayedDispatchMDNAddresses`. Can be overridden per-message via the `X-Delay-Dispatched-MDN` mail header (value in minutes). | *(empty — no delay)* |
| direct.james.notifications.delayedDispatchMDNAddresses | Comma-separated addresses (matched against the generated notification's `From`) whose "dispatched" MDN is delayed rather than sent immediately. | *(empty — none delayed)* |
| james.server.webadmin.enabled                  | Enables the James web admin API. | `true` |
| james.server.webadmin.username                 | Basic auth user name to access the James web admin API. | `admin` |
| james.server.webadmin.password                 | Basic auth password to access the James web admin API. | `d1r3ct` |
| james.server.webadmin.port                     | The HTTP port to access the James web admin API. | `8084` |
| james.server.smtp.autoAddresses | Comma-separated IP/CIDR addresses permitted to relay through the SMTP protocol without authentication. | *(empty)* |
| james.server.config.mailet.configFile | Path to an external `mailetcontainer.xml` to use in place of the bundled default mailet/processor pipeline config. | *(empty — uses bundled config)* |
| james.server.config.imap.configFile | Path to an external `imapserver.xml` to use in place of the bundled default. | *(empty — uses bundled config)* |
| james.server.config.pop3.configFile | Path to an external `pop3server.xml` to use in place of the bundled default. | *(empty — uses bundled config)* |
| james.server.config.smtp.configFile | Path to an external `smtpserver.xml` to use in place of the bundled default. | *(empty — uses bundled config)* |
| james.server.imap.bind                         | The local IP address that this server will bind to for the IMAP protocol. By default, it will bind to all addresses. | `0.0.0.0` |
| james.server.imap.port                         | The HTTP port that the IMAP protocol will listen on for incoming connections. | `1143` |
| james.server.imap.sockettls                    | Indicates if the initial IMAP connection is done over TLS. | `false` |
| james.server.imap.starttls                     | Indicates if the IMAP protocol supports the upgrade option to TLS. | `true` |
| james.server.imap.imapKeyStore                 | The key store file used for the IMAP TLS connection. | `/properties/keystore` |
| james.server.imap.imapKeyStorePassword         | The password for the IMAP key store file. | `1kingpuff` |
| james.server.pop3.bind                         | The local IP address that this server will bind to for the POP3 protocol. By default, it will bind to all addresses. | `0.0.0.0` |
| james.server.pop3.port                         | The HTTP port that the POP3 protocol will listen on for incoming connections. | `1110` |
| james.server.pop3.sockettls                    | Indicates if the initial POP3 connection is done over TLS. | `false` |
| james.server.pop3.starttls                     | Indicates if the POP3 protocol supports the upgrade option to TLS. | `true` |
| james.server.pop3.imapKeyStore                 | The key store file used for the POP3 TLS connection. | `/properties/keystore` |
| james.server.pop3.imapKeyStorePassword         | The password for the POP3 key store file. | `1kingpuff` |
| james.server.smtp.bind                         | The local IP address that this server will bind to for the SMTP protocol. By default, it will bind to all addresses. | `0.0.0.0` |
| james.server.smtp.port                         | The HTTP port that the SMTP protocol will listen on for incoming connections. | `1587` |
| james.server.smtp.sockettls                    | Indicates if the initial SMTP connection is done over TLS. | `false` |
| james.server.smtp.starttls                     | Indicates if the SMTP protocol supports the upgrade option to TLS. | `true` |
| james.server.smtp.imapKeyStore                 | The key store file used for the SMTP TLS connection. | `/properties/keystore` |
| james.server.smtp.imapKeyStorePassword         | The password for the SMTP key store file. | `1kingpuff` |

### XD

| Name | Description | Default Value |
| :---         | :---           | :---          |
| spring.rabbitmq.*        | RabbitMQ connection properties. See Spring [integration properties](https://docs.spring.io/spring-boot/appendix/application-properties/index.html#appendix.application-properties.integration) settings for full details. | host: `localhost`<br>port: `5672`<br>username: `guest`<br>password: `guest` |
| server.servlet.context-path         | The application context path for HTTP requests. | `/xd` |
| direct.webservices.security.basic.user.name     | Basic auth user name to access the configuration service API. You will need to set this value. | *(none)* |
| direct.webservices.security.basic.user.password | Basic auth password to access the configuration service API. You will need to set this value. | *(none)* |
| direct.webservices.connect.timeout              | Connect timeout, in milliseconds, for the REST client used to call the configuration service API. | `5000` |
| direct.webservices.response.timeout             | Response/read timeout, in milliseconds, for the REST client used to call the configuration service API. | `10000` |
| direct.config.service.url                      | URL of the configuration service API. | `http://localhost:8082` |
| direct.xd.usestreams | When `true`, accepted XDR document sets that need to be forwarded to SMTP recipients are sent via the message broker instead of a direct SMTP send. | `true` |
