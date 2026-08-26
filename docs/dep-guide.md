---
title: Deployment Guide
---

# Deployment Guide

The contents of this section are a starting point from which a production Health Information Service Provider (HISP) can be derived. The Bare Metal project is not intended to be a final solution for real-world scenarios; it documents the fastest and simplest way to launch a minimally operational HISP using the Java Reference Implementation.

We strongly advise, though do not require, fronting the reference implementation with a tested and proven enterprise mail server such as Proofpoint or Barracuda. Review the available deployment models and configurations with your system architect and decide which best suits your needs. This should also involve input from your security officer to evaluate issues such as HIPAA compliance.

The Bare Metal install should not be considered HIPAA compliant out of the box. Although it can be scaled up to meet high-availability (HA) requirements, the default instructions do not implement a highly available or fault-tolerant deployment.

* [HISP Only Deployment (no source)](dep-hisp-only)