provider "aws" {
  profile = var.profile
  region  = var.region-home
  alias   = "region-home"
}