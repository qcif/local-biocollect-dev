# Ensure user 'root' with host '%' exists.
# This allows logins from the docker host and from the vm host.

# caching_sha2_password: https://dev.mysql.com/doc/refman/8.0/en/upgrading-from-previous-series.html#upgrade-caching-sha2-password
CREATE USER IF NOT EXISTS '{{ mysql_service_root_username }}'@'{{ mysql_service_root_host }}' IDENTIFIED WITH caching_sha2_password BY '{{ mysql_service_root_password }}';
ALTER USER '{{ mysql_service_root_username }}'@'localhost' IDENTIFIED WITH caching_sha2_password BY '{{ mysql_service_root_password }}';
GRANT ALL ON *.* TO '{{ mysql_service_root_username }}'@'{{ mysql_service_root_host }}';
