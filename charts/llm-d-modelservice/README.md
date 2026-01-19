# llm-d-modelservice

> [!IMPORTANT]
> The helm chart provided via `furiosa/llm-d-modelservice` is obtained from [`llm-d-incubation/llm-d-modelservice`](https://github.com/llm-d-incubation/llm-d-modelservice). It is modified to support `llm-d` integration of RNGD and Furiosa-LLM. Note that some features supported by the upstream `llm-d-modelservice` Helm repository might not be supported by this Helm chart.
>
> The following feature is currently not supported:
> * P/D Disaggregation

**ModelService** is a Helm chart that simplifies LLM deployment on llm-d by declaratively managing Kubernetes resources for serving base models. It enables reproducible, scalable, and tunable model deployments through modular presets, and clean integration with `llm-d` ecosystem components (including vLLM, Gateway API Inference Extension, LeaderWorkerSet). It provides an opinionated but flexible path for deploying, benchmarking, and tuning LLM inference workloads.

The ModelService Helm Chart proposal is accepted on June 10, 2025. Read more about the roadmap, motivation, and other alternatives considered [here](https://github.com/llm-d/llm-d/blob/main/docs/proposals/modelservice.md).

TL;DR:

Active scenarios supported:
- Multi-node inference, utilizing data parallelism
- One pod per DP rank

Integration with `llm-d` components:
- Quickstart guide in `llm-d-infra` depends on ModelService
- Flexible configuration of `llm-d-inference-scheduler` for routing
- Features `llm-d-routing-sidecar` in P/D disaggregation

## Getting started

Add this repository to Helm.

```shell
helm repo add furiosa https://furiosa-ai.github.io/helm-charts
helm repo update
```

ModelService operates under the assumption that `llm-d-infra` has been installed in a Kubernetes cluster, which installs the required prerequisites and CRDs. Read the [`llm-d` Guides](https://github.com/llm-d/llm-d/blob/main/guides/README.md) for more information.

## Routing

Once a model is deployed, inference requests must be routed to it. To do this, the Kubernetes Gateway API Inference Extension (GAIE) Helm charts can be used. These charts are defined [here](https://github.com/kubernetes-sigs/gateway-api-inference-extension/tree/main/config/charts/). For example, to create an InferencePool, use the chart oci://registry.k8s.io/gateway-api-inference-extension/charts/inferencepool.

### Relationships

Note that when using the GAIE [inferencepool chart](https://github.com/kubernetes-sigs/gateway-api-inference-extension/tree/main/config/charts/inferencepool) together with the modelservice chart the following relationships will exist:

- The modelservice field `modelArtifact.routing.servicePort` should match the GAIE field `inferencePool.targetPortNumber` or be an entry in the list `inferencePool.targets` (depending on the apiVersion of InferencePool).
- The modelservice field `modelArtifact.labels` should match the GAIE field, `inferencePool.modelServers.matchLabels`.
Note that the field `llm-d.ai/role` will be addition in addition to the labels specified in the `modelArtifacts.labels` field.

### HTTPRoute

In addition to deploying the GAIE chart, an `HTTPRoute` is typically required to connect the `Gateway` to the `InferencePool`. Creating an HTTPRoute is not part of either chart. Some examples are provided [here](https://github.com/llm-d-incubation/llm-d-modelservice/blob/main/examples/README.md#httproute).

## Values

> [!IMPORTANT]
> The following values are not properly supported:
> * `prefill.create: true`
>
>    Since Furiosa-LLM does not support P/D disaggregation, setting this value to `true` will cause an error during the deployment of the Helm chart.
>
> * `multinode: true`
>
>    Setting this value to `true` deploys decode pods using LeaderWorkerSet, which is designed for scenarios where multiple pods work cooperatively.
>    However, Furiosa-LLM processes cannot cooperatively perform LLM inference like [vLLM](https://docs.vllm.ai/en/latest/serving/data_parallel_deployment/#internal-load-balancing).
>    Furthermore, when deploying with LeaderWorkerSets containing more than one worker, only the leader pod's metrics are exposed to the GAIE, preventing proper load balancing across all workers.

Below are the values you can set.
| Key                                    | Description                                                                                                       | Type            | Default                                     |
|----------------------------------------|-------------------------------------------------------------------------------------------------------------------|-----------------|---------------------------------------------|
| `modelArtifacts.name`                  | name of model in the form namespace/modelId. Required.                                                            | string          | N/A                                         |
| `modelArtifacts.uri`                   | Model artifacts URI. Current formats supported include `hf://`, `pvc://`, and `oci://`                            | string          | N/A                                         |
| `modelArtifacts.size`                  | Size used to create an emptyDir volume for downloading the model.                                                 | string          | N/A                                         |
| `modelArtifacts.authSecretName`        | The name of the Secret containing `HF_TOKEN` for `hf://` artifacts that require a token for downloading a model.  | string          | N/A                                         |
| `modelArtifacts.mountPath`             | Path to mount the volume created to store models                                                                  | string          | /model-cache                                |
| `multinode`                            | Determines whether to create P/D using Deployments (false) or LeaderWorkerSets (true)                             | bool            | `false`                                     |
| `routing.servicePort`                  | The port the routing proxy sidecar listens on. <br>If there is no sidecar, this is the port the request goes to.  | int             | N/A                                         |
| `routing.proxy.image`                  | Image used for the sidecar                                                                                        | string          | `ghcr.io/llm-d/llm-d-routing-sidecar:0.0.6` |
| `routing.proxy.targetPort`             | The port the vLLM decode container listens on. <br>If proxy is present, it will forward request to this port.     | string          | N/A                                         |
| `routing.proxy.debugLevel`             | Debug level of the routing proxy                                                                                  | int             | 5                                           |
| `routing.proxy.parentRefs[*].name`     | The name of the inference gateway                                                                                 | string          | N/A                                         |
| `decode.create`                        | If true, creates decode Deployment or LeaderWorkerSet                                                             | List            | `true`                                      |
| `decode.annotations`                   | Annotations that should be added to the Deployment or LeaderWorkerSet                                             | Dict            | {}                                          |
| `decode.tolerations`                   | Tolerations that should be added to the Deployment or LeaderWorkerSet                                             | List            | []                                          |
| `decode.replicas`                      | Number of replicas for decode pods                                                                                | int             | 1                                           |
| `decode.extraConfig`                   | Extra pod configuration                                                                                           | dict            | {}                                          |
| `decode.containers[*].name`            | Name of the container for the decode deployment/LWS                                                               | string          | N/A                                         |
| `decode.containers[*].image`           | Image of the container for the decode deployment/LWS                                                              | string          | N/A                                         |
| `decode.containers[*].args`            | List of arguments for the decode container.                                                                       | List[string]    | []                                          |
| `decode.containers[*].modelCommand`    | Nature of the command. One of `furiosaLLMServe`, `imageDefault` or `custom`                                       | string          | `imageDefault`                              |
| `decode.containers[*].command`         | List of commands for the decode container.                                                                        | List[string]    | []                                          |
| `decode.containers[*].ports`           | List of ports for the decode container.                                                                           | List[Port]      | []                                          |
| `decode.containers[*].extraConfig`     | Extra container configuration                                                                                     | dict            | {}                                          |
| `decode.initContainers`.               | List of initContainers that should be added (in addition to routing proxy if enabled)                             | List[Container] | N/A                                         |
| `decode.parallelism.tensor`            | Amount of tensor parallelism                                                                                      | int             | 4                                           |
| `decode.parallelism.data`              | Amount of data parallelism                                                                                        | int             | 1                                           |
| `decode.parallelism.workers`           | Number of workers over which data parallelism is implemented                                                      | int             | 1                                           |
| `decode.acceleratorTypes.labelKey`     | Key of label on node that identifies the hosted GPU type                                                          | string          | N/A                                         |
| `decode.acceleratorTypes.labelValue`   | Value of label on node that identifies type of hosted GPU                                                         | string          | N/A                                         |
| `prefill`                              | Same fields supported in `decode`                                                                                 | See above       | See above                                   |
| `extraObjects`                         | Additional Kubernetes objects to be deployed alongside the main application                                       | List            | []                                          |
