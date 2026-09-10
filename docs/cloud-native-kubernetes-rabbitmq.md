---
title: 'Production Kubernetes: RabbitMQ'
---

# Production Kubernetes: RabbitMQ

The message broker is the backbone of the [Cloud Native](cloud-native-deployment) processing pipeline — every Direct message flows through it as it moves from the SMTP/MQ Gateway to the STA and on to James, remote delivery, or XD. In a production HISP it needs to be highly available and independently operable, which the default deployment is not.

## What the default configuration does

`01-rabbitmq.yaml` in the [`direct-project-k8s`](https://github.com/DirectProjectJavaRI/direct-project-k8s) repository runs a **single-node** RabbitMQ:

* one `Deployment` replica of the `rabbitmq:3.13-management` image
* a `PersistentVolumeClaim` (`rabbitmq-data`) for the Mnesia directory, so durable queues and persistent messages survive a pod restart
* `strategy: Recreate` and `RABBITMQ_NODENAME=rabbit@localhost`, so the node keeps a stable identity across restarts and can re-open the existing data
* a single application user (`direct` / `direct`) created from the `rabbitmq-credentials` `Secret`

This is fine for evaluation, but it is a single point of failure, has no clustering or quorum queues, and every broker upgrade is a manual, disruptive operation.

## Options to consider

**On-cluster, operator-managed.** The [RabbitMQ Cluster Operator](https://github.com/rabbitmq/cluster-operator) is the open-source, officially supported way to run RabbitMQ on Kubernetes. You describe the broker with a `RabbitmqCluster` custom resource and the operator manages a multi-node cluster with rolling upgrades, persistent storage, Prometheus metrics, and TLS. Pair it with quorum queues for replicated, HA queue storage. Commercial distributions (for example VMware Tanzu RabbitMQ) build on the same operator with additional support and tooling.

**Managed / off-cluster.** A hosted broker removes broker operations from your plate entirely: [Amazon MQ for RabbitMQ](https://aws.amazon.com/amazon-mq/), CloudAMQP, or an equivalent on your cloud provider. The micro-services simply connect to it over the network. This is often the fastest path to a supportable production broker if your team does not want to run stateful infrastructure on the cluster.

**Bring your own.** If your organization already operates a RabbitMQ or AMQP-compatible broker, the RI services can point at it directly.

Whichever you choose, use durable exchanges and durable (ideally quorum) queues. The Spring Cloud Stream bindings the RI ships already declare durable queues, so no application change is needed for that.

## What changes in the manifests

Five services talk to RabbitMQ: `direct-smtp-mq-gateway`, `direct-sta-sboot`, `direct-james-server`, `direct-msg-monitor`, and `xd`. Each reads its broker connection from `spring.rabbitmq.*` keys in its own `<service>-config` `Secret`:

| Key | Purpose |
|-----|---------|
| `spring.rabbitmq.host` | broker hostname (a Kubernetes `Service` name for an on-cluster broker, or an external DNS name) |
| `spring.rabbitmq.port` | broker port (`5672`, or `5671` for TLS) |
| `spring.rabbitmq.username` / `spring.rabbitmq.password` | application credentials on the new broker |
| `spring.rabbitmq.virtual-host` | vhost, if the broker isolates the RI into its own |
| `spring.rabbitmq.ssl.enabled` | set to `true` for a TLS connection (managed brokers usually require it) |

Update those keys in all five `Secret`s to point at the new broker. If you are no longer running the bundled broker, also remove `01-rabbitmq.yaml` and its `rabbitmq-credentials` `Secret` from your apply set.

See [Modify Service Default Configuration](service-configuration) for the full `spring.rabbitmq.*` reference, and [Secrets Management](cloud-native-kubernetes-secrets) for keeping the updated credentials out of source control.
