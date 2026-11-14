# Object storage (ADR-0026, CHG-0069): a bucket of this tenant's own, and a
# read-only key for a workload that only serves its objects.
#
# The platform stores the bucket and does not back it up: keep your own copy of
# anything you can't re-derive. The quota is enforced about a minute behind:
# a single-part upload larger than it is refused at once, but a multipart upload
# (how most clients send a large object) is counted only after it completes.

resource "deevnet_bucket" "files" {
  tenant     = deevnet_tenant.this.name
  name       = "files"
  quota_gb   = 1
  versioning = true

  # Not "lifecycle": Terraform reserves that name.
  object_lifecycle {
    noncurrent_expire_days = 30
  }
}

resource "deevnet_bucket_key" "files_reader" {
  tenant = deevnet_tenant.this.name
  bucket = deevnet_bucket.files.name
  name   = "reader"
  access = "read"
}
