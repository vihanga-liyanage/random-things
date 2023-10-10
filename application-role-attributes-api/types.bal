// Table structures
type RoleAttributeRecord record {|
    *RoleID;
    readonly string attributeId;
    string attributeValue;
|};

type AttributeMetadataRecord record {|
    readonly string orgId;
    readonly string attributeId;
    string attributeName;
|};

// Other objects
type RoleID record {|
    readonly string orgId;
    readonly string appId;
    readonly string roleName;
|};

type RoleAttribute record {|
    string attributeName;
    string attributeValue;
|};

type Role record {|
    *RoleID;
    RoleAttribute[] attributes;
|};

type OrgAttributeMetadata record {|
    string orgId;
    AttributeMetadata[] attributes;
|};

type AttributeMetadata record {|
    string attributeId;
    string attributeName;
|};
