{{/*
CHAPTER3_REFERENCE.md §3.0: Helm helpers for firewall chart
*/}}
{{- define "firewall.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "firewall.fullname" -}}
{{- default (printf "%s-%s" .Release.Name .Chart.Name) .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- define "firewall.image" -}}
{{- if .Values.image.digest }}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest }}
{{- else if .Values.image.tag }}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository .Chart.AppVersion }}
{{- end }}
{{- end }}
