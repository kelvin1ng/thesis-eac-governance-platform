# CHAPTER3_REFERENCE.md §3.2.2 Layer 2: Traceability labels for Conftest (CI)
# Required: owner, environment, compliance-scope. Table 1: Conftest.

package labels

required_labels := ["owner", "environment", "compliance-scope"]

deny[msg] {
  doc := input[_]
  doc.kind == "Deployment"
  required := required_labels[_]
  not doc.metadata.labels[required]
  msg := sprintf("Deployment must have label %q", [required])
}

deny[msg] {
  doc := input[_]
  doc.kind == "Deployment"
  required := required_labels[_]
  not doc.spec.template.metadata.labels[required]
  msg := sprintf("Deployment pod template must have label %q", [required])
}

deny[msg] {
  doc := input[_]
  doc.kind == "Pod"
  required := required_labels[_]
  not doc.metadata.labels[required]
  msg := sprintf("Pod must have label %q", [required])
}
