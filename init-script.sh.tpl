#!/bin/bash
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Installing our app dependencies
sudo apt update
apt install apache2 php libapache2-mod-php php-mysql

# Setting permissions
chown -R www-data:www-data /var/www
chmod 2775 /var/www
mkdir -p /var/www/html
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
cd /var/www/html

# We use the injected secret to create a .env file
export MYAPPSECRET=${very_important_secret}
echo $MYAPPSECRET > /var/www/html/.env

# Ideally we would clone our app from a git repository here
# The app would consume the secret from the .env file