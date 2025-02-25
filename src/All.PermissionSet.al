permissionset 50600 "Byx Availability"
{
    Access = Internal;
    Assignable = true;
    Caption = 'All permissions', Locked = true;
    Permissions = codeunit "AVLB Auto Match Sales Line"=X,
        codeunit "AVLB Setup Tools Mgt"=X,
        codeunit "AVLB ErrorInfoAction"=X,
        codeunit "AVLB IC Management"=X,
        codeunit "AVLB IFW Tools Mgt"=X,
        codeunit "AVLB Integration Mgt"=X,
        codeunit "AVLB Inventory Check Mgt."=X,
        codeunit "AVLB Inventory Match Engine"=X,
        codeunit "AVLB Invt.Check Event Sub."=X,
        codeunit "AVLB Job InvtChkRqst Mgt"=X,
        codeunit "AVLB Job InvtChkRsps Mgt"=X,
        codeunit "AVLB Json Management"=X,
        codeunit "AVLB Reserv Matching Recreate"=X,
        codeunit "AVLB Setup Mgt"=X,
        codeunit "AVLB Single Instance Mgt"=X,
        codeunit "AVLB Steal Engine Mgt."=X,
        codeunit "AVLB Transf-Reserv Report"=X,
        codeunit "AVLB Trim Reservation Mgt"=X,
        codeunit "AVLB WebServiceApi Mgt"=X,
        codeunit "AVLB WebServiceHttp Mgt"=X,
        page "AVLB Availability Setup"=X,
        page "AVLB Inventory Check List"=X,
        report "AVLB Trim Reservation Entries"=X,
        codeunit "AVLB Auto Match Transf Line"=X,
        codeunit "AVLB IFW Event Subscriptions"=X,
        codeunit "AVLB Sandbox Cleaner"=X,
        tabledata "AVLB Availability Sku"=RIMD,
        table "AVLB Availability Sku"=X,
        codeunit "AVLB Availability Mgt"=X,
        page "AVLB Available Sku FB"=X,
        query "AVLB Calc SKU Qty. Query"=X;
}