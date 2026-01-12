# Deploying `furiosa-device-plugin` with Helm

This Helm chart deploys the `furiosa-device-plugin` for Kubernetes, which enables the use of FuriosaAI NPUs via Device Plugin API within your Kubernetes cluster.

## Prerequisites
- Kubernetes 1.20+
- FuriosaAI NPUs installed on your nodes
- FuriosaAI NPU driver installed on your nodes

## Installation

You can deploy the `furiosa-device-plugin` by running the following commands:

```shell
helm repo add furiosa https://furiosa-ai.github.io/helm-charts
helm repo update
helm install furiosa-device-plugin furiosa/furiosa-device-plugin -n <namespace> --create-namespace
```