# Deploying `furiosa-feature-discovery` with Helm

This Helm chart deploys the `furiosa-feature-discovery` for Kubernetes, which enables the labeling of FuriosaAI NPU feature within your Kubernetes cluster.

## Prerequisites
- FuriosaAI NPUs installed on your nodes
- FuriosaAI NPU driver installed on your nodes
- [`node-feature-discovery`](https://github.com/kubernetes-sigs/node-feature-discovery) deployed in your cluster.

## Installation

You can deploy the `furiosa-feature-discovery` by running the following commands:

```shell
helm repo add furiosa https://furiosa-ai.github.io/helm-charts
helm repo update
helm install furiosa-feature-discovery furiosa/furiosa-feature-discovery -n <namespace> --create-namespace
```