{{/*
Expand the name of the chart.
*/}}
{{- define "kube-bench-slack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kube-bench-slack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kube-bench-slack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kube-bench-slack.labels" -}}
helm.sh/chart: {{ include "kube-bench-slack.chart" . }}
{{ include "kube-bench-slack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kube-bench-slack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kube-bench-slack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "kube-bench-slack.serviceAccountName" -}}
{{- if .Values.rbac.serviceAccount.name }}
{{- .Values.rbac.serviceAccount.name }}
{{- else }}
{{- include "kube-bench-slack.fullname" . }}
{{- end }}
{{- end }}

{{/*
Create the name of the cluster role
*/}}
{{- define "kube-bench-slack.clusterRoleName" -}}
{{- if .Values.rbac.clusterRole.name }}
{{- .Values.rbac.clusterRole.name }}
{{- else }}
{{- include "kube-bench-slack.fullname" . }}
{{- end }}
{{- end }}

{{/*
Create the name of the cluster role binding
*/}}
{{- define "kube-bench-slack.clusterRoleBindingName" -}}
{{- if .Values.rbac.clusterRoleBinding.name }}
{{- .Values.rbac.clusterRoleBinding.name }}
{{- else }}
{{- include "kube-bench-slack.fullname" . }}
{{- end }}
{{- end }}

{{/*
Create the name of the secret
*/}}
{{- define "kube-bench-slack.secretName" -}}
{{- if kindIs "string" .Values.slack.token }}
{{- printf "%s-slack-credentials" (include "kube-bench-slack.fullname" .) }}
{{- else }}
slack-credentials
{{- end }}
{{- end }}

{{/*
Get the namespace
*/}}
{{- define "kube-bench-slack.namespace" -}}
{{- .Values.namespace.name }}
{{- end }}
