---
title: Cloud Native HISP Deployment Model
---

# Cloud Native HISP Deployment Model

The cloud native Health Information Service Provider (HISP) deployment model consists of smaller individual processes (i.e., micro-services) performing specific functional tasks and exposing APIs
either via REST or asynchronous messaging interfaces. Generally, the REST interfaces are used to retrieve and maintain the system's configuration
data, while the messaging interfaces are used to move Direct messages from one processing step to another using a streaming/pipelining paradigm.

Each micro-service is a discrete Spring Boot fat jar application. Because they are ordinary JVM processes with no container or platform dependencies, they can be deployed on a wide range of targets — bare metal or virtual
machines, Docker, Cloud Foundry, Kubernetes, Google Cloud Run, and so on. This page introduces the deployment model, its topology, and the set of micro-services; the [Deployment Models](#deployment-models) section below links
to step-by-step instructions for the platforms this documentation covers in detail.

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

The topology shown here is platform-agnostic. The same network zones, micro-services, and message flows apply whether each micro-service runs as a plain Java process on a long-lived ("pet") machine, as a container on a platform
such as Kubernetes, or on a managed runtime. Only the packaging and the platform-specific networking, scaling, and persistence details differ — those are covered in each deployment model's own page.

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

## Deployment Models

The micro-services above are ordinary Spring Boot fat-jar applications, so they can run on almost any platform capable of hosting a JVM process or an OCI container. This documentation covers two deployment models in detail:

* **[Machine Deployment (Fat Jars)](cloud-native-machine-deployment)** — run each micro-service as a plain Java process on one or more machines, physical or virtual. This is the closest analog to the Legacy [Bare Metal](legacy-deployment)
  deployment pattern, substituting the cloud-native fat jars for the old Tomcat and Apache James assembly.
* **[Kubernetes Deployment](cloud-native-kubernetes-deployment)** — deploy the micro-services as containers onto a Kubernetes cluster.

Other platforms — Cloud Foundry, Google Cloud Run, Amazon ECS, and similar — are equally viable, but may add platform-specific steps such as building container images or authoring platform manifests. Those steps are out of scope
for this documentation.

## Configuration and Tooling

The following apply to every deployment model. The property names and defaults are the same regardless of platform; only the mechanism for applying an override differs (see each page):

* **[Modify Service Default Configuration](service-configuration)** — the reference of configurable properties for each micro-service, with descriptions and default values.
* **[Configuration Manager Tool](configuration-manager)** — a command-line tool for loading domains, addresses, anchors, certificates, DNS records, trust bundles, and certificate policies into the Configuration Service.
