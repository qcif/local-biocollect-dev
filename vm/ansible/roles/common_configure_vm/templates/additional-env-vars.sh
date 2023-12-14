
# {{ ansible_managed }}

# {% for key, value in additional_env_vars.items() %}

export {{ key }}='{{ value }}'

# {% endfor %}

function dev_docker_compose() {
  docker compose -f '{{ docker_compose_path }}' --ansi never "$@"
}

function dev_docker_compose_update() {
  docker compose -f '{{ docker_compose_path }}' --ansi never up --detach --remove-orphans --quiet-pull --no-color
}

function dev_docker_compose_remove() {
  echo 'Bring down docker containers'
  docker compose -f '{{ docker_compose_path }}' --ansi never down --remove-orphans

  echo 'Remove unused docker containers'
  docker container prune -f

  echo 'Remove unused docker volumes'
  docker volume prune -f

  echo 'Remove known docker volumes'
  docker volume rm services_mongo_data
  docker volume rm services_mysql_data
  docker volume rm services_elasticsearch_data
}

function dev_docker_compose_prompt_mongo() {
  docker exec -it mongo_service mongo --username "{{ mongo_service_root_username }}" --password "{{ mongo_service_root_password }}" --authenticationDatabase "{{ mongo_service_auth_database }}"
}

function dev_docker_compose_prompt_mysql() {
  docker exec -it mysql_service mysql --host="{{ local_host }}" --user="{{ mysql_service_root_username }}" --password="{{ mysql_service_root_password }}"
}
