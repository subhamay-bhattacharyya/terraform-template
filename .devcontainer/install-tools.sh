#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="install-tools.log"
SUMMARY_FILE="${SUMMARY_FILE:-install-summary.json}"
VERSIONS_FILE="${VERSIONS_FILE:-.tool-versions.json}"
DRY_RUN=false
INSTALL_TOOLS=(all)

for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      echo "[Dry Run] No changes will be made. Commands will be printed only."
      ;;
    --tools=*)
      IFS=',' read -ra INSTALL_TOOLS <<< "${arg#*=}"
      ;;
    --summary-path=*)
      SUMMARY_FILE="${arg#*=}"
      ;;
  esac
done

exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SUMMARY_JSON="{}"
EXPECTED_JSON="{}"

if [[ -f "$VERSIONS_FILE" ]]; then
  EXPECTED_JSON=$(<"$VERSIONS_FILE")
fi

log_step() {
  echo -e "\n${YELLOW}🔧 $(date '+%Y-%m-%d %H:%M:%S') - $1${NC}"
}

run_cmd() {
  log_step "$1"
  shift
  if $DRY_RUN; then
    echo "[Dry Run] $*"
  else
    if "$@"; then
      echo -e "${GREEN}✅ Success: $1${NC}"
    else
      echo -e "${RED}❌ Failed: $1${NC}"
      exit 1
    fi
  fi
}

add_summary() {
  local name=$1
  local version=$2
  SUMMARY_JSON=$(echo "$SUMMARY_JSON" | jq --arg name "$name" --arg ver "$version" '. + {($name): $ver}')

  local expected_version
  expected_version=$(echo "$EXPECTED_JSON" | jq -r --arg name "$name" '.[$name] // empty')

  if [[ -n "$expected_version" && "$version" != "$expected_version" ]]; then
    echo -e "${RED}⚠️ Version mismatch for $name: expected $expected_version, got $version${NC}"
  fi
}

get_expected_version() {
  local name=$1
  echo "$EXPECTED_JSON" | jq -r --arg name "$name" '.[$name] // empty'
}

should_run() {
  [[ " ${INSTALL_TOOLS[*]} " =~ " all " || " ${INSTALL_TOOLS[*]} " =~ " $1 " ]]
}

# OS dependencies
log_step "Installing OS dependencies"
run_cmd "Install OS dependencies" sudo apt-get update -y && sudo apt-get install -y \
  curl unzip git jq gnupg software-properties-common ca-certificates lsb-release tar build-essential

# Terraform
if should_run terraform; then
  log_step "Installing Terraform"
  version=$(get_expected_version terraform)
  if ! $DRY_RUN; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
      | sudo tee /etc/apt/sources.list.d/hashicorp.list
  fi
  run_cmd "Install Terraform" sudo apt-get update && sudo apt-get install -y terraform
  TERRAFORM_VERSION=$(terraform version -json | jq -r .terraform_version)
  add_summary terraform "$TERRAFORM_VERSION"
fi

# AWS CLI
if should_run awscli; then
  log_step "Installing AWS CLI"
  run_cmd "Download AWS CLI" curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  run_cmd "Unzip AWS CLI" unzip awscliv2.zip
  run_cmd "Install AWS CLI" sudo ./aws/install
  rm -rf awscliv2.zip aws
  AWS_VERSION=$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)
  add_summary awscli "$AWS_VERSION"
fi

# Terraform Docs
if should_run terraform-docs; then
  log_step "Installing terraform-docs"
  version=$(get_expected_version terraform-docs)
  version="${version:-0.12.0}"
  run_cmd "Download terraform-docs" curl -sLo terraform-docs.tar.gz "https://github.com/terraform-docs/terraform-docs/releases/download/v${version}/terraform-docs-v${version}-$(uname)-amd64.tar.gz"
  run_cmd "Extract terraform-docs" tar -xzf terraform-docs.tar.gz
  run_cmd "Move terraform-docs" sudo mv terraform-docs /usr/local/bin/
  rm terraform-docs.tar.gz
  TERRADOCS_VERSION=$(terraform-docs --version | awk '{print $2}')
  add_summary terraform-docs "$TERRADOCS_VERSION"
