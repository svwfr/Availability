namespace Bragda.Availability;
codeunit 50600 "AVLB WebServiceApi Mgt"
{
    var
        JobInvtChkRspsMgt: Codeunit "AVLB Job InvtChkRsps Mgt";

    procedure InventoryCheck(jsonRequest: Text) JsonResponse: Text
    begin
        GlobalLanguage(1044);
        JsonResponse := JobInvtChkRspsMgt.CreateLogEntry(jsonRequest);
    end;
}
