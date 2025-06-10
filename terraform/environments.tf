locals {
  environments = {
    dev = {
      name = "development"
      lambda_config = {
        memory_size = 128
        timeout     = 30
        environment_variables = {
          db_mvshub = "dev-db"
          db_pass   = "dev-pass"
        }
      }
      tags = {
        Environment = "dev"
        Project   = "MVSHUB"
        DeveloperLastUpdate = "auto-updated"
        Managed_by  = "terraform"
        Cost_center = "development"
      }
    }
    qa = {
      name = "qa"
      lambda_config = {
        memory_size = 256
        timeout     = 60
        environment_variables = {
          db_mvshub = "qa-db"
          db_pass   = "qa-pass"
        }
      }
      tags = {
        Environment = "qa"
        Project   = "MVSHUB"
        DeveloperLastUpdate = "auto-updated"
        Managed_by  = "terraform"
        Cost_center = "testing"
      }
    }
    prod = {
      name = "production"
      lambda_config = {
        memory_size = 512
        timeout     = 900
        environment_variables = {
          db_mvshub = "prod-db"
          db_pass   = "prod-pass"
        }
      }
      tags = {
        Environment = "prod"
        Project   = "MVSHUB"
        DeveloperLastUpdate = "auto-updated"
        Managed_by  = "terraform"
        Cost_center = "production"
      }
    }
  }
}