{{/*
Create the name of the ServiceAccount to use.
*/}}
{{- define "jenkins.rbacFullname" -}}
{{- if .create -}}
  {{ default (printf "%s-%s" (include "jenkins.fullname" .) .name) .resourceName }}
{{- else -}}
  {{ default "default" .resourceName }}
{{- end -}}
{{- end -}}

{{/*
Create a ServiceAccount.
*/}}
{{- define "jenkins.serviceAccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "jenkins.rbacFullname" . }}
  labels:
  {{- if eq .name "master" -}}
    {{- include "jenkins.masterLabels" . | nindent 4 }}
  {{- else }}
    {{- include "jenkins.agentLabels" . | nindent 4 }}
  {{- end }}
{{- end -}}

{{/*
Create a ClusterRole.
*/}}
{{- define "jenkins.clusterRole" -}}
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: {{ include "jenkins.fullname" . }}-{{ .name }}
  labels:
  {{- if eq .name "master" -}}
    {{- include "jenkins.masterLabels" . | nindent 4 }}
  {{- else }}
    {{- include "jenkins.agentLabels" . | nindent 4 }}
  {{- end }}
rules:
{{- with .rules -}}
  {{ toYaml . | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
Create a ClusterRoleBinding.
*/}}
{{- define "jenkins.clusterRoleBinding" -}}
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: {{ include "jenkins.fullname" . }}-{{ .name }}
  labels:
  {{- if eq .name "master" -}}
    {{- include "jenkins.masterLabels" . | nindent 4 }}
  {{- else }}
    {{- include "jenkins.agentLabels" . | nindent 4 }}
  {{- end }}
subjects:
  - kind: ServiceAccount
    name: {{ include "jenkins.rbacFullname" . }}
    namespace: {{ .Release.Namespace }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: {{ if .rules }}{{ include "jenkins.fullname" . }}-{{ .name }}{{- else }}cluster-admin{{ end }}
{{- end -}}
