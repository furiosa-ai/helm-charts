{{/*
Expand the name of the chart.
*/}}
{{- define "llm-d-modelservice.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 55 chars because some Kubernetes name fields are limited to 63 (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
We use 55 because we add up to 8 characters (`-prefill`)
*/}}
{{- define "llm-d-modelservice.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 55 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 55 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 55 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
Truncated to 63 characrters because Kubernetes label values are limited to this
*/}}
{{- define "llm-d-modelservice.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create common labels for the resources managed by this chart.
*/}}
{{- define "llm-d-modelservice.labels" -}}
helm.sh/chart: {{ include "llm-d-modelservice.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/* Create sanitized model name (DNS compliant) */}}
{{- define "llm-d-modelservice.sanitizedModelName" -}}
  {{- $name := .Release.Name | lower | trim -}}
  {{- $name = regexReplaceAll "[^a-z0-9_.-]" $name "-" -}}
  {{- $name = regexReplaceAll "^[\\-._]+" $name "" -}}
  {{- $name = regexReplaceAll "[\\-._]+$" $name "" -}}
  {{- $name = regexReplaceAll "\\." $name "-" -}}

  {{- if gt (len $name) 63 -}}
    {{- $name = substr 0 63 $name -}}
  {{- end -}}

{{- $name -}}
{{- end }}

{{/* Create common shared by prefill and decode deployments */}}
{{- define "llm-d-modelservice.pdlabels" -}}
{{ .Values.modelArtifacts.labels | toYaml }}
{{- end }}

{{/* Create labels for the prefill deployment */}}
{{- define "llm-d-modelservice.prefilllabels" -}}
{{ include "llm-d-modelservice.pdlabels" . }}
llm-d.ai/role: prefill
{{- end }}

{{/* Create labels for the decode deployment */}}
{{- define "llm-d-modelservice.decodelabels" -}}
{{ include "llm-d-modelservice.pdlabels" . }}
llm-d.ai/role: decode
{{- end }}

{{/* Create the init container for the routing proxy/sidecar for decode pods */}}
{{- define "llm-d-modelservice.routingProxy" -}}
{{- if or (not (hasKey .proxy "enabled")) (ne .proxy.enabled false) -}}
- name: routing-proxy
  args:
    - --port={{ default 8000 .servicePort }}
    - --model-server-port={{ default 8200 .proxy.targetPort }}
    - --kv-connector={{ .proxy.connector | default "nixlv2" }}
    {{- if hasKey .proxy "zapDevel" }}
    - --zap-devel={{ .proxy.zapDevel }}
    {{- end }}
    {{- if hasKey .proxy "zapEncoder" }}
    - --zap-encoder={{ .proxy.zapEncoder }}
    {{- end }}
    {{- if hasKey .proxy "zapLogLevel" }}
    - --zap-log-level={{ .proxy.zapLogLevel }}
    {{- end }}
    {{- if hasKey .proxy "zapStacktraceLevel" }}
    - --zap-stacktrace-level={{ .proxy.zapStacktraceLevel }}
    {{- end }}
    {{- if hasKey .proxy "zapTimeEncoding" }}
    - --zap-time-encoding={{ .proxy.zapTimeEncoding }}
    {{- end }}
    {{- if hasKey .proxy "secure" }}
    - --secure-proxy={{ .proxy.secure }}
    {{- end }}
    {{- if hasKey .proxy "prefillerUseTLS" }}
    - --prefiller-use-tls={{ .proxy.prefillerUseTLS }}
    {{- end }}
    {{- if hasKey .proxy "certPath" }}
    - --cert-path={{ .proxy.certPath }}
    {{- end }}
  image: {{ required "routing.proxy.image must be specified" .proxy.image }}
  imagePullPolicy: {{ default "Always" .proxy.imagePullPolicy }}
{{- if and .Values.tracing .Values.tracing.enabled }}
  env:
    - name: OTEL_SERVICE_NAME
      value: {{ .Values.tracing.serviceNames.routingProxy | quote }}
    - name: OTEL_EXPORTER_OTLP_ENDPOINT
      value: {{ .Values.tracing.otlpEndpoint | quote }}
    - name: OTEL_TRACES_EXPORTER
      value: "otlp"
    - name: OTEL_TRACES_SAMPLER
      value: {{ .Values.tracing.sampling.sampler | quote }}
    - name: OTEL_TRACES_SAMPLER_ARG
      value: {{ .Values.tracing.sampling.samplerArg | quote }}
{{- end }}
  ports:
    - containerPort: {{ default 8000 .servicePort }}
  {{- if .proxy.resources }}
  resources: {{- toYaml .proxy.resources | nindent 4 }}
  {{- else }}
  resources: {}
  {{- end }}
  restartPolicy: Always
  securityContext:
    allowPrivilegeEscalation: false
    runAsNonRoot: true
{{- end }}
{{- end }}

{{/* Desired tensor parallelism --
- if tensor set, return it
- else return the Furiosa-LLM default of 8
*/}}
{{- define "llm-d-modelservice.tensorParallelism" -}}
{{- if and . (hasKey . "tensor") -}}
{{- if lt (int .tensor) 1 -}}
{{- fail "parallelism.tensor must be greater than zero" -}}
{{- end -}}
{{ .tensor }}
{{- else -}}
8
{{- end -}}
{{- end }}

{{/* Desired per-pod data parallelism; an omitted value defaults to 1. */}}
{{- define "llm-d-modelservice.dataParallelism" -}}
{{- if and . (hasKey . "data") -}}
{{- if lt (int .data) 1 -}}
{{- fail "parallelism.data must be greater than zero" -}}
{{- end -}}
{{ .data }}
{{- else -}}
1
{{- end -}}
{{- end }}

{{/* Desired pipeline parallelism */}}
{{- define "llm-d-modelservice.pipelineParallelism" -}}
{{- if and . (hasKey . "pipeline") -}}
{{- if lt (int .pipeline) 1 -}}
{{- fail "parallelism.pipeline must be greater than zero" -}}
{{- end -}}
{{ .pipeline }}
{{- else -}}
1
{{- end -}}
{{- end }}

{{/* Required number of Furiosa RNGDs per pod -- ceil(dp * pp * tp / 8). */}}
{{- define "llm-d-modelservice.furiosaRngdCountPerPod" -}}
{{- $data := int (include "llm-d-modelservice.dataParallelism" .) -}}
{{- $pipeline := int (include "llm-d-modelservice.pipelineParallelism" .) -}}
{{- $tensor := int (include "llm-d-modelservice.tensorParallelism" .) -}}
{{- div (add (mul $data $pipeline $tensor) 7) 8 -}}
{{- end }}

{{/*
Port on which the inference engine container should listen.
Context is helm root context plus key "role" ("decode" or "prefill")
*/}}
{{- define "llm-d-modelservice.modelServerPort" -}}
{{- if or (eq .role "prefill") (eq .Values.routing.proxy.enabled false) }}
{{- default 8000 .Values.routing.servicePort }}
{{- else }}
{{- .Values.routing.proxy.targetPort }}
{{- end }}
{{- end }}

{{/* Get the Furiosa device-plugin resource name. */}}
{{- define "llm-d-modelservice.acceleratorResource" -}}
{{- if and .Values.accelerator.resources (hasKey .Values.accelerator.resources "furiosa") -}}
{{- index .Values.accelerator.resources "furiosa" -}}
{{- else -}}
furiosa.ai/rngd
{{- end }}
{{- end }}

{{/* Check for accelerator resource mismatch and return warning message if any */}}
{{- define "llm-d-modelservice.acceleratorWarning" -}}
{{- $numAccelerators := int (include "llm-d-modelservice.furiosaRngdCountPerPod" .parallelism) -}}
{{- $acceleratorResource := include "llm-d-modelservice.acceleratorResource" . -}}
{{- if and (ge $numAccelerators 1) (ne $acceleratorResource "") }}
{{- if and .resources .resources.limits (hasKey .resources.limits $acceleratorResource) }}
{{- $userValue := int (index .resources.limits $acceleratorResource) }}
{{- if ne $userValue $numAccelerators }}
{{- printf "Accelerator mismatch: %s is set to %d but parallelism calculates %d. Using %d." $acceleratorResource $userValue $numAccelerators $userValue }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/* P/D deployment container resources */}}
{{- define "llm-d-modelservice.resources" -}}
{{- $limits := dict }}
{{- if and .resources .resources.limits }}
  {{- $limits = deepCopy .resources.limits }}
{{- end }}
{{- $requests := dict }}
{{- if and .resources .resources.requests }}
  {{- $requests = deepCopy .resources.requests }}
{{- end }}
{{- $draEnabled := eq (include "llm-d-modelservice.draEnabled" .) "true" -}}
resources:
{{- if $draEnabled -}}
  {{- /* DRA mode: pass through user-defined limits/requests as-is, add claims */}}
  {{- /* Users should not include accelerator resources in limits when DRA is enabled */}}
  limits:
    {{- toYaml $limits | nindent 4 }}
  requests:
    {{- toYaml $requests | nindent 4 }}
{{- else -}}
  {{- /* Device-plugin mode: default to the calculated per-pod RNGD count. */}}
  {{- $numAccelerators := int (include "llm-d-modelservice.furiosaRngdCountPerPod" .parallelism) -}}
  {{- $acceleratorResource := include "llm-d-modelservice.acceleratorResource" . -}}
  {{- if and (ge (int $numAccelerators) 1) (ne $acceleratorResource "") }}
    {{- /* Respect the user's explicit Furiosa device-plugin limit. */}}
    {{- if not (hasKey $limits $acceleratorResource) }}
      {{- $limits = mergeOverwrite $limits (dict $acceleratorResource (toString $numAccelerators)) }}
    {{- end }}
  {{- end }}
  {{- if and (ge (int $numAccelerators) 1) (ne $acceleratorResource "") }}
    {{- /* Respect the user's explicit Furiosa device-plugin request. */}}
    {{- if not (hasKey $requests $acceleratorResource) }}
      {{- $requests = mergeOverwrite $requests (dict $acceleratorResource (toString $numAccelerators)) }}
    {{- end }}
  {{- end }}
  limits:
    {{- toYaml $limits | nindent 4 }}
  requests:
    {{- toYaml $requests | nindent 4 }}
{{- end -}}
{{- $claimList := include "llm-d-modelservice.resourceClaimsBase" . | fromYamlArray -}}
{{- if $claimList }}
  claims:
  {{- $containerClaims := list -}}
  {{- range $claimList -}}
    {{- $containerClaims = append $containerClaims (dict "name" .name) -}}
  {{- end }}
    {{- toYaml $containerClaims | nindent 4 }}
{{- end }}
{{- end }}

{{/* prefill name */}}
{{- define "llm-d-modelservice.prefillName" -}}
{{ include "llm-d-modelservice.fullname" . }}-prefill
{{- end }}

{{/* decode name */}}
{{- define "llm-d-modelservice.decodeName" -}}
{{ include "llm-d-modelservice.fullname" . }}-decode
{{- end }}

{{/* P/D service account name */}}
{{- define "llm-d-modelservice.pdServiceAccountName" -}}
{{- if or .Values.serviceAccountOverride -}}
{{ .Values.serviceAccountOverride }}
{{- else -}}
{{ include "llm-d-modelservice.fullname" . }}
{{- end -}}
{{- end }}

{{/*
Volumes for PD containers based on model artifact prefix
Context is .Values.modelArtifacts
*/}}
{{- define "llm-d-modelservice.mountModelVolumeVolumes" -}}
{{- $parsedArtifacts := regexSplit "://" .uri -1 -}}
{{- $protocol := first $parsedArtifacts -}}
{{- $path := last $parsedArtifacts -}}
{{- if eq $protocol "hf" -}}
- name: model-storage
  emptyDir:
    sizeLimit: {{ default "0" .size }}
{{/* supports pvc or pvc+hf prefixes */}}
{{- else if hasPrefix "pvc" $protocol }}
{{- $parsedArtifacts := regexSplit "/" $path -1 -}}
{{- $claim := first $parsedArtifacts -}}
- name: model-storage
  persistentVolumeClaim:
    claimName: {{ $claim }}
    readOnly: {{ .readOnly }}
{{- else if eq $protocol "oci" }}
- name: model-storage
  image:
    reference: {{ $path }}
    pullPolicy: {{ default "Always" .imagePullPolicy }}
{{- end }}
{{- end }}

{{/*
VolumeMount for a PD container
Supplies model-storage mount if mountModelVolume: true for the container
*/}}
{{- define "llm-d-modelservice.mountModelVolumeVolumeMounts" -}}
{{- if or .container.volumeMounts .container.mountModelVolume }}
volumeMounts:
{{- end }}
{{- /* user supplied volume mount in values */}}
{{- with .container.volumeMounts }}
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- /* what we add if mounModelVolume is true */}}
{{- if .container.mountModelVolume }}
  - name: model-storage
    mountPath: {{ .Values.modelArtifacts.mountPath }}
{{- /* OCI always readOnly; PVC variants use modelArtifacts.readOnly */}}
{{- $parsedArtifacts := regexSplit "://" .Values.modelArtifacts.uri -1 -}}
{{- $protocol := first $parsedArtifacts -}}
{{- if eq $protocol "oci" }}
    readOnly: true
{{- else if hasPrefix "pvc" $protocol }}
    readOnly: {{ .Values.modelArtifacts.readOnly }}
{{- end -}}
{{- end }}
{{- end }}

