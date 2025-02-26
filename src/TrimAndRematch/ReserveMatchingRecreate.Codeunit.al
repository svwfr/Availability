namespace Bragda.Availability;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Transfer;
using Microsoft.Sales.Document;
using Microsoft.Foundation.Company;

codeunit 50617 "AVLB Reserv Matching Recreate"
{
    trigger OnRun()
    var
        TimeStart: Time;
        TimeEnded: Time;
        FinishMsg: Label 'Job is done and process time was: %1 sek', Locked = true;
        FinishTrimMsg: Label 'Finished with trimming\ Number of items handled: %1', Locked = true;
    begin
        SetMainLocation();
        TimeStart := Time;
        ClearGhostSurplus();
        HandlingDiffStockQty();
        HandlingMissingTransfQty();
        HandleMissingTransferOrdre();
        RematchSurplusOrderLines();
        TimeEnded := Time;
        if GuiAllowed and not HideDialog then begin
            Message(FinishMsg, (TimeEnded - TimeStart) / 1000);
            Message(FinishTrimMsg, TrimCount);
        end;
    end;

    procedure SetHideDialog(Hide: Boolean)
    begin
        HideDialog := Hide;
    end;

    procedure SetReportOnly(NewValue: Boolean)
    begin
        ReportOnly := NewValue;
    end;

    procedure UpdateDiffILEQty(Item: Record Item)
    var
        ReservEntry: Record "Reservation Entry";
        ItemLedgEntry: Record "Item Ledger Entry";
        DiffToAdj: Decimal;
    begin
        SetMainLocation(); //remove when local
        ReservEntry.SetCurrentKey("Item No.", "Variant Code", "Location Code", "Reservation Status", "Shipment Date", "Expected Receipt Date", "Serial No.", "Lot No.", "Package No.");
        ReservEntry.SetRange("Item No.", Item."No.");
        ReservEntry.SetRange("Location Code", MainLocation);
        ReservEntry.SetRange("Source Type", Database::"Item Ledger Entry");

        ItemLedgEntry.SetRange("Location Code", MainLocation);
        ItemLedgEntry.SetRange("Item No.", Item."No.");
        ItemLedgEntry.SetRange(Open, true);
        ItemLedgEntry.SetRange(Positive, true);
        ItemLedgEntry.SetBaseLoadFields();
        if ItemLedgEntry.FindSet() then
            repeat
                ReservEntry.SetRange("Reservation Status");
                ReservEntry.SetRange("Source Ref. No.", ItemLedgEntry."Entry No.");
                if ReservEntry.IsEmpty then
                    ReservEntry."Quantity (Base)" := 0
                else
                    ReservEntry.CalcSums("Quantity (Base)");
                if ReservEntry."Quantity (Base)" <> ItemLedgEntry."Remaining Quantity" then begin
                    DiffToAdj := ItemLedgEntry."Remaining Quantity" - ReservEntry."Quantity (Base)";
                    ReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
                    if ReservEntry.FindFirst() then begin
                        ReservEntry.CalcSums("Quantity (Base)");
                        ReservEntry.Validate("Quantity (Base)", ReservEntry."Quantity (Base)" + DiffToAdj);
                        ReservEntry.Modify();
                        NumbILEQtyUpdate += 1;
                    end else if DiffToAdj > 0 then begin
                        ReservEntry."Entry No." := 0; //autoincremt
                        ReservEntry.Positive := true;
                        ReservEntry."Item No." := Item."No.";
                        ReservEntry."Variant Code" := ItemLedgEntry."Variant Code";
                        ReservEntry.Description := Item.Description;
                        ReservEntry."Location Code" := MainLocation;
                        ReservEntry."Source Type" := Database::"Item Ledger Entry";
                        ReservEntry."Source Ref. No." := ItemLedgEntry."Entry No.";
                        ReservEntry.Validate("Quantity (Base)", ItemLedgEntry."Remaining Quantity");
                        ReservEntry."Reservation Status" := "Reservation Status"::Surplus;
                        ReservEntry."Creation Date" := Today;
                        ReservEntry."Created By" := CopyStr(UserId, 1, MaxStrLen(ReservEntry."Created By"));
                        if ReservEntry.Insert() then
                            NumbNewEntry += 1;
                    end;
                end;
            until ItemLedgEntry.Next() = 0;
    end;

    local procedure ClearGhostSurplus()
    var
        ReservEntry: Record "Reservation Entry";
        Location: Record Location;
        GhostToDeleteMsg: Label 'There are %1 surplus in Transit (%2) as can be deleted', Locked = true;
    begin
        Location.SetRange("Use As In-Transit", true);
        Location.SetBaseLoadFields();
        if Location.FindSet() then
            repeat
                ReservEntry.SetRange("Reservation Status", ReservEntry."Reservation Status"::Surplus);
                ReservEntry.SetRange("Location Code", Location.Code);
                if not ReservEntry.IsEmpty then begin
                    if ReportOnly then
                        Message(GhostToDeleteMsg, ReservEntry.Count, Location.Name);
                    ReservEntry.DeleteAll();
                end;
            until Location.Next() = 0;
    end;

    local procedure HandlingDiffStockQty()
    var
        Item: Record Item;
        CalcedILEQty: Decimal;
        TxtBuilder: TextBuilder;
        NumbDiffQty: Integer;
        FinishMsg: Label 'We did not track all quanties, and are now recreated:\Updated: %1\ New Created: %2\ Unchanged: %3\ Items: %4', Locked = true;
        OkMsg: Label 'The stock quanties where in sync for location: %1', Locked = true;
    begin
        Item.SetFilter("Location Filter", MainLocation);
        Item.SetAutoCalcFields(Inventory);
        Item.LoadFields(Inventory);
        if Item.FindSet() then
            repeat
                if Item.Inventory > 0 then begin
                    CalcedILEQty := CalcILEQty(Item."No.");
                    if Item.Inventory <> CalcedILEQty then begin
                        if not ReportOnly then
                            UpdateDiffILEQty(Item);
                        TxtBuilder.AppendLine(Item."No.");
                        NumbDiffQty += 1;
                    end;
                end;
            until Item.Next() = 0;

        if GuiAllowed and not HideDialog then begin
            if NumbDiffQty > 0 then
                Message(FinishMsg, NumbILEQtyUpdate, NumbNewEntry, NumbDiffQty - (NumbILEQtyUpdate + NumbNewEntry), TxtBuilder.ToText())
            else
                Message(OkMsg, MainLocation);
        end;
    end;

    local procedure HandlingMissingTransfQty()
    var
        TransLn: Record "Transfer Line";
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetRange("Source Type", Database::"Transfer Line");
        ReservEntry.SetRange("Location Code", MainLocation);
        TransLn.SetRange("Transfer-to Code", MainLocation);
        TransLn.SetFilter("Outstanding Quantity", '>0');
        TransLn.SetBaseLoadFields();
        if TransLn.FindSet() then
            repeat
                ReservEntry.SetRange("Source ID", TransLn."Document No.");
                ReservEntry.SetRange("Source Ref. No.", GetSourceRefNo(TransLn));
                ReservEntry.SetBaseLoadFields();
                if ReservEntry.FindFirst() then begin
                    ReservEntry.CalcSums("Quantity (Base)");
                    if ReservEntry."Quantity (Base)" < TransLn."Qty. to Receive (Base)" then
                        RepairTransfQty2Reserv(TransLn."Qty. to Receive (Base)" - ReservEntry."Quantity (Base)", TransLn);
                end;
            until TransLn.Next() = 0;
    end;

    local procedure CalcILEQty(ItemNo: Code[20]) ILEqty: Decimal
    var
        ReservationEntry: Record "Reservation Entry";
    begin
        ReservationEntry.SetCurrentKey("Item No.", "Variant Code", "Location Code", "Reservation Status", "Shipment Date", "Expected Receipt Date", "Serial No.", "Lot No.", "Package No.");
        ReservationEntry.SetRange("Item No.", ItemNo);
        ReservationEntry.SetRange("Location Code", MainLocation);
        ReservationEntry.SetRange("Source Type", Database::"Item Ledger Entry");
        ReservationEntry.SetBaseLoadFields();
        if ReservationEntry.FindFirst() then begin
            ReservationEntry.CalcSums("Quantity (Base)");
            ILEqty := ReservationEntry."Quantity (Base)";
        end;
    end;

    local procedure HandleMissingTransferOrdre()
    var
        TransLn: Record "Transfer Line";
        ReservEntry: Record "Reservation Entry";
        TransTxtBuilder: TextBuilder;
        ItemTrimList: List of [Code[20]];
        Transf2RecreateList: List of [Code[20]];
        LineNo: Integer;
        FinishMsg: Label 'Number of Transfer Orders found missing: %1\%2. Number of reservation entries modified qty: %3, and nubmer rebuild: %4.', Locked = true;
        OkMsg: Label 'All transfer orders are in place', Locked = true;
    begin
        ReservEntry.SetRange("Source Type", Database::"Transfer Line");
        ReservEntry.SetRange("Location Code", MainLocation);
        TransLn.SetRange("Transfer-to Code", MainLocation);
        TransLn.SetFilter("Outstanding Quantity", '>0');
        TransLn.SetBaseLoadFields();
        if TransLn.FindSet() then
            repeat
                ReservEntry.SetRange("Source ID", TransLn."Document No.");
                LineNo := GetSourceRefNo(TransLn);
                ReservEntry.SetRange("Source Ref. No.", LineNo);
                if ReservEntry.IsEmpty and not Transf2RecreateList.Contains(TransLn."Document No.") then begin
                    TransTxtBuilder.AppendLine(TransLn."Document No.");
                    Transf2RecreateList.Add(TransLn."Document No.");
                end;
            until TransLn.Next() = 0;

        if (Transf2RecreateList.Count > 0) and not ReportOnly then begin
            ItemTrimList := RecreateQty2Reserv(Transf2RecreateList);
            TrimSelectedItems(ItemTrimList);
        end;

        if GuiAllowed and not HideDialog then begin
            if Transf2RecreateList.Count = 0 then
                Message(OkMsg)
            else
                Message(FinishMsg, Transf2RecreateList.Count, TransTxtBuilder.ToText(), NumbTranfQtyUpdate, NumbNewEntry);
        end;
    end;

    local procedure GetSourceRefNo(TransLn: Record "Transfer Line") SourceRef: Integer
    var
        TransLnDer: Record "Transfer Line";
    begin
        TransLnDer.SetRange("Document No.", TransLn."Document No.");
        TransLnDer.SetRange("Derived From Line No.", TransLn."Line No.");
        if TransLnDer.FindFirst() then
            SourceRef := TransLnDer."Line No."
        else
            SourceRef := TransLn."Line No.";
    end;

    local procedure RecreateQty2Reserv(Transf2RecreateList: List of [Code[20]]) ItemTrimList: List of [Code[20]]
    var
        TransferLine: Record "Transfer Line";
        TransfNo: Code[20];
        DiffQty: Decimal;
    begin
        foreach TransfNo in Transf2RecreateList do begin
            TransferLine.SetRange("Document No.", TransfNo);
            TransferLine.SetFilter("Outstanding Quantity", '>0');
            TransferLine.SetBaseLoadFields();
            if TransferLine.FindSet() then begin
                repeat
                    DiffQty := TransferLine."Quantity (Base)" - CalcTotResrvSourcRefQty(TransferLine);
                    if DiffQty > 0 then begin
                        if not ItemTrimList.Contains(TransferLine."Item No.") then
                            ItemTrimList.Add(TransferLine."Item No.");
                        RepairTransfQty2Reserv(DiffQty, TransferLine);
                    end;
                until TransferLine.Next() = 0;
            end;
        end;
    end;

    local procedure CalcTotResrvSourcRefQty(TransLn: Record "Transfer Line") TotSrcLineQty: Decimal;
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetCurrentKey("Source ID", "Source Ref. No.", "Source Type", "Source Subtype", "Source Batch Name", "Source Prod. Order Line", "Reservation Status", "Shipment Date", "Expected Receipt Date");
        ReservEntry.SetRange("Source ID", TransLn."Document No.");
        ReservEntry.SetRange("Source Ref. No.", TransLn."Line No.");
        ReservEntry.SetRange("Source Type", Database::"Transfer Line");
        ReservEntry.SetRange("Location Code", MainLocation);
        repeat
            TotSrcLineQty += ReservEntry."Quantity (Base)";
        until ReservEntry.Next() = 0;
    end;

    local procedure RepairTransfQty2Reserv(DiffQty: Decimal; TransLn: Record "Transfer Line")
    var
        ReservEntry: Record "Reservation Entry";
        SourceRefNo: Integer;
    begin
        //Check if we can modify an existing surplus
        SourceRefNo := GetSourceRefNo(TransLn);
        ReservEntry.SetCurrentKey("Source ID", "Source Ref. No.", "Source Type", "Source Subtype", "Source Batch Name", "Source Prod. Order Line", "Reservation Status", "Shipment Date", "Expected Receipt Date");
        ReservEntry.SetRange("Source ID", TransLn."Document No.");
        ReservEntry.SetRange("Source Type", Database::"Transfer Line");
        ReservEntry.SetRange("Source Ref. No.", SourceRefNo);
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        ReservEntry.SetRange("Expected Receipt Date", TransLn."Receipt Date");
        ReservEntry.SetRange(Positive, true);
        ReservEntry.SetRange("Item No.", TransLn."Item No.");
        ReservEntry.SetRange("Location Code", TransLn."Transfer-to Code");
        if ReservEntry.FindFirst() then begin
            ReservEntry.Validate("Quantity (Base)", (ReservEntry."Quantity (Base)" + DiffQty));
            if ReservEntry.Modify() then
                NumbTranfQtyUpdate += 1;
            exit;
        end else
            CreateNewTransfSurplus(TransLn, DiffQty);
    end;

    local procedure CreateNewTransfSurplus(TransfLn: Record "Transfer Line"; DiffQty: Decimal)
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.Init();
        ReservEntry."Entry No." := 0; //autoincremt
        ReservEntry.Positive := true;
        ReservEntry."Reservation Status" := "Reservation Status"::Surplus;
        ReservEntry."Item No." := TransfLn."Item No.";
        ReservEntry."Variant Code" := TransfLn."Variant Code";
        ReservEntry.Description := TransfLn.Description;
        ReservEntry."Location Code" := TransfLn."Transfer-to Code";
        ReservEntry.Validate("Quantity (Base)", DiffQty);
        ReservEntry."Source Type" := Database::"Transfer Line";
        ReservEntry."Source Subtype" := 1;
        ReservEntry."Source ID" := TransfLn."Document No.";
        ReservEntry."Source Ref. No." := TransfLn."Line No.";
        ReservEntry."Expected Receipt Date" := TransfLn."Receipt Date";
        ReservEntry."Creation Date" := Today;
        ReservEntry."Created By" := CopyStr(UserId, 1, MaxStrLen(ReservEntry."Created By"));
        if ReservEntry.Insert() then
            NumbNewEntry += 1;
    end;

    local procedure RematchSurplusOrderLines()
    var
        ReservEntry: Record "Reservation Entry";
        ItemTrimList: List of [Code[20]];
    begin
        ReservEntry.SetRange("Source Type", Database::"Sales Line");
        ReservEntry.SetRange("Location Code", MainLocation);
        ReservEntry.SetRange("Reservation Status", ReservEntry."Reservation Status"::Surplus);
        ReservEntry.SetLoadFields("Item No.");
        if ReservEntry.FindSet() then
            repeat
                if not ItemTrimList.Contains(ReservEntry."Item No.") then
                    ItemTrimList.Add(ReservEntry."Item No.");
            until ReservEntry.Next() = 0;
        TrimSelectedItems(ItemTrimList);
    end;

    local procedure TrimSelectedItems(Item2TrimList: List of [Code[20]])
    var
        ItemNo: Code[20];
    begin
        foreach ItemNo in Item2TrimList do begin
            if TrimReservMgt.RemoveDemand(ItemNo) then begin
                TrimReservMgt.DefragPositiveSurplus(ItemNo, '');
                TrimReservMgt.ReAddDemand(ItemNo);
                TrimCount += 1;
            end;
        end;
    end;

    local procedure SetMainLocation()
    var
        CompanyInformation: Record "Company Information";
    begin
        if MainLocation = '' then begin
            CompanyInformation.get();
            CompanyInformation.TestField("Location Code");
            MainLocation := CompanyInformation."Location Code";
        end
    end;

    var
        TrimReservMgt: Codeunit "AVLB Trim Reservation Mgt";
        MainLocation: Code[10];
        NumbTranfQtyUpdate: Integer;
        NumbILEQtyUpdate: Integer;
        NumbNewEntry: Integer;
        TrimCount: Integer;
        ReportOnly: Boolean;
        HideDialog: Boolean;
}