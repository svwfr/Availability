namespace Byx.Availability;

using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Microsoft.Inventory.Transfer;

codeunit 50609 "AVLB Invt.Check Event Sub."
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Sales Document", 'OnBeforeReleaseSalesDoc', '', false, false)]
    local procedure BeforeReleaseSalesDoc(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean; var IsHandled: Boolean; var SkipCheckReleaseRestrictions: Boolean)
    var
        IfwLog: Record "IFW Log";
        InvtChkRqstMgt: Codeunit "AVLB Job InvtChkRqst Mgt";
    begin
        if PreviewMode then
            exit;
        if SalesHeader."Document Type" <> SalesHeader."Document Type"::Order then
            exit;
        if not SkipCheckReleaseRestrictions then
            if InvtChkRqstMgt.CreateInvtCheckLogEntry(SalesHeader, IfwLog) then
                IsHandled := not InvtChkRqstMgt.RunInvCheckLogEntry(IfwLog);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reservation-Check Date Confl.", OnBeforeUpdateDate, '', false, false)]
    local procedure OnBeforeUpdateDate(var ReservationEntry: Record "Reservation Entry"; NewDate: Date; var IsHandled: Boolean);
    begin
        if ReservationEntry.Positive and (ReservationEntry."Expected Receipt Date" <> 0D) then
            InvtMatchEngine.MoveTrackingEntries(ReservationEntry, NewDate)
    end;

    var
        InvtChkRqstMgt: Codeunit "AVLB Job InvtChkRqst Mgt";
        InvtChkRspsMgt: Codeunit "AVLB Job InvtChkRsps Mgt";
        InvtMatchEngine: Codeunit "AVLB Inventory Match Engine";
        SetupMgt: Codeunit "AVLB Setup Mgt";
        IfwJobIds: Enum "IFW Job Id";
        v: Record "Transfer Line" temporary;
}