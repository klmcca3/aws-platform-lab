# Private S3 bucket holding the app package. The app servers download it at boot
# through the S3 gateway endpoint (no internet needed).

resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "lab-artifacts-" # AWS adds a unique suffix
  force_destroy = true             # lets the nightly destroy remove it even with files inside
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

locals {
  # Version the app by its SOURCE files, not by the zip's bytes. The zip built on a Mac and
  # the zip built on GitHub's Linux runners are never byte-identical, but the source in Git is.
  # Same source anywhere -> same version -> no unnecessary redeploys.
  app_source_hash = md5(join("", [
    filemd5("${path.module}/../app/app.py"),
    filemd5("${path.module}/../app/requirements.txt"),
    filemd5("${path.module}/../app/build.sh"),
  ]))
}/../app/app.zip")
}

# Uploads app.zip, and re-uploads only when the app's source changes.
resource "aws_s3_object" "app" {
  bucket      = aws_s3_bucket.artifacts.id
  key         = "app/app.zip"
  source      = "${path.module}/../app/app.zip"
  source_hash = local.app_source_hash
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.id
}
