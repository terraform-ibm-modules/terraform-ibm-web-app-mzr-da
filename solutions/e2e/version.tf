terraform {
  required_version = ">= 1.3.0"
  # Lock DA into an exact provider version - renovate automation will keep it updated
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "2.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.3.0"
    }
  }
}
