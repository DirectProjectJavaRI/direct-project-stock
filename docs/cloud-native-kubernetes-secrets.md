---
title: 'Production Kubernetes: Secrets Management'
---

# Production Kubernetes: Secrets Management

Every micro-service in the [`direct-project-k8s`](https://github.com/DirectProjectJavaRI/direct-project-k8s) repository reads its configuration — database credentials, broker credentials, API passwords, keystore passphrases — from a Kubernetes `Secret` named `<service>-config`, mounted into the pod. That indirection is good; how the `Secret` is *produced* is what needs to change for production.

## What the default configuration does

Each manifest bundles its `Secret` inline, populated with `stringData`, and the file is committed to the repository:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: config-service-config
stringData:
  spring.security.user.password: "d1r3ct;"
  # ...
```

Kubernetes `Secret`s are only base64-encoded, not encrypted, so anyone who can read the repository or `get secrets` in the namespace can read every credential. The values shipped are the reference implementation's well-known defaults. This is acceptable for a throwaway evaluation stack and unacceptable for anything else.

## Options to consider

**Sync from an external secret store.** The [External Secrets Operator](https://external-secrets.io/) pulls values from AWS Secrets Manager, Google Secret Manager, Azure Key Vault, HashiCorp Vault, and others, and materializes them as Kubernetes `Secret`s. You commit an `ExternalSecret` that references the store; the real values never enter the repository. This is usually the best fit when your organization already has a secret manager.

**Mount straight from the store, no `Secret` at rest.** The [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/) mounts secret material into the pod as files pulled directly from an external provider, so there is no long-lived Kubernetes `Secret` object to protect (a synced `Secret` can still be created if a workload needs `envFrom`).

**Encrypt secrets so they *can* be committed.** [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) encrypts a `Secret` with a cluster-held key into a `SealedSecret` that is safe to store in Git; an in-cluster controller decrypts it back into a real `Secret`. [SOPS](https://github.com/getsops/sops) with `age` or KMS, wired into a GitOps tool such as Argo CD or Flux, achieves the same for a GitOps workflow.

Whatever you use, also:

* **Rotate every default credential.** At minimum: the Configuration Service / service-to-service basic auth (`admin` / `d1r3ct;`), the Configuration UI login (`admin` / `direct`), the James web admin password (`d1r3ct`), and the software keystore passphrases (`H1TBr0s!` / `H1TCh1ckS!`). See [Modify Service Default Configuration](service-configuration) for the complete list.
* **Enable encryption at rest for `Secret`s** in the API server (etcd encryption), or confirm your managed control plane already does it.
* **Lock down RBAC** on the `direct-project` namespace so only the workloads and operators that need a given `Secret` can read it.

## What changes in the manifests

The `Deployment`s do not need to change — they already reference `<service>-config` by name. Replace the inline `Secret` definitions with whichever mechanism above produces a `Secret` of the same name and keys, and drop the plaintext `Secret` YAML (and the standalone `rabbitmq-credentials` and `bootstrap-domain-config` `Secret`s) from source control.
