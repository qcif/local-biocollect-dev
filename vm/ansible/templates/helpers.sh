
# {{ ansible_managed }}

# {% if entry_is_service %}

function dev_{{ entry_name }}_service() {
 sudo systemctl "$@" '{{ entry_name }}'
}

function dev_{{ entry_name }}_logs() {
sudo journalctl --no-hostname -u '{{ entry_name }}' --no-pager | less +G
}

# {% endif %}

# {% if entry_builder == 'gradle' %}

function dev_{{ entry_name }}_refresh() {
dev_{{ entry_name }}_gradle clean --refresh-dependencies
}

function dev_{{ entry_name }}_assemble() {
dev_{{ entry_name }}_gradle assemble
}

function dev_{{ entry_name }}_update_lockfile() {
dev_{{ entry_name }}_gradle dependencies --write-locks
}

function dev_{{ entry_name }}_test() {
dev_{{ entry_name }}_gradle test
}

function dev_{{ entry_name }}_test_npm() {
dev_{{ entry_name }}_gradle npmTest
}

function dev_{{ entry_name }}_test_integration_chrome() {
dev_{{ entry_name }}_gradle -Dgeb.env=chromeHeadless integrationTest
}

function dev_{{ entry_name }}_test_integration_firefox() {
dev_{{ entry_name }}_gradle -Dgeb.env=firefoxHeadless integrationTest
}

function dev_{{ entry_name }}_gradle() {

{% if entry_java == '8' %}
export JAVA_HOME='{{ java_8_home_dir }}'
{% elif entry_java == '11' %}
export JAVA_HOME='{{ java_11_home_dir }}'
{% else %}
echo "Unknown java '{{ entry_java }}'."
exit 1
{% endif %}

cd "{{ entry_working_dir }}" || exit 1

/usr/bin/dos2unix '{{ entry_working_dir }}/gradlew' || exit 1
'{{ entry_working_dir }}/gradlew' --warning-mode all --console=plain --stacktrace --info -Dlogging.config={{ logback_config_path }} "$@"

export -n JAVA_HOME
}

# {% elif entry_builder == 'maven' %}


function dev_{{ entry_name }}_refresh() {
dev_{{ entry_name }}_maven clean -T 5
}

function dev_{{ entry_name }}_assemble() {
dev_{{ entry_name }}_maven package -T 5
}

function dev_{{ entry_name }}_test() {
# see: https://maven.apache.org/surefire/maven-surefire-report-plugin/index.html
dev_{{ entry_name }}_maven verify surefire-report:report-only

}

function dev_{{ entry_name }}_maven() {

{% if entry_java == '8' %}
export JAVA_HOME='{{ java_8_home_dir }}'
{% elif entry_java == '11' %}
export JAVA_HOME='{{ java_11_home_dir }}'
{% else %}
echo "Unknown java '{{ entry_java }}'."
exit 1
{% endif %}

export MAVEN_OPTS="-Xmx1g"

cd "{{ entry_working_dir }}" || exit 1

/usr/bin/dos2unix '{{ entry_working_dir }}/mvnw' || exit 1
'{{ entry_working_dir }}/mvnw' -Dmaven.plugin.validation=VERBOSE "$@"

export -n JAVA_HOME
export -n MAVEN_OPTS
}

# {% else %}

echo "Unknown source builder {{ entry_builder }}."

# {% endif %}


# {% if entry_java_artifact_name is defined and entry_java_artifact_name %}

# test the built artifact
function dev_{{ entry_name }}_artifact_run() {
{% for entry_env_var in entry_env_vars %} {{ entry_env_var.key }}="{{ entry_env_var.value }}"{% endfor %} \
  {% if entry_java == '8' %}{{ java_8_java_file }}{% elif entry_java == '11' %}{{ java_11_java_file }}{% else %}echo "Unknown java '{{ entry_java }}'.";exit 1;{% endif %} \
  {% if entry_java_sys_props is defined and entry_java_sys_props %}{% for entry_java_sys_prop in entry_java_sys_props %} -D{{ entry_java_sys_prop }}{% endfor %} \{% endif %}
  {% if entry_java_jvm_opts is defined and entry_java_jvm_opts %}{% for entry_java_jvm_opt in entry_java_jvm_opts %} -{{ entry_java_jvm_opt }}{% endfor %} \{% endif %}
  -jar {{ entry_working_dir }}/{{ entry_java_artifact_name }}
}

# {% endif %}
