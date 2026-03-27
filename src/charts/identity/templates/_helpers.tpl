{{/*
Common labels applied to all resources.
*/}}
{{- define "identity.labels" -}}
app.kubernetes.io/part-of: identity
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Keycloak labels for metadata.
*/}}
{{- define "identity.keycloak.labels" -}}
{{ include "identity.labels" . }}
app.kubernetes.io/name: keycloak
app.kubernetes.io/component: keycloak
app.kubernetes.io/version: {{ .Values.keycloak.image.tag | quote }}
{{- end }}

{{/*
Keycloak selector labels (subset used in matchLabels and service selectors).
*/}}
{{- define "identity.keycloak.selectorLabels" -}}
app.kubernetes.io/name: keycloak
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Postgres labels for metadata.
*/}}
{{- define "identity.postgres.labels" -}}
{{ include "identity.labels" . }}
app.kubernetes.io/name: postgres
app.kubernetes.io/component: postgres
app.kubernetes.io/version: {{ .Values.postgres.image.tag | quote }}
{{- end }}

{{/*
Postgres selector labels (subset used in matchLabels and service selectors).
*/}}
{{- define "identity.postgres.selectorLabels" -}}
app.kubernetes.io/name: postgres
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
