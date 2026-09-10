---
title: 'Production Kubernetes: Ingress'
---

# Production Kubernetes: Ingress

For a HISP to do anything useful, other HISPs and local end users have to be able to reach it — external SMTP for HISP-to-HISP exchange, an XDR endpoint for EHR submissions, IMAP/POP3 for mailbox clients, and (for operators) the Configuration UI. The default deployment exposes none of that.

## What the default configuration does

Every service in the [`direct-project-k8s`](https://github.com/DirectProjectJavaRI/direct-project-k8s) repository is a `ClusterIP` `Service`, reachable only from inside the cluster. The documentation shows `kubectl port-forward` for local testing, which tunnels a single port to your workstation and terminates no TLS, applies no authentication, and does no load balancing. It is a debugging tool, not an exposure strategy.

## Options to consider

Put a real edge in front of the cluster using the [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/). It is the current standard for ingress, and unlike the older `Ingress` resource it models L4 as well as L7 traffic (`HTTPRoute`, `TLSRoute`, `TCPRoute`, `UDPRoute`) and separates the infrastructure-owned `Gateway` from the app-owned routes.

**Pick an implementation.** [Envoy Gateway](https://gateway.envoyproxy.io/) is a good default — it is a CNCF project, tracks the Gateway API closely, and is built on the same Envoy proxy used by many service meshes. Istio, Cilium, and NGINX Gateway Fabric are other conformant options, as are the cloud providers' own Gateway controllers.

**Prefer a controller that integrates with your platform.** Several implementations provision cloud load balancers automatically from Gateway API resources. On AWS, for example, the AWS Load Balancer Controller (and the AWS Gateway API Controller for VPC Lattice) creates and manages an NLB or ALB from your `Gateway` definition, so you are not clicking around a console or writing Terraform for every listener. GKE and AKS have equivalent Gateway controllers that drive their native load balancers. This keeps the entire edge — DNS-fronted address, listeners, TLS certificates, target registration — described declaratively alongside the workloads.

## What to route

| Traffic | Service (port) | Route type | Notes |
|---------|----------------|------------|-------|
| Inbound Direct SMTP (from other HISPs) | `direct-smtp-mq-gateway` (`25`) | `TCPRoute` | The HISP's primary inbound path. Front it with a commercial mail security gateway if you need spam/malware filtering. |
| XDR document submission | `xd` (`8080`, path `/xd`) | `HTTPRoute` | Terminate TLS at the Gateway; consider requiring client certificates (mTLS) for partner EHRs. |
| Configuration UI | `config-ui` (`8080`) | `HTTPRoute` | Operator access only — restrict by source or put it behind SSO / a VPN. |
| SMTP submission / IMAP / POP3 (end users) | `direct-james-server` (`587` / `1143` / `1110`) | `TCPRoute` (or `TLSRoute` with SNI passthrough) | These protocols negotiate their own STARTTLS; pass the TCP stream through rather than terminating TLS at the edge. |
| DNS (CERT record discovery) | `dns-sboot` (`53` TCP + UDP) | `TCPRoute` + `UDPRoute`, or a dedicated `LoadBalancer` `Service` | Needs a routable public address so other HISPs' resolvers can query it. |

Do **not** expose the Configuration Service API, the STA, the Message Monitor, RabbitMQ, or the James web admin API outside the cluster — they are internal components. (The James web admin API binds to the pod loopback interface and is only reachable through `kubectl port-forward` regardless.)

Terminate TLS and apply authentication and rate limiting at the Gateway for the HTTP endpoints, and use real certificates (for example via cert-manager) rather than the self-signed development certificate some services ship with.

Sample `HTTPRoute` and `TCPRoute` manifests for a specific implementation may be added to the [`direct-project-k8s`](https://github.com/DirectProjectJavaRI/direct-project-k8s) repository in the future; until then, the routing table above and your chosen implementation's documentation are the starting point.
