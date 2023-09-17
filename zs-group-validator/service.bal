import ballerina/http;
import ballerina/log;

import ballerinax/scim;
import ballerina/time;
import ballerina/regex;

configurable string orgName = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string[] scope = ["internal_user_mgt_list"];

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

        if payload.user == "" || payload.groups == "" {
            return {
                status: "Failure",
                message: "User and groups should not be empty!"
            };
        }

        log:printInfo("validateGroups call received - " + payload.groups);

        string[] groups = regex:split(payload.groups, ",");
        string allowedGroups = "";

        foreach string group in groups {
            log:printInfo("Checking group: " + group);
            string username = "DEFAULT/" + group + "@zs.com";
            scim:UserSearch searchData = { filter: string `userName eq ${username}`, schemas: ["urn:ietf:params:scim:api:messages:2.0:SearchRequest"] };
            scim:UserResponse response = check scimClient->searchUser(searchData);

            // log:printInfo(response.toBalString());
            
            if response.totalResults > 0 {
                scim:UserResource[] userResources = response.Resources ?: [];
                scim:UserResource user = userResources[0];

                if user?.urn\:scim\:wso2\:schema?.expiryDate is json && user?.urn\:scim\:wso2\:schema?.expiryDate != null {
                    string expiry = check user?.urn\:scim\:wso2\:schema?.expiryDate;

                    time:Utc utcNow = time:utcNow();

                    time:Civil expiryCivil = check time:civilFromString(expiry);
                    time:Utc utcExpiry = check time:utcFromCivil(expiryCivil);
                    
                    if utcNow < utcExpiry {

                        log:printInfo("Group " + group + " is allowed.");
                        allowedGroups += group + ",";
                    } else {
                        log:printInfo("Group " + group + " is NOT allowed.");
                    }
                } else {
                    log:printInfo("Group " + group + " is ignored.");
                }
            }
        }

        return {
            status: "success",
            allowedGroups: allowedGroups
        };
    }
}