{{/*
Pod elements of Deployment spec template
context is a pdSpec
*/}}
{{- define "llm-d-modelservice.modelPod" -}}
  {{- with .pdSpec.extraConfig }}
    {{ include "common.tplvalues.render" ( dict "value" . "context" $ ) | nindent 2 }}
  {{- end }}
  {{- /* DEPRECATED; use extraConfig.imagePullSecrets instead */ -}}
  {{- with .pdSpec.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 2 }}
  {{- end }}
  {{- /* DEPRECATED; use extraConfig.scheulerName instead */ -}}
  {{- if or .pdSpec.schedulerName .Values.schedulerName }}
  schedulerName: {{ .pdSpec.schedulerName | default .Values.schedulerName }}
  {{- end }}
  {{- if and .pdSpec.priorityClassName (ne (.pdSpec.priorityClassName | lower) "none") }}
  priorityClassName: {{ .pdSpec.priorityClassName }}
  {{- end }}
  {{- /* DEPRECATED; use extraConfig.securityContext instead */ -}}
  {{- with .pdSpec.podSecurityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  serviceAccountName: {{ include "llm-d-modelservice.pdServiceAccountName" . }}
  {{- /* define volume for the pd pod. Create a volume depending on the model artifact uri type */}}
  volumes:
  {{- if or .pdSpec.volumes }}
    {{- toYaml .pdSpec.volumes | nindent 4 }}
  {{- end -}}
  {{- /* create volume if at least one of the containers in pdSpec has mountModelVolume: true */ -}}
  {{- $hasModelVolume := false }}
  {{- range .pdSpec.containers }}
    {{- if .mountModelVolume }}
      {{- $hasModelVolume = true }}
    {{- end -}}
  {{- end -}}
  {{- if $hasModelVolume }}
  {{ include "llm-d-modelservice.mountModelVolumeVolumes" .Values.modelArtifacts | nindent 4}}
  {{- end -}}
  {{- /* Add resourceClaims for DRA (new and old API) */}}
  {{- include "llm-d-modelservice.podResourceClaims" . | nindent 2 }}
{{- end }}

{{/*
Container elements of Deployment spec template
context is a dict with helm root context plus:
   key - "container"; value - container spec
   key - "role"; value - either "decode" or "prefill"
   key - "parallelism"; value - $.Values.decode.parallelism
*/}}
{{- define "llm-d-modelservice.container" -}}
- name: {{ default "furiosa-llm" .container.name }}
  image: {{ required "image of container is required" .container.image }}
  {{- with .container.extraConfig }}
    {{ include "common.tplvalues.render" ( dict "value" . "context" $ ) | nindent 2 }}
  {{- end }}
  {{- /* DEPRECATED; use extraConfig.securityContext instead */ -}}
  {{- with .container.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- /* DEPRECATED; use extraConfig.imagePullPolicy instead */ -}}
  {{- with .container.imagePullPolicy }}
  imagePullPolicy: {{ . }}
  {{- end }}
  {{- /* handle command and args */}}
  {{- include "llm-d-modelservice.command" . | nindent 2 }}
  {{- /* insert user's env for this container */}}
  env:
  {{- with .container.env }}
    {{- include "common.tplvalues.render" ( dict "value" . "context" $ ) | nindent 2 }}
  {{- end }}
  {{- (include "llm-d-modelservice.parallelismEnv" .) | nindent 2 }}
  {{- /* insert envs based on what modelArtifact prefix */}}
  {{- (include "llm-d-modelservice.hfEnv" .) | nindent 2 }}
  {{- /* Add tracing environment variables */}}
  {{- (include "llm-d-modelservice.tracingEnv" .) | nindent 2 }}
  {{- with .container.ports }}
  ports:
    {{- include "common.tplvalues.render" ( dict "value" . "context" $ ) | nindent 2 }}
  {{- end }}
  {{- /* DEPRECATED; use extraConfig.livenessProbe instead */ -}}
  {{- with .container.livenessProbe }}
  livenessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- /* DEPRECATED; use extraConfig.readinessProbe instead */ -}}
  {{- with .container.readinessProbe }}
  readinessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- /* DEPRECATED; use extraConfig.startupProbe instead */ -}}
  {{- with .container.startupProbe }}
  startupProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- (include "llm-d-modelservice.resources" (dict "resources" .container.resources "parallelism" .parallelism "container" .container "Values" .Values "role" .role "pdSpec" .pdSpec)) | nindent 2 }}
  {{- include "llm-d-modelservice.mountModelVolumeVolumeMounts" (dict "container" .container "Values" .Values) | nindent 2 }}
  {{- /* DEPRECATED; use extraConfig.workingDir instead */ -}}
  {{- with .container.workingDir }}
  workingDir: {{ . }}
  {{- end }}
  {{- /* DEPRECATED; use extraConfig.stdin instead */ -}}
  {{- with .container.stdin }}
  stdin: {{ . }}
  {{- end }}
  {{- /* DEPRECATED; use extraConfig.tty instead */ -}}
  {{- with .container.tty }}
  tty: {{ . }}
  {{- end }}
{{- end }} {{- /* define "llm-d-modelservice.container" */}}

