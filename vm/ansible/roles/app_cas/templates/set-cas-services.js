
// {{ ansible_managed }}

var casServiceDef = {{ app_cas_db_services_defs | to_json }}

// delete the existing services
var r = db.runCommand({delete: '{{ app_cas_mongo_db_main_collection_services }}', deletes: [{q: {}, limit: 0}]});
if((r.hasOwnProperty('ok') && r.ok != 1)||r.hasOwnProperty('writeConcernError')||r.hasOwnProperty('writeError')||r.hasOwnProperty('writeErrors')){printjson(r);throw('Mongo error.');}

// insert the new services
r = db.runCommand({insert: '{{ app_cas_mongo_db_main_collection_services }}', documents: casServiceDef, ordered: true});
if((r.hasOwnProperty('ok') && r.ok != 1)||r.hasOwnProperty('writeConcernError')||r.hasOwnProperty('writeError')||r.hasOwnProperty('writeErrors')){printjson(r);throw('Mongo error.');}