---
title: Overview
---

# Overview

The Bare Metal assembly has historically been a deployment option consisting of a single Java assembly, based on the Java Reference Implementation, that packages Apache Tomcat and Apache James as its main hosting applications. Over time, the reference implementation has migrated to a more contemporary, cloud-native paradigm. As of the 9.0 release, the Bare Metal assembly has retired the use of Tomcat and moved to a purely microservices-based architecture made up of a set of Spring Boot applications with pre-configured core settings for rapid deployment.

The Java Reference Implementation and Bare Metal projects are not intended to be a full-blown, production-ready Health Information Service Provider (HISP). Instead, they are a starting point from which a production HISP can be derived and deployed.

## Guides

This document describes the Bare Metal installation of the Java Direct Project reference implementation from a pre-built assembly (no source required).

* [Deployment Guide](dep-guide) - This section describes how to deploy a Bare Metal installation.
* [Deployment Options](imp-options) - This section describes how to configure the Bare Metal installation for specific use cases, such as single-use certificates and enhanced private key protection.
