# Deploying `furiosa-npu-operator` with Helm

This Helm chart deploys the `furiosa-npu-operator` for Kubernetes, which enables the automating of FuriosaAI Cloud Native components within your Kubernetes cluster.

## Prerequisites
- FuriosaAI NPUs installed on your nodes
- FuriosaAI NPU driver installed on your nodes
- [`node-feature-discovery`](https://github.com/kubernetes-sigs/node-feature-discovery) deployed in your cluster.

## Installation

You can deploy the `furiosa-npu-operator` by running the following commands:

```shell
helm repo add furiosa https://furiosa-ai.github.io/helm-charts
helm repo update
helm install furiosa-npu-operator furiosa/furiosa-npu-operator -n <namespace> --create-namespace
```
