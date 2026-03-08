# CHAPTER3_REFERENCE.md §3.1 Immutability, §3.6 Table 3 (artifact tampering)
# ECR with image_tag_mutability = IMMUTABLE: digest-only refs, registry immutability [18], [28].

resource "aws_ecr_repository" "firewall" {
  name                 = "${var.project_name}/firewall"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}
