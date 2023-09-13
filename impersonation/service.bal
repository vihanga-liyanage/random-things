import ballerina/http;

type Payload record {
    string name;
};

# A service representing a network-accessible API
# bound to port `9090`.
service / on new http:Listener(9090) {

    resource function post greeting(@http:Payload Payload payload) returns json|error {
        // Send a response back to the caller.
        if payload.name is "" {
            return error("name should not be empty!");
        }
        return {
            msg: "Hello, " + payload.name
        };
    }
}
