## =====================================================================================================================
## 📁 Project Name        : Terraform GitHub Template Repository
## 📝 Description         : A reusable template for setting up Terraform-based Infrastructure-as-Code (IaC) projects
##                         on GitHub using GitHub Actions for CI/CD automation.
##
## 🔄 Modification History:
##   Version   Date          Author     Description
##   -------   ------------  --------   -------------------------------------------------------------------------------
##   1.0.0     Jun 20, 2025  Subhamay   Initial version with GitHub Actions workflow for Terraform CI/CD
##
## =====================================================================================================================

# --- root/main.tf ---

resource "aws_s3_bucket" "s3_bucket" {
  bucket = local.bucket-name

  tags = {
    environment          = var.environment-name
    Owner                = "subhamay.aws@gmail.com"
  }
}