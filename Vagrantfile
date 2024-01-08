# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'csv'
require 'yaml'

Vagrant.require_version ">= 2.2.0"
Vagrant.configure("2") do |config|

  # ------------------
  # Vagrant VM settings you can change
  # ------------------

  guest_user_name = "vagrant"
  vm_hostname = "local-biocollect-dev"
  localhost_domain = "127.0.0.1"

  # Set this to your timezone so that times are easy to understand.
  timezone_name = 'Australia/Brisbane'

  # Ansible is used to provision the virtual machine.
  # versions: https://github.com/ansible/ansible/releases
  ansible_core_version = '2.16.2'

  # Python is used to run ansible and for managing the apps and plugins.
  # versions: https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa
  python_version = '3.11'

  # Nginx is used as a reverse proxy to provide access to apps.
  # versions: https://nginx.org/en/download.html
  nginx_version = '1.24.*'

  # Docker is used to run containers.
  # versions: https://docs.docker.com/engine/release-notes/24.0/
  docker_ce_version = '5:24.0.7*'
  containerd_version = '1.6*'
  # versions: https://docs.docker.com/compose/release-notes/
  compose_version = '2.21*'

  # Nodejs container is used to populate the js from package.json files.
  # versions: https://nodejs.org/en/download/
  nodejs_version = '20'

  # Mongo container is used as the CAS and Ecodata databases.
  # versions: https://hub.docker.com/_/mongo
  mongo_version = '5-focal'

  # MySQL container is used as the CAS and Userdetails databases.
  # versions: https://hub.docker.com/_/mysql
  mysql_version = '8.0'

  # Elasticsearch container is used by Ecodata for search.
  # versions: https://hub.docker.com/_/elasticsearch
  elasticsearch_version = '7.17.16'

  # Gotenberg pdf service for creating pdf files.
  # versions: https://hub.docker.com/r/gotenberg/gotenberg/tags
  gotenberg_version = '7'

  # Local mail server for testing mail sending.
  # versions: https://hub.docker.com/r/maildev/maildev/tags
  maildev_version = '2.1.0'

  # Local S3-compatible server for testing S3 storage.
  # versions: https://hub.docker.com/r/minio/minio/tags
  minio_version = 'latest'

  # the various ports in use
  specified_ports = {
    # services
    'web_service_port': 8880,
    'pdf_service_port': 8083,
    'mail_service_http_port': 1080,
    'mail_service_smtp_port': 1025,
    'objectstore_service_main_port': 9000,
    'objectstore_service_console_port': 9001,
    'db_ui_service_http_port': 8080,
    'mongo_ui_service_http_port': 8081,
    'app_status_service_port': 8082,
    'mongo_service_port': 27017,
    'mysql_service_port': 3306,
    'elasticsearch_service_port': 9200,

    # apps
    'biocollect_http_port': 8900,
    'biocollect_debug_port': 5900,
    'ecodata_http_port': 8901,
    'ecodata_debug_port': 5901,
    'cas_http_port': 8902,
    'cas_debug_port': 5902,
    'userdetails_http_port': 8903,
    'userdetails_debug_port': 5903,
    'apikey_http_port': 8904,
    'apikey_debug_port': 5904,
    'alerts_http_port': 8905,
    'alerts_debug_port': 5905,
    'theme_http_port': 8906,
    'dashboard_http_port': 8907,
  }

  # This refers to the Ubuntu release code name.
  ubuntu_release_name = 'focal'

  # architecture
  vagrant_architecture = ENV['VAGRANT_ARCHITECTURE'] || "amd64"

  # Find your local ubuntu mirrors here: https://launchpad.net/ubuntu/+archivemirrors
  # Note that if you're using arm64, not every mirror will have the arm64 packages.

  # amd64
  box_amd64_name = "bento/ubuntu-20.04"
  ubuntu_apt_amd64_url = "https://mirror.aarnet.edu.au/pub/ubuntu/archive"

  # arm64
  box_arm64_name = "bento/ubuntu-20.04-arm64"
  ubuntu_apt_arm64_url = "https://mirror.aarnet.edu.au/pub/ubuntu/ports"

  # Change the memory and CPU to suit your machine.
  # Note that a minimal, mostly usable virtual machine requires at least 6BG and 4 CPUs to run
  # CAS, Apikey, Userdetails, Ecodata, and Biocollect.
  vagrant_memory = 8192 # in MB
  vagrant_cpus = 6

  # ------------------
  # End settings you can change
  # ------------------

  # get the additional env vars
  additional_env_vars = YAML.load_file('.local/additional-env-vars.yml')
  # populate env var values from ENV
  additional_env_vars.each { |key, value|
    unless ENV[key]
      raise "Must set env var '#{key}' (this env var is in .local/additional-env-vars.yml)."
    end
    additional_env_vars[key] = ENV[key]
  }

  # set hostname
  config.vm.hostname = vm_hostname

  # guest dirs
  guest_home_dir = "/home/#{guest_user_name}"
  guest_src_dir = "#{guest_home_dir}/src"
  ansible_venv_dir = "#{guest_home_dir}/ansible-venv"
  ansible_collections_dir = "#{guest_home_dir}/ansible-collections"

  # guest architecture

  # Set the box to use based on the architecture - Ubuntu 20.04 LTS
  case vagrant_architecture
  when 'arm64'
    config.vm.box = box_arm64_name
    ubuntu_apt_url = ubuntu_apt_arm64_url

  when 'amd64'
    config.vm.box = box_amd64_name
    ubuntu_apt_url = ubuntu_apt_amd64_url
  else
    raise "Unsupported architecture '#{vagrant_architecture}'. Please set VAGRANT_ARCHITECTURE to 'arm64' or 'amd64'."
  end

  # provider settings for virtualbox
  config.vm.provider "virtualbox" do |vb|
    vb.memory = vagrant_memory
    vb.cpus = vagrant_cpus
    vb.linked_clone = false
    vb.name = vm_hostname
  end

  # provider settings for vmware
  config.vm.provider "vmware_desktop" do |vm|
    vm.vmx["memsize"] = vagrant_memory.to_s
    vm.vmx["numvcpus"] = vagrant_cpus.to_s
    vm.vmx["displayname"] = vm_hostname
    vm.gui = false
    vm.vmx["ethernet0.pcislotnumber"] = "160"
  end

  # sync folder - exclude folders using rsync option
  rsync_exclude_list = %w[.vagrant/ .git/ .idea/ coverage-html/ __pycache__/ .venv/ node_modules/ .gradle/ out/ target/ build/ build-cache/ coverage/ java-profiler-reports/]
  config.vm.synced_folder "./..", guest_src_dir, type: "rsync", rsync__exclude: rsync_exclude_list, group: guest_user_name, owner: guest_user_name, create: true

  # ensure there is a vagrant directory at the root, this is needed by some boxes
  config.vm.provision "vagrant_user_dir", type: "shell", inline: <<-SHELL
        if [[ ! -d "/vagrant" ]]; then
            sudo mkdir -p "/vagrant"
            sudo chown "#{guest_user_name}:#{guest_user_name}" "/vagrant"
        fi
  SHELL

  # prepare to run ansible
  config.vm.provision "prepare_ansible", type: "shell", path: "vm/prepare.sh",
                      env: {
                        'FILE_OWNER': guest_user_name,
                        'HOME_DIR': guest_home_dir,
                        'SRC_DIR': guest_src_dir,
                        'APT_URL': ubuntu_apt_url,
                        'ANSIBLE_VENV_DIR': ansible_venv_dir,
                        'ANSIBLE_COLLECTIONS_DIR': ansible_collections_dir,
                        'VAGRANT_ARCHITECTURE': vagrant_architecture,
                        'UBUNTU_RELEASE': ubuntu_release_name,
                        'PYTHON_VERSION': python_version,
                        'ANSIBLE_VERSION': ansible_core_version,
                      }

  # run the ansible provisioning
  config.vm.provision "run_ansible", type: "ansible_local" do |ans|
    ans.compatibility_mode = "2.0"
    ans.verbose = false
    ans.install = false
    ans.playbook_command = "#{ansible_venv_dir}/bin/ansible-playbook"
    ans.config_file = "#{guest_src_dir}/local-biocollect-dev/vm/ansible/ansible.cfg"
    ans.playbook = "#{guest_src_dir}/local-biocollect-dev/vm/ansible/playbook.yml"
    ans.extra_vars = {
      # core
      'guest_user_name': guest_user_name,
      'guest_home_dir': guest_home_dir,
      'guest_src_dir': guest_src_dir,
      'apt_url': ubuntu_apt_url,
      'ansible_venv_dir': ansible_venv_dir,
      'ansible_collections_dir': ansible_collections_dir,
      'vagrant_architecture': vagrant_architecture,
      'ubuntu_release': ubuntu_release_name,
      'timezone_name': timezone_name,
      'specified_ports': specified_ports,
      'additional_env_vars': additional_env_vars,
      'specified_versions': {
        'ansible_core': ansible_core_version,
        'python': python_version,
        'nginx': nginx_version,
        'nodejs': nodejs_version,
        'mongo': mongo_version,
        'mysql': mysql_version,
        'elasticsearch': elasticsearch_version,
        'docker_ce': docker_ce_version,
        'containerd': containerd_version,
        'compose': compose_version,
        'gotenberg': gotenberg_version,
        'maildev': maildev_version,
        'minio': minio_version,
      }
    }
  end

  # forwarded ports - third party apps
  config.vm.network "forwarded_port", guest: specified_ports[:web_service_port], host: specified_ports[:web_service_port], host_ip: localhost_domain

  # forward the debug ports
  specified_ports.each { |key, value|
    if key.to_s.include? '_debug_'
      config.vm.network "forwarded_port", guest: value, host: value, host_ip: localhost_domain
    end
  }
end