{{- define "llm-d-modelservice.argsByProtocol" -}}
{{- $parsedArtifacts := regexSplit "://" .Values.modelArtifacts.uri -1 -}}
{{- $protocol := first $parsedArtifacts -}}
{{- $other := last $parsedArtifacts -}}
{{- if eq $protocol "hf" -}}
{{- /* $other is the the model */}}
  {{- if .modelArg }}
  - --model
  {{- end }}
  - {{ include "common.tplvalues.render" ( dict "value" $other "context" $ ) }}
{{- else if eq $protocol "pvc" }}
{{- /* $other is the PVC claim and the path to the model */}}
{{- $claimpath := regexSplit "/" $other 2 -}}
{{- $path := last $claimpath -}}
  {{- if .modelArg }}
  - --model
  {{- end }}
  - {{ trimSuffix "/" .Values.modelArtifacts.mountPath }}/{{ $path }}
{{- else if eq $protocol "pvc+hf" }}
{{- $claimpath := regexSplit "/" $other -1 -}}
{{- $length := len $claimpath }}
{{- $namespace := index $claimpath (sub $length 2) -}}
{{- $modelID := last $claimpath -}}
  {{- if .modelArg }}
  - --model
  {{- end }}
  - {{ $namespace }}/{{ $modelID }}
{{- else if eq $protocol "oci" }}
{{- /* TBD */}}
{{- fail "arguments for oci:// not implemented" }}
{{- end }}
{{- end }} {{- /* define "llm-d-modelservice.argsByProtocol" */}}

