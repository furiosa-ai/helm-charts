# llm-d-modelservice

> [!IMPORTANT]
> The helm chart provided via `furiosa/llm-d-modelservice` is obtained from [`llm-d-incubation/llm-d-modelservice`](https://github.com/llm-d-incubation/llm-d-modelservice). It is modified to support `llm-d` integration of RNGD and Furiosa-LLM. Note that some features supported by the upstream `llm-d-modelservice` Helm repository might not be supported by this Helm chart.
>
> The following feature is currently not supported:
> * P/D Disaggregation

**ModelService** is a Helm chart for deploying Furiosa-LLM model servers on RNGD accelerators and integrating them with the `llm-d` routing ecosystem. This Furiosa variant uses Kubernetes Deployments and supports either the Furiosa device plugin or Dynamic Resource Allocation (DRA).

The ModelService Helm Chart proposal is accepted on June 10, 2025. Read more about the roadmap, motivation, and other alternatives considered [here](https://github.com/llm-d/llm-d/blob/main/docs/proposals/modelservice.md).

TL;DR:

Active scenarios supported:
- Furiosa-LLM serving with tensor, data, and pipeline parallelism
- Independent replicas managed by a Kubernetes Deployment
- Device-plugin or DRA-based RNGD allocation
- Optional OpenTelemetry environment injection

Integration with `llm-d` components:
- Quickstart guide in `llm-d-infra` depends on ModelService
- Flexible configuration of `llm-d-inference-scheduler` for routing

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
>    LeaderWorkerSet is intentionally not included because Furiosa-LLM does not support the cooperative Wide-EP deployment model it requires. Setting this compatibility value to `true` causes chart validation to fail.

Below are the values you can set.
| Key                                          | Description                                                                                                       | Type            | Default                                            |
|----------------------------------------------|-------------------------------------------------------------------------------------------------------------------|-----------------|----------------------------------------------------|
| `modelArtifacts.name`                        | name of model in the form namespace/modelId. Required.                                                            | string          | N/A                                                |
| `modelArtifacts.uri`                         | Model artifacts URI. Current formats supported include `hf://`, `pvc://`, and `oci://`                            | string          | N/A                                                |
| `modelArtifacts.size`                        | Size used to create an emptyDir volume for downloading the model.                                                 | string          | N/A                                                |
| `modelArtifacts.authSecretName`              | The name of the Secret containing `HF_TOKEN` for `hf://` artifacts that require a token for downloading a model.  | string          | N/A                                                |
| `modelArtifacts.mountPath`                   | Path to mount the volume created to store models                                                                  | string          | /model-cache                                       |
| `multinode`                                  | Unsupported compatibility value; `true` causes validation to fail                                                 | bool            | `false`                                            |
| `tracing.enabled`                            | Inject standard OpenTelemetry environment variables into Furiosa-LLM                                              | bool            | `false`                                            |
| `tracing.otlpEndpoint`                       | OTLP endpoint exposed to tracing-capable runtimes                                                                 | string          | `http://otel-collector:4317`                       |
| `routing.servicePort`                        | The port the routing proxy sidecar listens on. <br>If there is no sidecar, this is the port the request goes to.  | int             | N/A                                                |
| `routing.proxy.image`                        | Image used for the dormant P/D routing sidecar                                                                    | string          | `ghcr.io/llm-d/llm-d-router-disagg-sidecar:latest` |
| `routing.proxy.targetPort`                   | The port the Furiosa-LLM container listens on when the proxy is enabled                                           | int             | 8200                                               |
| `routing.proxy.debugLevel`                   | Debug level of the routing proxy                                                                                  | int             | 5                                                  |
| `routing.proxy.parentRefs[*].name`           | The name of the inference gateway                                                                                 | string          | N/A                                                |
| `decode.create`                              | If true, creates the decode Deployment                                                                            | bool            | `true`                                             |
| `decode.annotations`                         | Annotations added to the Deployment                                                                               | Dict            | {}                                                 |
| `decode.tolerations`                         | Tolerations added to decode pods                                                                                  | List            | []                                                 |
| `decode.replicas`                            | Number of replicas for decode pods                                                                                | int             | 1                                                  |
| `decode.extraConfig`                         | Extra pod configuration                                                                                           | dict            | {}                                                 |
| `decode.containers[*].name`                  | Name of the container for the decode Deployment                                                                   | string          | `furiosa-llm`                                      |
| `decode.containers[*].image`                 | Furiosa-LLM container image                                                                                       | string          | N/A                                                |
| `decode.containers[*].args`                  | List of arguments for the decode container.                                                                       | List[string]    | []                                                 |
| `decode.containers[*].modelCommand`          | Nature of the command. One of `furiosaLLMServe`, `imageDefault` or `custom`                                       | string          | `imageDefault`                                     |
| `decode.containers[*].command`               | List of commands for the decode container.                                                                        | List[string]    | []                                                 |
| `decode.containers[*].ports`                 | List of ports for the decode container.                                                                           | List[Port]      | []                                                 |
| `decode.containers[*].extraConfig`           | Extra container configuration                                                                                     | dict            | {}                                                 |
| `decode.initContainers`.                     | List of initContainers that should be added (in addition to routing proxy if enabled)                             | List[Container] | N/A                                                |
| `decode.parallelism.tensor`                  | Amount of tensor parallelism                                                                                      | int             | 8                                                  |
| `decode.parallelism.data`                    | Amount of data parallelism                                                                                        | int             | 1                                                  |
| `decode.parallelism.pipeline`                | Amount of pipeline parallelism                                                                                    | int             | 1                                                  |
| `decode.resourceClaims`                      | Additional non-accelerator DRA claims attached to decode pods                                                     | List            | []                                                 |
| `accelerator.type`                           | Accelerator type; only `furiosa` is supported                                                                     | string          | `furiosa`                                          |
| `accelerator.dra`                            | Use DRA ResourceClaims instead of device-plugin resources                                                         | bool            | `false`                                            |
| `accelerator.resources.furiosa`              | Device-plugin resource name                                                                                       | string          | `furiosa.ai/rngd`                                  |
| `accelerator.resourceClaimTemplates.furiosa` | Furiosa DRA ResourceClaimTemplate settings                                                                        | Dict            | See `values.yaml`                                  |
| `prefill`                                    | Same fields supported in `decode`                                                                                 | See above       | See above                                          |
| `extraObjects`                               | Additional Kubernetes objects to be deployed alongside the main application                                       | List            | []                                                 |

The default accelerator count is calculated per pod as
`ceil(parallelism.data * parallelism.pipeline * parallelism.tensor / 8)`.
In device-plugin mode, the chart fills missing `resources.limits` and
`resources.requests` entries for `furiosa.ai/rngd`; explicit entries take
precedence independently. In DRA mode, the same count is used for the
ResourceClaimTemplate unless `accelerator.resourceClaimTemplates.furiosa.count`
is set explicitly.
