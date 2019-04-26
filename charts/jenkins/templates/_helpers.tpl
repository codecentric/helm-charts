{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "jenkins.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "jenkins.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "jenkins.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account to use.
*/}}
{{- define "jenkins.serviceAccountName" -}}
{{- $context := dict "Values" .Values "Chart" .Chart "Release" .Release }}
{{- $_ := set $context "name" "master" }}
{{- $_ := set $context "create" .Values.serviceAccount.master.create }}
{{- $_ := set $context "resourceName" .Values.serviceAccount.master.name }}
{{- include "jenkins.rbacFullname" $context }}
{{- end -}}

{{/*
{{/*
Create common labels.
*/}}
{{- define "jenkins.commonLabels" -}}
app.kubernetes.io/name: {{ include "jenkins.name" . }}
helm.sh/chart: {{ include "jenkins.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Create master labels.
*/}}
{{- define "jenkins.masterLabels" -}}
{{ include "jenkins.commonLabels" . }}
app.kubernetes.io/component: master
{{- end -}}

{{/*
Create test labels.
*/}}
{{- define "jenkins.testLabels" -}}
{{ include "jenkins.commonLabels" . }}
app.kubernetes.io/component: test
{{- end -}}

{{/*
Create agent labels.
*/}}
{{- define "jenkins.agentLabels" -}}
{{ include "jenkins.commonLabels" . }}
app.kubernetes.io/component: {{ .name }}
{{- end -}}

{{/*
Create the label selector.
*/}}
{{- define "jenkins.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jenkins.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: master
{{- end -}}

{{/*
Create the suffix for an init configmap. Needs a .Values.referenceContent' list item as context.
*/}}
{{- define "jenkins.configmapSuffix" -}}
{{- default "home" .relativeDir | replace "." "-" -}}
{{- end -}}

{{/*
Create checksum annotions so the pod is recreated when the confis change.
*/}}
{{- define "jenkins.configChecksumAnnotations" -}}
checksum/init: {{ include (print $.Template.BasePath "/configmap-init.yaml") . | sha256sum }}
{{- $refList := list -}}
{{- range .Values.referenceContent }}
  {{- range $key, $value := .data -}}
    {{- $refList = append $refList .fileName -}}
    {{- $refList = append $refList (tpl .fileContent $) -}}
  {{- end -}}
{{- end }}
checksum/ref: {{ join "" $refList | sha256sum }}
{{- end -}}

{{/*
Create the ingress url of Jenkins.
*/}}
{{- define "jenkins.ingressUrl" -}}
{{- with .Values.ingress }}
  {{- if .enabled -}}
    http{{ if .tls }}s{{ end }}://{{ .host }}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create the name for the casc secret.
*/}}
{{- define "jenkins.cascSecret" -}}
{{- if .Values.casc.existingSecret -}}
  {{- .Values.casc.existingSecret -}}
{{- else -}}
  {{- include "jenkins.fullname" . }}-casc
{{- end -}}
{{- end -}}

