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

output "domain-name" {
  value = google_compute_instance.web.network_interface.0.network_ip
}

output "public-hostname" {
    value = google_compute_instance.web.network_interface.0.access_config.0.nat_ip
}

output "application-url" {
   value = "${google_compute_instance.web.network_interface.0.access_config.0.nat_ip}/index.php"
}

output "very_important_secret" {
   value = data.infisical_secrets.myapp-confidential.secrets.very_important_secret.value
   sensitive = true
}