{{- define "llm-d-modelservice.furiosaLLMServeModelCommand" -}}
{{- $tensorParallelism := int (include "llm-d-modelservice.tensorParallelism" .parallelism) -}}
{{- $dataParallelism := int (include "llm-d-modelservice.dataParallelism" .parallelism) -}}
{{- $pipelineParallelism := int (include "llm-d-modelservice.pipelineParallelism" .parallelism) -}}
command: ["furiosa-llm", "serve"]
args:
{{- (include "llm-d-modelservice.argsByProtocol" .) }}
  - --port
  - {{ (include "llm-d-modelservice.modelServerPort" .) | quote }}
  - --tensor-parallel-size
  - {{ $tensorParallelism | quote }}
  - --data-parallel-size
  - {{ $dataParallelism | quote }}
  - --pipeline-parallel-size
  - {{ $pipelineParallelism | quote }}
{{- with .container.args }}
  {{ toYaml . | nindent 2 }}
{{- end }}
{{- end }} {{- /* define "llm-d-modelservice.furiosaLLMServeModelCommand" */}}

{{- define "llm-d-modelservice.customModelCommand" -}}
{{- /* use provided command and args (fail if no command) */}}
{{- if not .container.command }}
{{- fail "When .container.modelCommand not set or `custom`, a `command` is required." }}
{{- else }}
{{- with .container.command }}
command:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .container.args }}
args:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- end }} {{- /* define "llm-d-modelservice.modelCommandCustom" */}}

