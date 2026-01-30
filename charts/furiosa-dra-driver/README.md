# Deploying `furiosa-dra-driver` with Helm

This Helm chart deploys the `furiosa-dra-driver` for Kubernetes, which enables the use of FuriosaAI NPUs via DRA Driver API within your Kubernetes cluster.

## Prerequisites
- Kubernetes 1.34+
- FuriosaAI NPUs installed on your nodes
- FuriosaAI NPU driver installed on your nodes

## Installation

You can deploy the `furiosa-dra-driver` by running the following commands:

```shell
helm repo add furiosa https://furiosa-ai.github.io/helm-charts
helm repo update
helm install furiosa-dra-driver furiosa/furiosa-dra-driver -n <namespace> --create-namespace
```