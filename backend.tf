terraform {
  backend "s3" {
    bucket       = "eurosafeai-overleaf-tfstate-906513713427-us-east-1"
    key          = "overleaf-mentor/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
