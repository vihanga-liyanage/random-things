import ballerina/http;
import ballerina/log;

type Payload record {
    string user;
    string impersonatee;
    string application;
};

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    resource function post canImpersonate(@http:Payload Payload payload) returns json|error {

        log:printInfo("canImpersonate call received");

        if payload.user is "" || payload.impersonatee is "" {
            return {
                status: 400,
                message: "User and impersonatee should not be empty!"
            };
        }

        var message = "Invalid";

        if payload.user == "mark@kfone.com" && payload.impersonatee == "vihanga@wso2.com" {
            message = "Valid";
        }

        log:printInfo("Returning status: " + message);
        
        return {
            status: 200,
            message: message
        };
    }
}