fi

# Terragrunt
if should_run terragrunt; then
  log_step "Installing Terragrunt"
  version=$(get_expected_version terragrunt)
  if [[ -z "$version" ]]; then
    version=$(curl -s https://api.github.com/repos/gruntwork-io/terragrunt/releases/latest | jq -r .tag_name)
  fi
  run_cmd "Download Terragrunt" curl -Lo terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/${version}/terragrunt_$(uname -s)_amd64"
  run_cmd "Install Terragrunt" chmod +x terragrunt && sudo mv terragrunt /usr/local/bin/
  add_summary terragrunt "$version"
fi

# Install tools with curl | sh style + move + version extraction
install_go_tool() {
  local name=$1
  local path=$2
  local version
  version=$(get_expected_version "$name")
  version="${version:-latest}"
  run_cmd "Install $name" go install "${path}@${version}"
  run_cmd "Move $name" sudo mv ~/go/bin/$name /usr/local/bin/
  eval "$3"
}

# Terrascan
if should_run terrascan; then
  log_step "Installing Terrascan"
  run_cmd "Install Terrascan" curl -s https://runterrascan.io/install.sh | bash
  run_cmd "Move Terrascan" sudo mv terrascan /usr/local/bin/
  TERRASCAN_VERSION=$(terrascan version | head -n1 | awk '{print $3}')
  add_summary terrascan "$TERRASCAN_VERSION"
fi

# TFLint
if should_run tflint; then
  log_step "Installing TFLint"
  run_cmd "Install TFLint" curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
  run_cmd "Move TFLint" sudo mv tflint /usr/local/bin/
  TFLINT_VERSION=$(tflint --version | head -n1 | awk '{print $2}')
  add_summary tflint "$TFLINT_VERSION"
fi

# TFSec
if should_run tfsec; then
  log_step "Installing TFSec"
  run_cmd "Download tfsec" curl -sLo tfsec "https://github.com/aquasecurity/tfsec/releases/latest/download/tfsec-$(uname)-amd64"
  run_cmd "Install tfsec" chmod +x tfsec && sudo mv tfsec /usr/local/bin/
  TFSEC_VERSION=$(tfsec --version | awk '{print $3}')
  add_summary tfsec "$TFSEC_VERSION"
fi

# Trivy
if should_run trivy; then
  log_step "Installing Trivy"
  version=$(get_expected_version trivy)
  version="${version:-latest}"
  run_cmd "Install Trivy" curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin "$version"
  TRIVY_VER=$(trivy --version | head -n1 | awk '{print $2}')
  add_summary trivy "$TRIVY_VER"
fi

# Infracost
if should_run infracost; then
  log_step "Installing Infracost"
  run_cmd "Install Infracost" curl -s https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh
  run_cmd "Move Infracost" sudo mv infracost /usr/local/bin/
  INFRACOST_VERSION=$(infracost --version | awk '{print $3}')
  add_summary infracost "$INFRACOST_VERSION"
fi

# tfupdate
if should_run tfupdate; then
  log_step "Installing tfupdate"
  install_go_tool tfupdate github.com/minamijoyo/tfupdate \
    'TFUPDATE_VERSION=$(tfupdate --version | awk "{print \$3}"); add_summary tfupdate "$TFUPDATE_VERSION"'
fi

# hcledit
if should_run hcledit; then
  log_step "Installing hcledit"
  install_go_tool hcledit github.com/minamijoyo/hcledit \
    'HCLEDIT_VERSION=$(hcledit --version | awk "{print \$3}"); add_summary hcledit "$HCLEDIT_VERSION"'
fi

# Write summary
if ! $DRY_RUN; then
  echo "$SUMMARY_JSON" | jq . > "$SUMMARY_FILE"
  echo -e "\n${GREEN}📦 Tool summary written to $SUMMARY_FILE${NC}"
fi

echo -e "\n${GREEN}✅ All tools installed successfully at $(date '+%Y-%m-%d %H:%M:%S')${NC}"
