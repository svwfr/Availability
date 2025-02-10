namespace Byx.Availability;
using Microsoft.Inventory.Tracking;
codeunit 50611 "AVLB Inventory Match Engine"
{
    procedure MoveTrackingEntries(ReservationEntry: Record "Reservation Entry"; NewDate: Date)
    var
        ReservEntryIn: Record "Reservation Entry";
        ReservEntryOut: Record "Reservation Entry";
    begin
        exit; //tenke mer på å flytte behovet med forsyning
        ReservEntryIn.SetCurrentKey("Source Type", "Source Subtype", "Source ID", "Source Batch Name", "Source Prod. Order Line", "Source Ref. No.");
        ReservEntryIn.SetRange(Positive, true);
        ReservEntryIn.SetRange("Source Type", ReservationEntry."Source Type");
        ReservEntryIn.SetRange("Source ID", ReservationEntry."Source ID");
        ReservEntryIn.SetRange("Source Ref. No.", ReservationEntry."Source Ref. No.");
        ReservEntryIn.LoadFields("Entry No.");
        if ReservEntryIn.FindSet() then
            repeat
                if ReservEntryOut.Get(ReservEntryIn."Entry No.", false) then
                    if ReservEntryOut."Shipment Date" < NewDate then begin
                        ReservEntryOut."Shipment Date" := NewDate;
                        ReservEntryOut.Modify()
                    end;
            until ReservEntryIn.Next() = 0;
    end;
}