
// {{ ansible_managed }}

var ecodataHubDef = {{ app_ecodata_hub_default_defs | to_json }};

// insert the ecodata hub
r = db.runCommand({insert: 'hub', documents: ecodataHubDef, ordered: true});
{{ mongo_default_check_result }}
