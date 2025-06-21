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


bucket-name      = "subhamay-git-sec-ops-cicd-bucket-06611-81"
project-name     = "gha-tmpl"
environment-name = "devl"

## Uncomment the following lines to use S3 as the backend for Terraform state management when running locally.
## For GitHub Actions, the backend is configured in the workflow file.

# tf-state-bucket  = "subhamay-tf-state-637423502513-devl-us-east-1"