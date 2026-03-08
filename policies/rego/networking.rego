# CHAPTER3_REFERENCE.md §3.2.2 Layer 2: Firewall networking for Conftest (CI) [44]
# Privileged, hostNetwork, capabilities. Table 1: Conftest.

package networking

allowed_caps := {"NET_RAW", "NET_ADMIN"}

deny[msg] {
  doc := input[_]
  doc.kind == "Deployment"
  doc.spec.template.spec.securityContext.privileged == true
  msg := "Privileged mode is not allowed"
}

deny[msg] {
  doc := input[_]
  doc.kind == "Deployment"
  doc.spec.template.spec.containers[_].securityContext.privileged == true
  msg := "Container privileged mode is not allowed"
}

deny[msg] {
  doc := input[_]
  doc.kind == "Deployment"
  doc.spec.template.spec.hostNetwork == true
  msg := "Host networking is not allowed"
}

deny[msg] {
  doc := input[_]
  doc.kind == "Deployment"
  cap := doc.spec.template.spec.containers[_].securityContext.capabilities.add[_]
  not allowed_caps[cap]
  msg := sprintf("Capability %v not allowed; only NET_RAW, NET_ADMIN", [cap])
}

deny[msg] {
  doc := input[_]
  doc.kind == "Pod"
  doc.spec.securityContext.privileged == true
  msg := "Privileged mode is not allowed"
}

deny[msg] {
  doc := input[_]
  doc.kind == "Pod"
  doc.spec.containers[_].securityContext.privileged == true
  msg := "Container privileged mode is not allowed"
}

deny[msg] {
  doc := input[_]
  doc.kind == "Pod"
  doc.spec.hostNetwork == true
  msg := "Host networking is not allowed"
}
