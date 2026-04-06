{{/*
Expand the name of the chart.
*/}}
{{- define "my-nginx-chart.name" -}}
{{- .Chart.Name }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "my-nginx-chart.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "my-nginx-chart.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "my-nginx-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "my-nginx-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-nginx-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
