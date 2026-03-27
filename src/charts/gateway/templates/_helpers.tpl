{{/*
Common labels applied to all gateway resources.
*/}}
{{- define "gateway.labels" -}}
app.kubernetes.io/part-of: gateway
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
ALB labels for metadata.
*/}}
{{- define "gateway.alb.labels" -}}
{{ include "gateway.labels" . }}
app.kubernetes.io/name: alb-test
app.kubernetes.io/component: load-balancer
{{- end }}

{{/*
Gateway resource labels for metadata.
*/}}
{{- define "gateway.gateway.labels" -}}
{{ include "gateway.labels" . }}
app.kubernetes.io/name: agc-gateway
app.kubernetes.io/component: gateway
{{- end }}

{{/*
Frontend TLS policy labels for metadata.
*/}}
{{- define "gateway.tlsPolicy.labels" -}}
{{ include "gateway.labels" . }}
app.kubernetes.io/name: mtls-policy
app.kubernetes.io/component: tls-policy
{{- end }}

{{/*
Keycloak HTTPRoute labels for metadata.
*/}}
{{- define "gateway.routeKeycloak.labels" -}}
{{ include "gateway.labels" . }}
app.kubernetes.io/name: route-keycloak
app.kubernetes.io/component: route
{{- end }}
