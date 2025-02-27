---
title: "Managing secrets with Infisical and OpenTofu"
date: 2025-02-27
author: "Jacobo García"
---

## On this page

- Introduction.
- Assumptions and pre-requisites.
- Configuring Infisical on your development machine and create an Infisical project.
- Creating a Machine Identity and exposing it to OpenTofu.
- Creating a secret in Infisical.
- Deploying a GCP compute instance with OpenTofu.
- Retrieving secrets from Infisical and feeding them to startup script.
- Conclusions.

## Introduction
A seasoned infrastructure engineer cares about security. Protecting sensitive data is one of the most important security tasks an engineer performs. Proper security measures help ensure this data is protected from theft or unauthorized access. With the myriad of tools available in the market, it is easier than never before to implement security best practices. We are going to learn how to use one of those tools: Infisical, an open-source secret management platform. Teams use Infisical to centralize configuration and secrets. In this post we are going to learn how to integrate Infisical with OpenTofu, a Terraform 100% open-source fork.

Imagine that you need to have a secret safely available as an environment variable of a startup script in a GCP compute instance. Probably your startup script will use the environment later to perform another action. This post will walk through to creation of a GCP compute instance with OpenTofu, then use Infisical to retrieve a secret and inject it in the startup script of the startup script.

These are the steps to follow: 
 - Configure Infisical in a development machine and create an Infisical project.
 - Creating an Infisical Machine Identity to use in OpenTofu.
 - Create a secret in Infisical.
 - Deploy a GCP compute instance with OpenTofu.
 - Retrieve a secret from Infisical Vault and inject it in a compute instance init script.

I hope everything is clear at this point, let's step forward.

## Assumptions and pre-requisites

We want to keep this post short, so before we get in to the real action we are going to assume some basic pre-requisites fullfilled. You should we have:
- The following tools installed: `git`, `tofu`, `infisical`, `gcloud`.
- A configured GCP account with the following APIs enabled: Compute, Billing, Identity and Access Management.
- An Infisical account for your organisation. Infiscal offers a paid cloud version with a generous free tier, which will be used in this exercise. We don't want to explain how to configure the self-hosted, open-source version for simplicity reasons. 
- Take note of the region and the organisation when you registered an Infisical account for latter use. In this post the organisation name is `Liminal` and the region is EU (Europe).

With every requisite fulfilled we can move to the next section.

## Configuring Infisical in your development machine and creating a new project.

Now that you have registered an Infisical account we are going to configure it's CLI. Keep in ind the Infisical region selected in the previous step.

Start by authenticating with the Infisical platform:
```bash
infisical login
```

![image](images/01.png)

Here you have to pick the Infisical Cloud region.

![image](images/02.png)

Open the URL offered in the next step and use it to authenticate via Browser. 
Login, select the region and your organisation, after sucesfully loggin in you'll see:

![image](images/03.png)

Heading back to the command line, we have sucesfully authenticated.

![image](images/04.png)

Next, we are going to create a new Infisical project to store our secrets. Infisical doesn't offer a command line action for creating a project. So we have to rely on it's web administrative interface. In your browser, head into `https://app.infisical.com`, once you log in you'll be able to create a new project.

![image](images/05.png)

Click on "New Project", use the Project Name `myapp-confidential` add an optional description and "click Create Project"  

![image](images/06.png)
![image](images/6.5.png)

Our project is created. Now we are going to configure Infisical in our infra repo. We will use an example OpenTofu repository specifically created for this post. In the terminal run:

```bash
git clone https://github.com/therobot/infisical-opentofu-post.git
```

Then run `infisical init` to initialize the project, then select your organization and project `myapp-confidential`.

```bash
cd infisical-opentofu-post
infisical init
```

![image](images/07.png)
![image](images/08.png)
![image](images/09.png)

After running the init command a new configuration file `.infisical.json` is created in your root directory. 

Once you completed this section you should have an Infisical project named `myapp-confidential`, the infisical CLI configured, and our example infra repo. 

## Creating a Machine Identity and exposing it to OpenTofu

An Infisical machine identity is an entity that symbolizes a workload or application needing access to different resources within Infisical. Think of it as an IAM user in AWS or a service account in GCP. We are going to create one and expose it as environment variables for OpenTofu.

In the Infisical web admin interface, in the Sidebar got to: Admin > Access Control. Find and click "Machine Identities" and then "Create Identity".

![image](images/12.png)

Now click on "Create a new Identity". Afterwards type `opentofu` for the identity name, assign the role Member. 

![image](images/14.png)
![image](images/15.png)

Let's assign the Machine Identity to our project. In this same screen click on the "+" symbol located at the end-right of the interface. Select `myapp-confidential` and apply the role Developer, click Add.

![image](images/16.png)
![image](images/17.png)

We will use Universal Auth method for our client, but we need to take note of a couple of parameters for authenticating our OpenTofu client. Click on the settings wheel next to Universal Auth, under Authentication. Then click on "Add Client Secret" and then click create. Note down Client Secret since it only will be shown once. Close the window and take note of Client ID.