{{/*
Container elements of Deployment spec template
context is a dict with helm root context plus:
   key - "container"; value - container spec
   key - "role"; value - either "decode" or "prefill"
   key - "parallelism"; value - $.Values.decode.parallelism
*/}}
{{- define "llm-d-modelservice.command" -}}
{{- $modelCommand := default "custom" .container.modelCommand -}}
{{- if eq $modelCommand "furiosaLLMServe" }}
{{- include "llm-d-modelservice.furiosaLLMServeModelCommand" . }}
{{- else if eq $modelCommand "custom" }}
{{- include "llm-d-modelservice.customModelCommand" . }}
{{- else }}
{{- fail ".container.modelCommand is not as expected. Valid values are `furiosaLLMServe` and `custom`." }}
{{- end }}
{{- end }} {{- /* define "llm-d-modelservice.command" */}}

{{- define "llm-d-modelservice.hfEnv" -}}
{{- $parsedArtifacts := regexSplit "://" .Values.modelArtifacts.uri -1 -}}
{{- $protocol := first $parsedArtifacts -}}
{{- $other := last $parsedArtifacts -}}
{{- if contains "hf" $protocol }}
{{- if eq $protocol "hf" }}
{{- if .container.mountModelVolume }}
- name: HF_HOME
  value: {{ .Values.modelArtifacts.mountPath }}
{{- end }}
{{- end }}
{{- if eq $protocol "pvc+hf" }}
{{- $claimpath := regexSplit "/" $other -1 -}}
{{- $length := len $claimpath }}
{{- $start := 1 }}
{{- $end := sub $length 2 }}
{{- $middle := slice $claimpath $start $end }}
{{- $hfhubcache := join "/" $middle }}
{{- if .container.mountModelVolume }}
- name: HF_HUB_CACHE
  value: {{ trimSuffix "/" .Values.modelArtifacts.mountPath }}/{{ $hfhubcache }}
{{- end }}
{{- end }}
{{- end }}
{{- with .Values.modelArtifacts.authSecretName }}
- name: HF_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ . }}
      key: HF_TOKEN
{{- end }}
{{- end }} {{- /* define "llm-d-modelservice.hfEnv" */}}

