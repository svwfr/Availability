namespace Byx.Availability;
enumextension 50600 "AVLB IFW Integration Id" extends "IFW Integration Id"
{
    value(0; "AVAIL")
    {
        Caption = 'Byx Availability';
        Implementation = "IFW Integration Handler" = "AVLB Integration Mgt";
    }
}

enumextension 50601 "AVLB IFW Job Id" extends "IFW Job Id"
{
    value(100; "INVT.CHK.RQST")
    {
        Caption = 'API Request: InventoryCheck (SE)';
        Implementation = "IFW Job Handler" = "AVLB Job InvtChkRqst Mgt";
    }
    value(101; "INVT.CHK.RSPS")
    {
        Caption = 'API Response: InventoryCheck (NO)';
        Implementation = "IFW Job Handler" = "AVLB Job InvtChkRsps Mgt";
    }
}

enum 50601 "AVLB Setup Constants"
{
    // Setup Id's - Inventory Check
    value(200; "SetupInventoryChkActive") { }
    value(201; "SetupInventoryChkLocation") { }
    value(202; "SetupCapableToPromiseFormula") { }
    value(203; "SetupOauth2ChkInventoryUrl") { Caption = 'https://api.businesscentral.dynamics.com/v2.0/%1/%2/ODataV4/AvailabilityApi_InventoryCheck?company=(%3)', Locked = true; }
    value(204; "SetupOauth2TokenUrl") { Caption = 'https://login.microsoftonline.com/%1/oauth2/v2.0/token', Locked = true; }
    value(205; "SetupOauth2ClientId") { }
    value(206; "SetupOauth2ClientSecret") { }
    value(207; "SetupOauth2TenantId") { }
    value(208; "SetupOauth2Environment") { }
    value(209; "SetupOauth2CompanyGuid") { }
    value(212; "SetupInventoryChkAbakionUserID") { }
    value(214; "IFW") { }               // Job Queue Category Code
    value(215; "3") { }                 // SecondsToStart RunWithJobQueue
}
