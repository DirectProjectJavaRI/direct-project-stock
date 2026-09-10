---
title: Kubernetes Deployment
---

# Kubernetes Deployment

This deployment model runs the same set of reference implementation micro-services as containers orchestrated by [Kubernetes](https://kubernetes.io/). Where the [Machine Deployment (Fat Jars)](cloud-native-machine-deployment) model runs each service as a plain Java process you start and stop yourself, this model hands the same jars — pre-packaged as container images — to a cluster that schedules them, restarts them when they fail, and gives them stable in-cluster networking and storage.

The network topology is the same [generalized topology](cloud-native-deployment#topology-overview) described on the landing page, and the [Micro-Services List](cloud-native-deployment#micro-services-list) is unchanged. Only the packaging and the platform mechanics — Deployments and Services instead of directories and scripts, `Secret`s and environment variables instead of `application.yml` files, `PersistentVolumeClaim`s instead of local directories — are specific to this page.

As with the rest of the Bare Metal / Reference Implementation documentation, this is a **starting point, not a production configuration**. The manifests deploy a default, single-instance configuration of the RI that is meant to work on almost any Kubernetes platform with minimal changes, so you can stand the system up quickly and then evolve it toward a hardened, highly available HISP for your environment.

## Prerequisites

You need a running Kubernetes cluster and a `kubectl` context pointed at it before you start. The cluster provider does not matter — for local development and testing, something as simple as [kind](https://kind.sigs.k8s.io/) or the Kubernetes support built into Docker Desktop is enough; for a production HISP you would typically run on a managed platform such as Amazon EKS, Azure AKS, or Google GKE. The one platform-specific concern is persistent storage, which is covered under [Notes and Caveats](#storageclass-per-platform).

## The `direct-project-k8s` Manifest Repository

A companion repository, [`direct-project-k8s`](https://github.com/DirectProjectJavaRI/direct-project-k8s), holds a default set of Kubernetes manifests that deploy a working, default configuration of the reference implementation. The manifests pull container images from the **`directproject`** organization on Docker Hub — <https://hub.docker.com/orgs/directproject> — which publishes an image for every micro-service in the deployment model.

Everything installs into a namespace named `direct-project`.

### Repository Structure

The repository contains one manifest file per Kubernetes resource group and Direct Project micro-service:

| File | Component | Notes |
|------|-----------|-------|
| `00-namespace.yaml` | namespace `direct-project` | |
| `01-rabbitmq.yaml` | RabbitMQ broker | Not a DirectProject image; required by the Spring Cloud Stream services. User `direct`/`direct`. Mnesia data on a `PersistentVolumeClaim` (`rabbitmq-data`) so durable queues and messages survive restarts. |
| `10-config-service.yaml` | Configuration Service | Embedded H2 database on a `PersistentVolumeClaim` (`config-service-data`); `/actuator/health` probes; HTTP 8080. |
| `11-config-ui.yaml` | Configuration UI | HTTP 8080; log in with `admin`/`direct`. |
| `20-dns-sboot.yaml` | DNS Service | DNS on port 53 (TCP + UDP); HTTP 8080. |
| `30-direct-james-server.yaml` | Apache James | SMTP 587→1587, IMAP 1143, POP3 1110, webadmin API/HTTP 8084 (`admin`/`d1r3ct`); embedded Derby store on a `PersistentVolumeClaim` (`direct-james-server-data`). |
| `40-direct-smtp-mq-gateway.yaml` | SMTP/MQ Gateway | Non-web service; SMTP 25→1025. |
| `50-direct-msg-monitor.yaml` | Message Monitor | H2 file database on a `PersistentVolumeClaim` (`direct-msg-monitor-data`); `/actuator/health` probes; HTTP 8080. |
| `60-direct-sta-sboot.yaml` | Security and Trust Agent | `/actuator/health` probes; HTTP 8080. |
| `70-xd.yaml` | XD | HTTP 8080; context path `/xd`. |
| `80-bootstrap-domain.yaml` | one-shot `Job` | Seeds one Direct domain into the Configuration Service — the STA will not start with zero domains configured. |

Each micro-service manifest bundles its own `Secret` (named `<service>-config`), a `Deployment`, and a `ClusterIP` `Service`. The `Secret`s in the repository carry the reference implementation's default credentials so the stack comes up out of the box; for any real deployment, replace them using a secret-management approach appropriate to your cluster (a sealed-secret controller, an external secret store, your platform's secret integration, and so on) and see [Modify Service Default Configuration](service-configuration) for the full list of settings each service exposes.

## Deploy

First, clone the manifest repository so you have the YAML files locally:

```sh
git clone https://github.com/DirectProjectJavaRI/direct-project-k8s.git
cd direct-project-k8s
```

Then apply every manifest in the repository root:

```sh
kubectl apply -f .
```

`kubectl apply -f .` processes files in filename order, so the `00-` prefix on `00-namespace.yaml` ensures the `direct-project` namespace exists before the manifests that put resources into it — otherwise the first apply fails with `namespaces "direct-project" not found`. Ordering among the numbered service manifests has no effect beyond that; their pods start concurrently and retry until dependencies are ready.

Check the progress of the rollout with:

```sh
kubectl -n direct-project rollout status deployment --timeout=300s
kubectl -n direct-project get pods
```

It is normal to see a few restarts on `direct-james-server` and `direct-sta-sboot` during the initial rollout while they wait for the Configuration Service and the seeded domain to become available.

If the rollout stalls — pods stuck in `Pending`, `ContainerCreating`, or `CrashLoopBackOff` — check [Notes and Caveats](#notes-and-caveats) first. The most common cause on a managed platform is a `PersistentVolumeClaim` that cannot bind because the cluster's `StorageClass` differs from the `standard` the manifests assume (on EKS this also requires installing the EBS CSI driver). `kubectl -n direct-project get pvc` and `kubectl -n direct-project describe pod <name>` will point at the specific problem.

## Local Connectivity Testing

To reach a service from your workstation for testing or troubleshooting, use `kubectl port-forward`. Each command tunnels a local port to the in-cluster `Service` and runs in the foreground — leave it running while you use the port and press `Ctrl+C` to close it.

```sh
# HTTP endpoints
kubectl -n direct-project port-forward svc/config-ui 8080:8080            # http://localhost:8080  (admin/direct)
kubectl -n direct-project port-forward svc/config-service 8082:8080       # http://localhost:8082/actuator/health
kubectl -n direct-project port-forward svc/xd 9080:8080                   # http://localhost:9080/xd

# Inbound mail entry point: SMTP -> RabbitMQ gateway
kubectl -n direct-project port-forward svc/direct-smtp-mq-gateway 2525:25

# James mail server
kubectl -n direct-project port-forward svc/direct-james-server 1587:587   # SMTP submission
kubectl -n direct-project port-forward svc/direct-james-server 1143:1143  # IMAP
kubectl -n direct-project port-forward svc/direct-james-server 1110:1110  # POP3
kubectl -n direct-project port-forward svc/direct-james-server 8084:8084  # webadmin API
```

Port-forwarding is a developer convenience, not a way to expose the platform. To make services reachable from outside the cluster, adopt a real ingress strategy. The [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/) is the current recommended approach: deploy an implementation (Envoy Gateway, Istio, NGINX Gateway Fabric, or your cloud provider's controller) and define `Gateway` plus `HTTPRoute` resources for the HTTP endpoints (Configuration UI, Configuration Service, XD) and `TCPRoute` resources for the mail protocols (SMTP, IMAP, POP3), terminating TLS and applying authentication at that layer. A traditional `Ingress` controller also works for the HTTP endpoints. RabbitMQ is intentionally left out — the messaging infrastructure should never be exposed outside the cluster.

## Notes and Caveats

### StorageClass per Platform

The `PersistentVolumeClaim`s in the manifests specify `storageClassName: standard`, which is the default on Docker Desktop, kind, and minikube. On a managed platform, change `storageClassName` on every PVC (or remove the field to fall back to the cluster's own default `StorageClass`, if it has one):

| Platform | StorageClass to use | Notes |
|----------|---------------------|-------|
| Docker Desktop / kind / minikube | `standard` (also `hostpath` / `local-path`) | Node-local storage, as shipped. |
| **AKS** (Azure) | `managed-csi` or `managed-csi-premium` | Azure Disk CSI is preinstalled; `managed-csi` is the default. |
| **GKE** (Google) | `standard-rwo` or `premium-rwo` | Persistent Disk CSI is preinstalled; `standard-rwo` is the default on current GKE. |
| **EKS** (AWS) | `gp3` (or `gp2`) | Needs setup — see below. |

On **EKS**, the Amazon EBS CSI driver is **not installed by default**, and recent EKS clusters ship with **no default `StorageClass`**, so these `PersistentVolumeClaim`s stay `Pending` until you (1) install the `aws-ebs-csi-driver` EKS add-on and attach an IAM role to it, and (2) create a `gp3` `StorageClass` (optionally marked the cluster default). See the AWS documentation for the [Amazon EBS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html). Note also that an EBS volume lives in a single Availability Zone: with a node group spanning multiple AZs, a pod can be scheduled in an AZ where its volume does not exist. Keeping `volumeBindingMode: WaitForFirstConsumer` on the `StorageClass` (the default for the AWS `gp3`/`gp2` classes) avoids this by deferring volume creation until the pod is scheduled.

### Persistence and single-instance services

Every stateful component keeps its data on a `ReadWriteOnce` `PersistentVolumeClaim`:

| PVC | Backs |
|-----|-------|
| `rabbitmq-data` | RabbitMQ Mnesia directory — durable queues and persistent messages. |
| `config-service-data` | Configuration Service H2 database — domains, trust anchors, certificates, settings. |
| `direct-msg-monitor-data` | Message Monitor H2 database — transaction, aggregation, and duplicate-tracking stores. |
| `direct-james-server-data` | James embedded Derby store — users, mailboxes, message content. |

The Configuration Service, Message Monitor, and James use a file-backed embedded database out of the box (H2 for the first two, Derby for James). That database takes an exclusive lock on its files, so **each of these three Deployments must stay at `replicas: 1`** — a second pod cannot acquire the lock and will fail to start. For the same reason those Deployments use `strategy: Recreate` (a rolling update would briefly run two pods contending for the same volume). To run more than one replica of any of them, move it off the embedded database onto a shared external MySQL or PostgreSQL instance (`spring.r2dbc.*` for the Configuration Service, `spring.datasource.*` for the Message Monitor and James — see [Modify Service Default Configuration](service-configuration)).

A few implementation details support this: RabbitMQ pins `RABBITMQ_NODENAME=rabbit@localhost` so its Erlang node name stays stable across pod restarts (a plain `Deployment` gives each pod a new hostname, which would orphan the Mnesia data), and because the Message Monitor's stock image runs with an in-memory database, its manifest overrides `spring.datasource.url` to a file database on the PVC. The stateless services (Configuration UI, DNS Service, SMTP/MQ Gateway, XD, STA) hold no local state and can be scaled normally.

### Default credentials

The `Secret`s carry the reference implementation's stock credentials — `admin`/`d1r3ct;` for service-to-service basic authentication and `admin`/`direct` for the Configuration UI. Change these in the per-service `Secret`s before exposing the deployment anywhere. See [Modify Service Default Configuration](service-configuration) for every credential and connection setting each service reads.

### The deployment is not a configured HISP

Applying the manifests brings the pods up, but the STA still needs trust anchors, domains, and certificates configured in the Configuration Service before mail will flow. Use the Configuration UI or the [Configuration Manager Tool](configuration-manager) to load your HISP configuration.

The STA refuses to start until at least one domain exists in the Configuration Service, so `80-bootstrap-domain.yaml` seeds a placeholder domain, `direct.example.com`, purely to get the service to boot. The STA only requires that *some* domain is present — once you have added your own domain(s), the placeholder can be safely deleted through the Configuration UI or Configuration Manager.

## Moving Toward a Production Deployment

The default manifests are tuned to come up on any cluster with a single `kubectl apply`, which means every stateful piece is deliberately simplified: one replica of each service, embedded H2/Derby databases, a single-node in-cluster RabbitMQ, credentials committed directly in the manifests, and no ingress beyond `kubectl port-forward`. Each of those is a reasonable default for evaluation and a poor one for a production Health Information Service Provider (HISP).

The pages below cover the main areas to revisit as you harden the deployment. They can be tackled independently and in any order; each describes what the default configuration does, the options worth considering, and which `Secret` values change as a result.

* **[RabbitMQ](cloud-native-kubernetes-rabbitmq)** — replacing the single-node in-cluster broker with an operator-managed cluster or a managed service.
* **[Secrets Management](cloud-native-kubernetes-secrets)** — getting credentials out of the checked-in manifests and into a real secret store.
* **[Database](cloud-native-kubernetes-database)** — moving the Configuration Service, Message Monitor, and James off their embedded databases onto MySQL or PostgreSQL.
* **[Ingress](cloud-native-kubernetes-ingress)** — exposing services outside the cluster with the Gateway API instead of port-forwarding.
