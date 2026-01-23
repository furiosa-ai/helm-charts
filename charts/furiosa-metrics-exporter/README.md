# Deploying `furiosa-metrics-exporter` with Helm

This Helm chart deploys the `furiosa-metrics-exporter` for Kubernetes, which enables the exporting metrics of FuriosaAI NPUs within your Kubernetes cluster.

## Prerequisites
- FuriosaAI NPUs installed on your nodes
- FuriosaAI NPU driver installed on your nodes

## Installation

You can deploy the `furiosa-metrics-exporter` by running the following commands:

```shell
helm repo add furiosa https://furiosa-ai.github.io/helm-charts
helm repo update
helm install furiosa-metrics-exporter furiosa/furiosa-metrics-exporter -n <namespace> --create-namespace
```
