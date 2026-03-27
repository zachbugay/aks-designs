{{/*
Common labels applied to all tenant resources.
*/}}
{{- define "tenant.labels" -}}
app.kubernetes.io/part-of: {{ .Values.tenantName }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Service (API) labels for metadata.
*/}}
{{- define "tenant.service.labels" -}}
{{ include "tenant.labels" . }}
app.kubernetes.io/name: {{ .Values.service.name }}
app.kubernetes.io/component: api
app.kubernetes.io/version: {{ .Values.service.tag | quote }}
{{- end }}

{{/*
Service (API) selector labels.
*/}}
{{- define "tenant.service.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.service.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
React app labels for metadata.
*/}}
{{- define "tenant.reactApp.labels" -}}
{{ include "tenant.labels" . }}
app.kubernetes.io/name: {{ .Values.reactApp.name }}
app.kubernetes.io/component: frontend
app.kubernetes.io/version: {{ .Values.reactApp.tag | quote }}
{{- end }}

{{/*
React app selector labels.
*/}}
{{- define "tenant.reactApp.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.reactApp.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
