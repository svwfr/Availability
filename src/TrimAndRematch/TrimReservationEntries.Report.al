namespace Byx.Availability;
using Microsoft.Inventory.Item;
report 50600 "AVLB Trim Reservation Entries"
{
    Caption = 'Trim Reservation Entries', Locked = true;
    UsageCategory = Tasks;
    ApplicationArea = All;
    ProcessingOnly = true;
    Description = 'Loop through all items, to first remove the demand from reservation entries, before recreate tracking';

    dataset
    {
        dataitem(Item; Item)
        {
            RequestFilterFields = "No.", "Variant Filter";
            trigger OnAfterGetRecord()
            begin
                if Item."No." = '' then
                    exit;
                RecreateMatching.UpdateDiffILEQty(Item);
                if TrimReservMgt.RemoveDemand(Item."No.") then begin
                    TrimReservMgt.DefragPositiveSurplus(Item."No.", item."Variant Filter");
                    TrimReservMgt.ReAddDemand(Item."No.");
                    TrimCount += 1;
                end else
                    TrimReservMgt.DefragPositiveSurplus(Item."No.", "Variant Filter");
            end;

            trigger OnPostDataItem()
            var
                FinishMsg: Label 'finished down and up :)\ Number items handles: %1', Locked = true;
            begin
                if GuiAllowed then
                    Message(FinishMsg, TrimCount);
            end;
        }
    }

    var
        TrimReservMgt: Codeunit "AVLB Trim Reservation Mgt";
        RecreateMatching: Codeunit "AVLB Reserv Matching Recreate";
        TrimCount: Integer;
}