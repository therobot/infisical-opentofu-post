/*
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

provider "google" {
  project     = "opentofu-infisical-blog-post"
  region      = "europe-west8"
}

provider "infisical" {
  host          = "https://eu.infisical.com" # Specify the region you have selected when you created the workspace
  client_id     = "<machine-identity-client-id>"
  client_secret = "<machine-identity-client-secret>"
}

provider "random" {}

data "infisical_secrets" "myapp-confidential" {
  env_slug     = "dev"
  workspace_id = "<project_id>"
  folder_path  = "/"
}

data "template_file" "myapp_init_script" {
  template = file("init-script.sh.tpl")
  vars = {
    very_important_secret = data.infisical_secrets.myapp-confidential.secrets.very_important_secret.value
  }
}
>
resource "random_pet" "name" {
  length = 2
}

resource "google_compute_instance" "web" {
  name         = "web-${random_pet.name.id}"
  machine_type = "n2-standard-4"
  zone         = "europe-west8-a"
  metadata_startup_script = data.template_file.myapp_init_script.rendered

  boot_disk {
    initialize_params {
      image = "ubuntu-minimal-2410-oracular-amd64-v20250212"
    }
  }
  scratch_disk {
    interface = "NVME"
  }

  network_interface {
    network = "default"
    access_config {}
  }

  tags = [ random_pet.name.id  ] 

}
