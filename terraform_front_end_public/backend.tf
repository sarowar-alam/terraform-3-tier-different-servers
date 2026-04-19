# ============================================================================
# Remote State Backend — S3
#
# Initialise with:
#   terraform init \
#     -backend-config="bucket=YOUR_BUCKET_NAME" \
#     -backend-config="profile=sarowar-ostad"
#
# Or create a file called backend-config.tfbackend (already git-ignored):
#   bucket  = "your-s3-bucket"
#   profile = "sarowar-ostad"
# Then run:
#   terraform init -backend-config=backend-config.tfbackend
# ============================================================================

terraform {
  backend "s3" {
    key     = "fpub-trfm/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true
    # bucket  — provided at init time via -backend-config flag
    # profile — provided at init time via -backend-config flag
  }
}
