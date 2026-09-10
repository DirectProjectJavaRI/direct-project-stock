---
title: Machine Deployment (Fat Jars)
---

# Machine Deployment (Fat Jars)

This deployment model runs each micro-service as a plain Java process on one or more machines — physical hosts or long-lived ("pet") virtual machines. It is the closest cloud-native analog to the [Legacy](legacy-deployment) Bare Metal deployment pattern: instead of a single Tomcat and Apache James assembly, you run the set of Spring Boot fat jars listed in the [Cloud Native HISP Deployment Model](cloud-native-deployment#micro-services-list) — each in its own directory, started and stopped with a small service script.

The network topology is the same [generalized topology](cloud-native-deployment#topology-overview) described on the landing page: an externally facing SMTP gateway (and, optionally, an XD endpoint) in the public zone, the Security and Trust Agent and its supporting services on an internal network, and a message broker tying the processing pipeline together. On a single machine you can run every service side by side; for a larger or more resilient deployment, spread the services across several machines and point them at shared database and broker instances (see [Modify Service Default Configuration](service-configuration)).

The rest of this page walks through deploying the message broker, downloading the micro-service binaries, and launching them.

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

The DNS records the DNS Service serves are managed through the Config UI and [Configuration Manager](configuration-manager), the same tools used for the rest of the HISP configuration.

### Adding External JARs to the Classpath

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
