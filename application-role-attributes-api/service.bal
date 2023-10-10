import ballerina/http;
import ballerina/io;
import ballerina/uuid;

table<AttributeMetadataRecord> key(orgId, attributeId) attributeMetadataTable = table [
    {orgId: "1", attributeId: "0001", attributeName: "Start Date"},
    {orgId: "1", attributeId: "0002", attributeName: "End Date"},
    {orgId: "1", attributeId: "0003", attributeName: "Subscription Type"}
];

table<RoleAttributeRecord> key(orgId, appId, roleName, attributeId) roleAttributesTable = table [
    {orgId: "1", appId: "1", roleName: "role_1", attributeId: "0001", attributeValue: "xxx"}
];

# A service to handle custom attributes on Asgardeo application roles
service / on new http:Listener(9090) {

    resource function get metaData/o/[string orgId]/attributes() returns json|http:NotFound|error {
        
        table<AttributeMetadataRecord> attributeRecords = from AttributeMetadataRecord r in attributeMetadataTable
            where r.orgId == orgId
            select r;
        if attributeRecords.length() == 0 {
            return http:NOT_FOUND;
        }

        AttributeMetadata[] am = [];

        foreach AttributeMetadataRecord item in attributeRecords {
            am.push({attributeId: item.attributeId, attributeName: item.attributeName});
        }

        OrgAttributeMetadata response = {
            orgId: orgId,
            attributes: am
        };
        return response;
    }
    
    resource function post metaData/o/[string orgId]/attributes(string attributeName) returns json|http:Created|http:Conflict|error {

        table<AttributeMetadataRecord> r2 = from AttributeMetadataRecord r in attributeMetadataTable
            where r.orgId == orgId && r.attributeName == attributeName
            select r;
        if r2.length() != 0 {
            return http:CONFLICT;
        }

        string attributeId = uuid:createType1AsString();
        attributeMetadataTable.add({orgId: orgId, attributeId: attributeId, attributeName: attributeName});

        return http:CREATED;
    }

    resource function get metaData/o/[string orgId]/attributes/[string attributeId]() returns json|http:NotFound|error {
        
        AttributeMetadataRecord? attribute = attributeMetadataTable[orgId, attributeId];
        if attribute is null {
            return http:NOT_FOUND;
        }

        return attribute;
    }
    
    resource function put metaData/o/[string orgId]/attributes/[string attributeId](string attributeName) 
        returns json|http:Accepted|http:NotFound|error {

        table<AttributeMetadataRecord> r2 = from AttributeMetadataRecord r in attributeMetadataTable
            where r.orgId == orgId && r.attributeId == attributeId
            select r;
        if r2.length() == 0 {
            return http:NOT_FOUND;
        }

        attributeMetadataTable.put({orgId: orgId, attributeId: attributeId, attributeName: attributeName});

        return http:ACCEPTED;
    }

    resource function delete metaData/o/[string orgId]/attributes/[string attributeId]() 
        returns json|http:Accepted|http:NotFound|http:BadRequest|error {

        table<AttributeMetadataRecord> r2 = from AttributeMetadataRecord r in attributeMetadataTable
            where r.orgId == orgId && r.attributeId == attributeId
            select r;
        if r2.length() == 0 {
            return http:NOT_FOUND;
        }

        // Check whether this attribute has been used
        table<RoleAttributeRecord> results = from RoleAttributeRecord r in roleAttributesTable 
            where r.orgId == orgId && r.attributeId == attributeId
            select r;

        if results.length() != 0 {
            http:BadRequest b = {body: {msg: "Attribute is used to store role attribute values. Please delete them first."}};
            return b;
        }

        _ = attributeMetadataTable.remove([orgId, attributeId]);

        return http:ACCEPTED;
    }

    resource function get o/[string orgId]/applications/[string appId]/roles/[string roleName]/attributes() 
        returns json|http:NotFound|http:InternalServerError|error {

        io:println(roleAttributesTable);
        
        table<RoleAttributeRecord> results = from RoleAttributeRecord r in roleAttributesTable 
            where r.orgId == orgId && r.appId == appId && r.roleName == roleName
            select r;

        if results.length() == 0 {
            return http:NOT_FOUND;
        }
        
        io:println(results);
        
        RoleAttribute[] atrs = [];

        foreach RoleAttributeRecord r in results {
            AttributeMetadataRecord? atr = attributeMetadataTable[orgId, r.attributeId];
            if atr is () {
                http:InternalServerError e = {body: {msg: "Could not find attribute metadata for the attribute ID: " + r.attributeId + " and org ID: " + orgId}};
                return e;
            }
            io:println(r.attributeId, " - ",atr.attributeName, " - ", r.attributeValue);
            RoleAttribute a = {attributeName: atr.attributeName, attributeValue: r.attributeValue};
            atrs.push(a);
        }

        Role role = {
            orgId: orgId,
            appId: appId,
            roleName: roleName,
            attributes: atrs
        };
        return role;
    }

    resource function post o/[string orgId]/applications/[string appId]/roles/[string roleName]/attributes(Attribute attribute) 
        returns json|http:NotFound|http:BadRequest|http:Conflict|http:Created|error {

        if attribute.attributeId == "" {
            http:BadRequest b = {body: {msg: "Attribute ID cannot be empty"}};
            return b;
        }

        // check if the attribute ID is valid
        table<AttributeMetadataRecord> attributeRecord = from AttributeMetadataRecord r in attributeMetadataTable
            where r.orgId == orgId && r.attributeId == attribute.attributeId
            select r;
        if attributeRecord.length() != 1 {
            http:BadRequest b = {body: {msg: "Attribute ID is invalid"}};
            return b;
        }

        table<RoleAttributeRecord> results = from RoleAttributeRecord r in roleAttributesTable 
            where r.orgId == orgId && r.appId == appId && r.roleName == roleName
            select r;

        if results.length() == 0 {
            return http:NOT_FOUND;
        }
        
        // Check if the same attribute exists in the role
        table<RoleAttributeRecord> results_2 = from RoleAttributeRecord r in roleAttributesTable 
            where r.orgId == orgId && r.appId == appId && r.roleName == roleName && r.attributeId == attribute.attributeId
            select r;

        if results_2.length() != 0 {
            http:Conflict b = {body: {msg: "Attribute ID already exists in the role"}};
            return b;
        }

        // Persist role attribute
        roleAttributesTable.add({
            orgId: orgId, 
            appId: appId, 
            roleName: roleName, 
            attributeId: attribute.attributeId, 
            attributeValue: attribute.attributeValue
        });

        return http:CREATED;
    }
    
    resource function get o/[string orgId]/applications/[string appId]/roles/[string roleName]/attributes/[string attributeId]() 
        returns json|http:NotFound|http:InternalServerError|error {

        RoleAttributeRecord? r = roleAttributesTable[orgId, appId, roleName, attributeId];

        if r is null {
            return http:NOT_FOUND;
        }

        AttributeMetadataRecord? m = attributeMetadataTable[orgId, attributeId];
        if m is null {
            http:InternalServerError e = {body: {msg: "Could not find attribute metadata for the attribute ID: " + attributeId + " and org ID: " + orgId}};
            return e;
        }

        RoleAttribute roleAttribute = {attributeName: m.attributeName, attributeValue: r.attributeValue};
        return roleAttribute;
    }

    resource function put o/[string orgId]/applications/[string appId]/roles/[string roleName]/attributes/[string attributeId](string attributeValue) 
        returns json|http:NotFound|http:Accepted|error {

        RoleAttributeRecord? r = roleAttributesTable[orgId, appId, roleName, attributeId];

        if r is null {
            return http:NOT_FOUND;
        }

        roleAttributesTable.put({
            orgId: orgId, 
            appId: appId, 
            roleName: roleName, 
            attributeId: attributeId, 
            attributeValue: attributeValue
        });

        return http:ACCEPTED;
    }

    resource function delete o/[string orgId]/applications/[string appId]/roles/[string roleName]/attributes/[string attributeId]() 
        returns json|http:NotFound|http:Accepted|error {

        RoleAttributeRecord? r = roleAttributesTable[orgId, appId, roleName, attributeId];

        if r is null {
            return http:NOT_FOUND;
        }

        _ = roleAttributesTable.remove([orgId, appId, roleName, attributeId]);

        return http:ACCEPTED;
    }

}
