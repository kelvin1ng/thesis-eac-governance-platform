# CHAPTER3_REFERENCE.md §3.2.2 Layer 2: Image policies for Conftest (CI)
# Used by Conftest in pipelines; mirrors Gatekeeper allowlist + digest logic.
# Table 1: Conftest — Execution Plane Verification.

package image

allowed_registries := ["641133458487.dkr.ecr.us-east-1.amazonaws.com", "602401143452.dkr.ecr."]

deny[msg] {
  doc := input[_]
  doc.kind == "Deployment"
  image := doc.spec.template.spec.containers[_].image
  not is_allowed_registry(image)
  msg := sprintf("Image %v is not from allowed registry", [image])
}

deny[msg] {
  doc := input[_]
  doc.kind == "Pod"
  image := doc.spec.containers[_].image
  not is_allowed_registry(image)
  msg := sprintf("Image %v is not from allowed registry", [image])
}

deny[msg] {
  doc := input[_]
  doc.kind == "Deployment"
  image := doc.spec.template.spec.containers[_].image
  not contains(image, "sha256:")
  msg := sprintf("Image %v must use digest (sha256:...)", [image])
}

deny[msg] {
  doc := input[_]
  doc.kind == "Pod"
  image := doc.spec.containers[_].image
  not contains(image, "sha256:")
  msg := sprintf("Image %v must use digest (sha256:...)", [image])
}

is_allowed_registry(image) {
  registry := allowed_registries[_]
  startswith(image, registry)
}
