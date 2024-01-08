# local-biocollect-dev
A local development environment for ALA's Biocollect app and related apps.

It provides:

- the ability to work on and run apps and plugins
- an overview of the apps and plugins available
- a virtual machine to make the environment consistent and easy to set up

This is a local development environment.
**Do not** use this for a public deployment.

> This is a work in progress. If you'd like to use this setup for local development, 
> please contact [@cofiem](https://github.com/cofiem) for help and to contribute.

## Setup

The goal is to have the apps and plugins in one folder.
You can then change the code on your local machine, sync the changes to the guest virtual machine,
and have the apps running to view the changes.

Requirements:

- Install [Vagrant](https://developer.hashicorp.com/vagrant/docs/installation)
- Install a [Vagrant provider](https://developer.hashicorp.com/vagrant/docs/providers), the Vagrantfile supports Virtualbox or VMWare

Options for application code:

- If you want to work on your own customised apps and plugins, git clone those repositories.
- If you want to contribute changes back to the ALA, you will need
  to [fork the ALA repos](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/about-forks)
  and work in the forked repos.

You'll need at least these repositories:

- [ala-cas-5](https://github.com/AtlasOfLivingAustralia/ala-cas-5)
- [apikey](https://github.com/AtlasOfLivingAustralia/apikey)
- [biocollect](https://github.com/AtlasOfLivingAustralia/biocollect)
- [ecodata](https://github.com/AtlasOfLivingAustralia/ecodata)
- [local-biocollect-dev](https://github.com/qcif/local-biocollect-dev)
- [userdetails](https://github.com/AtlasOfLivingAustralia/userdetails)

These repositories are also supported (some are 'in place' editable plugins for the Grails applications):

- [ala-map-plugin](https://github.com/AtlasOfLivingAustralia/ala-map-plugin)
- [ala-security-project](https://github.com/AtlasOfLivingAustralia/ala-security-project)
- [ala-bootstrap3](https://github.com/AtlasOfLivingAustralia/ala-bootstrap3)

The steps to set up the local code and start the Vagrant VM:

1. On your development machine, create a folder named `biocollect-dev`.
2. Use `git` to clone this development environment repo to `biocollect-dev/local-biocollect-dev`.
3. Use `git` to clone and checkout the other relevant repositories, e.g. `biocollect-dev/biocollect`
4. Open a command line and change directory to `biocollect-dev/local-biocollect-dev`.
5. Start the Vagrant machine `vagrant up --provision`.
6. SSH into the development machine using `vagrant ssh`.
7. View the overview of the status of the virtual machine at [the local dev landing page](http://localhost:8880)

The first run of the ansible provisioning might take a while as it needs to download quite a few dependencies.

Ensure the correct branch is checked out in each repository.

## Environment variables

There is a way to pass through env vars from your local machine to the vagrant VM.

- Set the env vars you want in your local machine.
- Create a yaml file at `.local/additional-env-vars.yml`, containing only key/value pairs with empty values (
  e.g. `ENV_VAR_NAME: ''`)
- The values will be obtained from the env vars with the exact same name on your local machine.
- These env vars will be set when you ssh into the guest using `vagrant ssh`, and will be available to the systemd services that run each app.

To be able to download packages hosted on GitHub Packages, you'll need a [GitHub Personal Access Token (classic)](https://github.com/settings/tokens).
The token needs at least `read:packages` permission.

Set environment variables:

```console
GITHUB_ACTOR='<github user name>'
GITHUB_TOKEN='<personal access token (classic)>'
```

Add the variable names to the `.local/additional-env-vars.yml` file:

```yaml
---
GITHUB_ACTOR: ''
GITHUB_TOKEN: ''
```

## Usage

There are helper bash functions for each app plugin, docker, and other things.
To view them, ssh into the vagrant VM and type `dev_` then press [tab] twice.

For example:

- Run biocollect tests: `dev_app_biocollect_test`
- Run biocollect app (using the systemd service): `dev_app_biocollect_service start`
- View the biocollect app logs: `dev_app_biocollect_logs`

While developing, control the app using `dev_(app|plugin)_[name]_service (start|stop|restart)`.

Set up a [vagrant synchronisation method](https://developer.hashicorp.com/vagrant/docs/synced-folders) to make it easy
to work on the code locally
and have it automatically update in the vagrant VM.

To run biocollect, there is an order to start the apps.

Wait for each app to be ready before starting the next. Check using `dev_app_[name]_logs`.

```console
dev_app_cas_service start
dev_app_apikey_service start
dev_app_userdetails_service start
dev_app_ecodata_service start
dev_app_biocollect_service start
```

You can then view the application websites using the `web` links on [the local dev landing page](http://localhost:8880).

If you need to remove all the database and generated data and start over:

```console
sudo rm -rf /home/vagrant/secret_generation/*
dev_docker_compose_remove
```

Then synchronise the vagrant data and run the provisioning to create everything again:

```console
vagrant rsync
vagrant provision
```

## Advanced settings

The `Vagrantfile` contains some variable declarations at the top of the file.
Take care changing these variables, as any changes might cause issues starting the vagrant virtual machine.

After changing settings, depending on which settings were changed, you'll need to do *one* of the following:

- restart the virtual machine: `vagrant halt` and then `vagrant up --provision`
- re-run all the provisioning: `vagrant provision`
- re-run just the ansible provisioning: `vagrant provision --provision-with=run_ansible`

This is where you can change things like the `timezone_name` for the virtual machine,
as well as the version of various dependencies, such as `nodejs_version`, `mongo_version`, `mysql_version`.

You can also change the specified ports using `specified_ports`.

Other advanced settings are in the ansible 'defaults' files in `vm/ansible/roles/[role_name]/defaults/main.yml`.

## Additional information

### Setting your theme

The apps can be themed. The theming is provided by the `ala-bootstrap3` plugin.

Placeholder theme files are in the `app_theme` ansible role in `vm/ansible/roles/app_theme/templates`.

The placeholder theme files do not include the css and js files.
You can include these by adding the files in `vm/ansible/roles/app_theme/templates` 
and then adding the file names to the list in `vm/ansible/roles/app_theme/tasks/main.yml`.

### Using host '%' in MySQL

- This allows login from any host - can be a security risk.
- Needed to allow processes outside the docker container to login.
- Hard to determine the ip address that mysql will see, so this is the easiest way.
- This is reasonable for this local development environment, but don't use this in a live deployment.

### Generated secrets

These applications require quite a few secrets, particularly CAS.

The secrets are generated by the ansible role `common_secret_generation` 
and stored in separate files in `/home/vagrant/secret_generation`.

### Landing page

Uses [server sent events](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events) to update the status of the services.

To test it:

```console
cd ~
source dashboard-venv/bin/activate
python services/status_dashboard.py
```

Then visit [the server sent events page](http://localhost:8880/sse/).