{{- define "llm-d-modelservice.parallelismEnv" -}}
- name: DP_SIZE
  value: {{ include "llm-d-modelservice.dataParallelism" .parallelism | quote }}
- name: TP_SIZE
  value: {{ include "llm-d-modelservice.tensorParallelism" .parallelism | quote }}
- name: PP_SIZE
  value: {{ include "llm-d-modelservice.pipelineParallelism" .parallelism | quote }}
{{- end }} {{- /* define "llm-d-modelservice.parallelismEnv" */}}

{{/*
Standard OpenTelemetry environment variables for Furiosa-LLM containers.
This is manifest-level configuration only; OTLP export depends on runtime/SDK support.
Requires: .Values.tracing, .role ("decode" or "prefill")
Returns: YAML list of environment variables if tracing is enabled, empty otherwise
*/}}
{{- define "llm-d-modelservice.tracingEnv" -}}
{{- if and .Values.tracing .Values.tracing.enabled }}
{{- $serviceName := "" }}
{{- if eq .role "decode" }}
  {{- $serviceName = .Values.tracing.serviceNames.furiosaLLMDecode }}
{{- else if eq .role "prefill" }}
  {{- $serviceName = .Values.tracing.serviceNames.furiosaLLMPrefill }}
{{- end }}
- name: OTEL_SERVICE_NAME
  value: {{ $serviceName | quote }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ .Values.tracing.otlpEndpoint | quote }}
- name: OTEL_TRACES_EXPORTER
  value: "otlp"
- name: OTEL_TRACES_SAMPLER
  value: {{ .Values.tracing.sampling.sampler | quote }}
- name: OTEL_TRACES_SAMPLER_ARG
  value: {{ .Values.tracing.sampling.samplerArg | quote }}
{{- end }}
{{- end }} {{- /* define "llm-d-modelservice.tracingEnv" */}}
