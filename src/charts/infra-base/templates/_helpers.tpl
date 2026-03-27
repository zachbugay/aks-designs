{{/*
Common labels applied to all infra-base resources.
*/}}
{{- define "infra-base.labels" -}}
app.kubernetes.io/part-of: {{ .Values.namespace }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Secret provider labels for metadata.
*/}}
{{- define "infra-base.secretProvider.labels" -}}
{{ include "infra-base.labels" . }}
app.kubernetes.io/name: kv-tls-secrets
app.kubernetes.io/component: secret-provider
{{- end }}

{{/*
Secrets-sync labels for metadata.
*/}}
{{- define "infra-base.secretsSync.labels" -}}
{{ include "infra-base.labels" . }}
app.kubernetes.io/name: secrets-sync
app.kubernetes.io/component: secrets-sync
{{- end }}

{{/*
Secrets-sync selector labels (subset used in matchLabels).
*/}}
{{- define "infra-base.secretsSync.selectorLabels" -}}
app.kubernetes.io/name: secrets-sync
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
