
// {{ ansible_managed }}

var casServiceDef = {{ app_cas_db_services_defs | to_json }};

// insert the new services
r = db.runCommand({insert: '{{ app_cas_mongo_db_main_collection_services }}', documents: casServiceDef, ordered: true});
{{ mongo_default_check_result }}