# Note: Configure GCS backend for state management
# Create a GCS bucket in your GCP project first, then run:
# 
# terraform init -backend-config="bucket=YOUR_STATE_BUCKET_NAME"
#
# Or use terraform.tfvars to set the bucket:
# 
# gcs_bucket = "your-terraform-state-bucket"
#
# For local development, you can comment out the backend configuration
# and use local state by creating a local.tfvars file

# Uncomment this block and set the bucket name when ready for production
# terraform {
#   backend "gcs" {
#     bucket = "your-terraform-state-bucket"
#     prefix = "terraform/state"
#   }
# }
