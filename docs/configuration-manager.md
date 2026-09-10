---
title: Configuration Manager Tool
---

# Configuration Manager Tool

In addition to the [core micro-services](cloud-native-deployment#micro-services-list), the Cloud Native model ships **Configuration Manager**, a command-line tool for managing configuration service data — domains, addresses, anchors, certificates, DNS records, trust bundles, and certificate policies. It's the Cloud Native replacement for the Legacy model's `ConfigMgmtConsole` tool: both tools are driven by the same interactive commands (`ImportPolicy`, `AddPolicyGroup`, `AddPolicyToGroup`, `AddPolicyGroupToDomain`, `AddPrivateCertWithWrappedKey`, etc. — matched case-insensitively). Only the jar/tool you launch differs by deployment model.

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

Like the other services, Configuration Manager connects to the Configuration Service's REST API and is configured via the same `direct.webservices.security.basic.user.*` and `direct.config.service.url` properties documented in the [Security and Trust Agent](service-configuration#security-and-trust-agent) settings table — override them with an `application.yml` placed alongside the jar, or with `--property=value` arguments on the command line, for example:

```
java -jar config-manager-9.0.0.jar --direct.config.service.url=http://myconfigservice:8082/
```
