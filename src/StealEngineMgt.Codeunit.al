namespace Bragda.Availability;
using Microsoft.Sales.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Ledger;
codeunit 50616 "AVLB Steal Engine Mgt."
{
    procedure AbelToStealStock(ThiefEntry: Record "Reservation Entry"; DateForCTP: Date): Boolean
    var
        ReservEntry: Record "Reservation Entry";
        QtyNegSurplus: Decimal;
        FirstSurplusIncome: Date;
        Datefilter: Text;
    begin
        if ThiefEntry."Source Type" <> Database::"Sales Line" then
            exit(false);
        QtyNegSurplus := ThiefEntry."Quantity (Base)";

        if FreeCTPtracked2ILE(ThiefEntry, QtyNegSurplus, DateForCTP, ReservEntry) then
            exit(true);

        FirstSurplusIncome := Find1stSurplusIncome(ThiefEntry."Item No.", ThiefEntry."Location Code");
        if FirstSurplusIncome = 0D then
            exit(false);

        if FreeILE_Match2Inbound(ThiefEntry, FirstSurplusIncome, QtyNegSurplus, DateForCTP, ReservEntry) then
            exit(true);

        if not FindIncomeFilter(ThiefEntry."Item No.", ThiefEntry."Location Code", ThiefEntry."Shipment Date", Datefilter) then
            exit(false);

        if PostponeAllInboundMatch(ThiefEntry."Item No.", ThiefEntry."Location Code", Datefilter, QtyNegSurplus) then
            exit(true);

        exit(false);
    end;

    local procedure FreeCTPtracked2ILE(ThiefEntry: Record "Reservation Entry"; QtyNegSurplus: Decimal; DateForCTP: Date; var ReservEntry: Record "Reservation Entry"): Boolean
    var
        Qty2Steal: Decimal;
    begin
        //orders beyond CTP, but has reserved to stock can be stealed!
        ReservEntry.SetCurrentKey("Item No.", "Variant Code", "Location Code", "Reservation Status", "Shipment Date", "Expected Receipt Date", "Serial No.", "Lot No.", "Package No.");
        ReservEntry.SetRange(Positive, true);
        ReservEntry.SetRange("Item No.", ThiefEntry."Item No.");
        ReservEntry.SetRange("Location Code", ThiefEntry."Location Code");
        ReservEntry.SetFilter("Shipment Date", '>=%1', DateForCTP);
        ReservEntry.SetRange("Source Type", Database::"Item Ledger Entry");
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Tracking);
        ReservEntry.LoadFields(Quantity);
        if ReservEntry.FindSet() then
            repeat
                Qty2Steal += ReservEntry.Quantity;
                ClearMatching(ReservEntry."Entry No.");
                if Qty2Steal >= Abs(QtyNegSurplus) then
                    exit(true);
            until ReservEntry.Next() = 0;
    end;

    local procedure FreeILE_Match2Inbound(ThiefEntry: Record "Reservation Entry"; FirstSurplusIncome: Date; QtyNegSurplus: Decimal; DateForCTP: Date; var ReservEntry: Record "Reservation Entry"): Boolean
    var
        Qty2Steal: Decimal;
        NoInboundToMatch: Boolean;
    begin
        //Find tracked ILE with shipment date betweeen 1st surplus income to ctp. 
        //These outbounds can be moved to a later income
        ReservEntry.SetRange("Shipment Date", FirstSurplusIncome, DateForCTP);
        if ReservEntry.FindSet() then
            repeat
                if ReMatchReceiptDate(ReservEntry, NoInboundToMatch) then
                    Qty2Steal += ReservEntry.Quantity;
                if Qty2Steal >= Abs(QtyNegSurplus) then begin
                    MatchThiefEntry(ThiefEntry."Source ID", ThiefEntry."Source Ref. No.");
                    exit(true);
                end;
            until NoInboundToMatch or (ReservEntry.Next() = 0);
        if Qty2Steal > 0 then
            MatchThiefEntry(ThiefEntry."Source ID", ThiefEntry."Source Ref. No.");
    end;

    local procedure ClearMatching(EntryNo: Integer)
    var
        ReservEntry: Record "Reservation Entry";
        NewFreeEntry: Record "Reservation Entry";
    begin
        if ReservEntry.Get(EntryNo, true) then begin
            ReservEntry."Reservation Status" := "Reservation Status"::Surplus;
            ReservEntry."Shipment Date" := 0D;
            NewFreeEntry := ReservEntry;
            NewFreeEntry."Entry No." := 0; //AutoIncrement
            NewFreeEntry.Insert();
            ReservEntry.Delete();
        end;
        if ReservEntry.Get(EntryNo, false) then begin
            ReservEntry."Reservation Status" := "Reservation Status"::Surplus;
            ReservEntry.Modify();
        end;
    end;

    local procedure Find1stSurplusIncome(ItemNo: Code[20]; Location: Code[10]): Date
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetCurrentKey("Reservation Status", "Item No.", "Variant Code", "Location Code", "Expected Receipt Date");
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        ReservEntry.SetRange("Item No.", ItemNo);
        ReservEntry.SetRange("Location Code", Location);
        ReservEntry.SetRange(Positive, true);
        if ReservEntry.FindFirst() then
            exit(ReservEntry."Expected Receipt Date")
        else
            exit(0D);
    end;

    local procedure FindIncomeFilter(ItemNo: Code[20]; Location: Code[10]; ThiefShipmentDate: Date; var Datefilter: Text): Boolean
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetCurrentKey("Reservation Status", "Item No.", "Variant Code", "Location Code", "Expected Receipt Date");
        ReservEntry.SetRange("Item No.", ItemNo);
        ReservEntry.SetRange("Location Code", Location);
        ReservEntry.SetFilter("Expected Receipt Date", '<=%1', ThiefShipmentDate);
        ReservEntry.SetFilter("Source Type", '<>%1', Database::"Item Ledger Entry");
        ReservEntry.SetRange(Positive, true);
        if ReservEntry.FindFirst() then begin
            Datefilter := Format(ReservEntry."Expected Receipt Date");
            ReservEntry.FindLast();
            Datefilter += StrSubstNo('..%1', ReservEntry."Expected Receipt Date");
            exit(true);
        end;
    end;

    local procedure PostponeAllInboundMatch(ItemNo: Code[20]; Location: Code[10]; Datefilter: Text; QtyNegSurplus: Decimal): Boolean
    var
        MatchedOutboundToMove: Record "Reservation Entry";
        Qty2Steal: Decimal;
        NoInboundToMatch: Boolean;
    begin
        //Find tracked outbound which has been matched with an inbound receipt date within the Theif's shipment date.
        //Check if tracked outbounds can be moved to a later income
        MatchedOutboundToMove.SetCurrentKey("Item No.", "Variant Code", "Location Code", "Reservation Status", "Shipment Date", "Expected Receipt Date", "Serial No.", "Lot No.", "Package No.");
        MatchedOutboundToMove.Ascending(false);
        MatchedOutboundToMove.SetRange("Item No.", ItemNo);
        MatchedOutboundToMove.SetRange("Location Code", Location);
        MatchedOutboundToMove.SetRange("Reservation Status", "Reservation Status"::Tracking);
        MatchedOutboundToMove.SetFilter("Expected Receipt Date", Datefilter);
        MatchedOutboundToMove.SetFilter("Shipment Date", '>%1', MatchedOutboundToMove.GetRangeMax("Expected Receipt Date"));
        MatchedOutboundToMove.SetFilter("Source Type", '<>%1', Database::"Item Ledger Entry");
        MatchedOutboundToMove.SetRange(Positive, false);
        if MatchedOutboundToMove.FindSet() then
            repeat
                if ReMatchReceiptDate(MatchedOutboundToMove, NoInboundToMatch) then
                    Qty2Steal += MatchedOutboundToMove.Quantity;
                if Qty2Steal >= Abs(QtyNegSurplus) then
                    exit(true);
            until NoInboundToMatch or (MatchedOutboundToMove.Next() = 0);
    end;

    local procedure ReMatchReceiptDate(EntryToFree: Record "Reservation Entry"; var NoInboundToMatch: Boolean) SuccessToFree: Boolean
    var
        NewInboundEntry: Record "Reservation Entry";
        EntriesToMatch: Dictionary of [Integer, Decimal];
        QtyToMatch: Decimal;
    begin
        //Find new later surplus income that the outbound can match
        NewInboundEntry.SetCurrentKey("Reservation Status", "Item No.", "Variant Code", "Location Code", "Expected Receipt Date");
        NewInboundEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        NewInboundEntry.SetRange("Item No.", EntryToFree."Item No.");
        NewInboundEntry.SetRange("Location Code", EntryToFree."Location Code");
        NewInboundEntry.SetFilter("Expected Receipt Date", '<=%1', EntryToFree."Shipment Date");
        NewInboundEntry.SetFilter("Source ID", '<>%1', EntryToFree."Source ID");
        NewInboundEntry.SetRange(Positive, true);
        NewInboundEntry.LoadFields(Quantity);
        if NewInboundEntry.FindSet() then
            repeat
                //Only move if able to move for later receipt date
                if NewInboundEntry."Expected Receipt Date" > EntryToFree."Expected Receipt Date" then begin
                    QtyToMatch += NewInboundEntry."Quantity (Base)";
                    EntriesToMatch.Add(NewInboundEntry."Entry No.", NewInboundEntry.Quantity);
                end;
            until (NewInboundEntry.Next() = 0) or (QtyToMatch >= EntryToFree.Quantity)
        else
            NoInboundToMatch := true;

        if EntriesToMatch.Count > 0 then begin
            ReMatchInbound(EntryToFree."Entry No.", EntriesToMatch);
            if QtyToMatch < EntryToFree."Quantity (Base)" then
                SuccessToFree := SplitEntry2Free(EntryToFree, QtyToMatch)
            else begin
                EntryToFree."Reservation Status" := "Reservation Status"::Surplus;
                SuccessToFree := EntryToFree.Modify();
            end;
        end;
    end;

    local procedure ReMatchInbound(EntryToMove: Integer; EntriesToMatch: Dictionary of [Integer, Decimal])
    var
        EntryRec2Move: Record "Reservation Entry";
        EntryRecOld: Record "Reservation Entry";
        InboundEntryRec: Record "Reservation Entry";
        SurplusEntryRec: Record "Reservation Entry";
        InboundEntryNo: Integer;
        TotRematchQty: Decimal;
        MatchedQtyBase: Decimal;
        InboundQtyBase: Decimal;
        DeleteOldMatch: Boolean;
    begin
        MatchedQtyBase := 0;
        EntryRec2Move.Get(EntryToMove, false);
        TotRematchQty := Abs(EntryRec2Move."Quantity (Base)");
        foreach InboundEntryNo in EntriesToMatch.Keys() do begin
            InboundEntryRec.Get(InboundEntryNo, true);
            InboundQtyBase := InboundEntryRec."Quantity (Base)";
            if Abs(EntryRec2Move."Quantity (Base)") > InboundQtyBase then
                EntryRec2Move.Validate("Quantity (Base)", (InboundQtyBase * -1))
            else
                DeleteOldMatch := true;
            EntryRec2Move."Expected Receipt Date" := InboundEntryRec."Expected Receipt Date";
            EntryRec2Move."Entry No." := InboundEntryNo;
            EntryRec2Move.Insert();
            if EntryRecOld.Get(EntryToMove, false) then
                if DeleteOldMatch then
                    EntryRecOld.Delete(true)
                else begin
                    EntryRecOld.Validate("Quantity (Base)", ((Abs(EntryRecOld."Quantity (Base)") - InboundQtyBase)) * -1);
                    EntryRecOld.Modify();
                end;

            InboundEntryRec."Shipment Date" := EntryRec2Move."Shipment Date";
            InboundEntryRec."Reservation Status" := "Reservation Status"::Tracking;

            if Abs(EntryRec2Move."Quantity (Base)") < InboundQtyBase then
                InboundEntryRec.Validate("Quantity (Base)", Abs(EntryRec2Move."Quantity (Base)"));
            InboundEntryRec.Modify();

            if TotRematchQty = InboundQtyBase + MatchedQtyBase then
                exit;

            if TotRematchQty < InboundQtyBase + MatchedQtyBase then begin
                // split inbound qty
                SurplusEntryRec := InboundEntryRec;
                SurplusEntryRec.Validate("Quantity (Base)", (InboundQtyBase + MatchedQtyBase - TotRematchQty));
                SurplusEntryRec."Reservation Status" := "Reservation Status"::Surplus;
                SurplusEntryRec."Shipment Date" := 0D;
                SurplusEntryRec."Entry No." := 0; //AutoIncrement
                SurplusEntryRec.Insert();
                exit;
            end else
                MatchedQtyBase += InboundQtyBase;

            if EntryRecOld.Get(EntryToMove, false) then
                EntryRec2Move := EntryRecOld
            else
                EntryRec2Move.Get(EntryToMove, false);
        end;
    end;

    local procedure MatchThiefEntry(OrderNo: Code[20]; LineNo: Integer)
    var
        SalesLn: Record "Sales Line";
        ReservMgt: Codeunit "Reservation Management";
    begin
        SalesLn.Get("Sales Document Type"::Order, OrderNo, LineNo);
        ReservMgt.SetReservSource(SalesLn);
        ReservMgt.DeleteReservEntries(true, 0);
        ReservMgt.AutoTrack(SalesLn."Outstanding Qty. (Base)");
    end;

    local procedure SplitEntry2Free(EntryToFree: Record "Reservation Entry"; QtyToMatch: Decimal): Boolean
    var
        EntryToFreeNew: Record "Reservation Entry";
    begin
        EntryToFreeNew := EntryToFree;
        EntryToFreeNew.Validate("Quantity (Base)", QtyToMatch);
        EntryToFreeNew."Reservation Status" := "Reservation Status"::Surplus;
        EntryToFreeNew."Entry No." := 0; //AutoIncrement
        if not EntryToFreeNew.Insert() then
            exit(false);
        EntryToFree.Validate("Quantity (Base)", (EntryToFree."Quantity (Base)" - QtyToMatch));
        exit(EntryToFree.Modify());
    end;

    var
}