![image](images/18.png)
![image](images/19.png)

Finally we will need the workspace ID parameter to complete our OpenTofu configuration. Click on "Secrets" on the sidebar > `myapp-confidential > "Project Settings". Then click on "Copy Project ID" and note it down.
We will expose the three parameters as shell environment variables, replace the parameters in angle brackets below with the ones noted down.

```bash
export TF_VAR_INFISICAL_CLIENT_ID="<OPENTOFU_CLIENT_ID>"
export TF_VAR_INFISICAL_CLIENT_SECRET="<OPENTOFU_CLIENT_SECRET>"
export TF_VAR_INFISICAL_WORKSPACE_ID="<MYAPP_CONFIDENTIAL_PROJECT_ID>"
```

## Creating a secret in Infisical.
  
We are ready to store secrets in infisical. Let's to create a secret named `very_important_secret` with an example value of `secret123`, and we will store in our `development` environment. [Infisical supports multiple environments per project](https://infisical.com/docs/documentation/platform/project#project-environment). On the command line execute:

```bash
infisical secrets set "very_important_secret=secret123" --env dev
```
![image](images/10.png)

Now you can review your secret:
```bash
infisical secrets get "very_important_secret"
```
[IMAGE11]

Infisical supports CRUD operations in the secrets, for more information check [the official docs](https://infisical.com/docs/cli/commands/secrets#description).

We are done creating our secrets, let's create some infrastructure.

## Deploying a GCP compute instance with OpenTofu

Let's go back to our OpenTofu infra repo. 

```bash
ls -l
total 64
-rw-r--r--@ 1 sculptures  staff  1117 Feb 27 12:49 init-script.sh.tpl
-rw-r--r--@ 1 sculptures  staff  1770 Feb 25 23:26 main.tf
-rw-r--r--@ 1 sculptures  staff  1007 Feb 25 23:32 outputs.tf
-rw-r--r--@ 1 sculptures  staff   152 Feb 25 23:20 terraform.tfstate
-rw-r--r--@ 1 sculptures  staff  8426 Feb 25 23:20 terraform.tfstate.backup
-rw-r--r--@ 1 sculptures  staff   898 Feb 22 18:42 providers.tf
-rw-r--r--@ 1 sculptures  staff   898 Feb 22 18:42 variables.tf
```

Open `main.tf` in our editor which contains the juicy infra code. Take a look at our Infisical syntax provider:

```tf
provider "infisical" {
  host          = "https://eu.infisical.com" # Specify the region you have selected when you created the workspace
  client_id = var.infisical_client_id
  client_secret = var.infisical_client_secret
}

```

The variables `client_id` and `client_secret` are available in our environment, they were exported beforehand. Those variables should be also declared in `variables.tf`. It is important to configure the `host` parameter URL to the region specific region your using. There's a bug in Infisical that makes OpenTofu crash if you specify `app.infisical.com`, as the official documentation states.

The next block retrieves the whole infisical project `myapp-confidential` and instances it as an OpenTofu data object. We are also consuming `workspace_id` from our shell environment, same as with the provider.

```tf
data "infisical_secrets" "myapp-confidential" {
  env_slug     = "dev"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/"
}
```

The following code declares a template which will be used for the startup script in the compute instance creation.

```tf
data "template_file" "myapp_init_script" {
  template = file("init-script.sh.tpl")
  vars = {
    very_important_secret = data.infisical_secrets.myapp-confidential.secrets.very_important_secret.value
  }
}
```
Take a special look on how to access specific secrets inside the whole Infisical project. The secret we are going to use: `very_important_secret` is accessed on the OpenTofu `infisical_projects` data object and instanced as a template variable. Pay special attention to the last line of `init-script.sh.tpl` to see how `very_important_secret` is rendered:

```bash
export MYAPPSECRET=${very_important_secret}
```

Below comes the code that declares the compute instance resource. This resource runs the template declared using `metadata_startup_script`. The template is rendered in the parameter declaration, the startup script is executed as part of the compute instance creation process.

```tf
resource "google_compute_instance" "web" {
  name         = "web-${random_pet.name.id}"
  machine_type = "n2-standard-4"
  zone         = "europe-west8-a"
  metadata_startup_script = data.template_file.myapp_init_script.rendered
...
```
Finally, we just need to execute the usual steps on OpenTofu to create our infrastructure.

```bash
tofu init
```
Run the OpenTofu `plan` command to create a preview of resources created and destroyed.

```bash
tofu plan
```
A sucessful `plan` command will output a preview of the changes performed to your infrastructure. Now it is time to make this changes real.

```bash
tofu apply
```

When sucessfull the command will create our instance and execute the script which instances `very_important_secret`. In our use case the secret is exposed as shell environment variable that could be later used. 

A good idea to verify all the steps in the example is to echo the variable to a file. You can also examine the secret from the command line, since we have an specific output resource for the secret in our `outputs.tf`.

```bash
tofu output -json very_important_secret
"secret123"
```

# Conclusion

