import ballerina/http;
import ballerina/log;

import ballerinax/scim;

configurable string orgName = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string[] scope = [
    "internal_user_mgt_view",
    "internal_user_mgt_list",
    "internal_user_mgt_create",
    "internal_user_mgt_delete",
    "internal_user_mgt_update",
    "internal_user_mgt_delete",
    "internal_group_mgt_view",
    "internal_group_mgt_list",
    "internal_group_mgt_create",
    "internal_group_mgt_delete",
    "internal_group_mgt_update",
    "internal_group_mgt_delete"
];

//Create a SCIM connector configuration
scim:ConnectorConfig scimConfig = {
    orgName: orgName,
    clientId: clientId,
    clientSecret: clientSecret,
    scope: scope
};

//Initialize the SCIM client.
scim:Client scimClient = check new (scimConfig);

type Payload record {
    string user;
    string groups;
};

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    resource function post validateGroups(@http:Payload Payload payload) returns json|error {

        log:printInfo("canImpersonate call received");

        if payload.user is "" || payload.groups is "" {
            return {
                status: 400,
                message: "User and groups should not be empty!"
            };
        }

        log:printInfo("Get All Groups ===============================");

        scim:GroupResponse response = check scimClient->getGroups();
        log:printInfo(response.toString());
        
    }

}
