
// {{ ansible_managed }}

// create the user permission entries
var r = db.runCommand({
    insert: "userPermission",
    documents: [

        // {% for user_item in user_access %}

        {
            "accessLevel": "{{ user_item.accessLevel }}",
            "entityId": "{{ user_item.entityId }}",
            "entityType": "{{ user_item.entityType }}",
            "status": "active",
            "userId": "{{ create_cas_user_result.query_result[1][0]['@out_user_id'] }}"
        }

        // {% if not loop.last %}

        ,

        // {% endif %}

        //  {% endfor %}

    ]
});
{{ mongo_default_check_result }}
