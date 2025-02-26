namespace Bragda.Availability;

using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Item;
using Microsoft.Foundation.Company;
using Microsoft.Inventory.Transfer;
using Microsoft.Inventory.Ledger;

codeunit 50622 "AVLB Auto Match Transf Line"
{
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reservation Management", OnAutoTrackOnCheckSourceType, '', false, false)]
    local procedure AutoTrackOnCheckSourceType(var ReservationEntry: Record "Reservation Entry"; var ShouldExit: Boolean)
    begin
        if ShouldExit then
            exit;
        ShouldExit := AutoMatchTransfLine(ReservationEntry);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reservation-Check Date Confl.", OnBeforeUpdateDate, '', false, false)]
    local procedure OnBeforeUpdateDate(var ReservationEntry: Record "Reservation Entry"; NewDate: Date; var IsHandled: Boolean)
    begin
        if ReservationEntry."Source Type" <> Database::"Transfer Line" then
            exit;
        if ReservationEntry."Expected Receipt Date" >= NewDate then //Income moves to earlier date
            exit;
        SetMainLocation();
        if ReservationEntry."Location Code" <> MainLocation then
            exit;
        if SetTracked2Surplus(ReservationEntry, NewDate) then
            MoveTrackedDemand(ReservationEntry, true);
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reservation Engine Mgt.", OnBeforeCloseReservEntry, '', false, false)]
    local procedure OnBeforeCloseReservEntry(var ReservEntry: Record "Reservation Entry"; var ReTrack: Boolean; DeleteAll: Boolean; var SkipDeleteReservEntry: Boolean)
    begin
        if DeleteAll then
            exit;
        if (ReservEntry."Source Type" = Database::"Transfer Line") and ReservEntry.Positive and
        (ReservEntry."Reservation Status" = "Reservation Status"::Tracking) then
            SkipDeleteReservEntry := true;
    end;

    local procedure SetTracked2Surplus(ReservEntry: Record "Reservation Entry"; NewDate: Date) StatusChanged: Boolean
    var
        DemandEntry: Record "Reservation Entry";
        SupplyEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetPointerFilter();
        if not ReservEntry.IsEmpty then
            ReservEntry.ModifyAll("Expected Receipt Date", NewDate);
        ReservEntry.SetRange("Shipment Date", 0D, CalcDate('-1D', NewDate));
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Tracking);
        ReservEntry.SetBaseLoadFields();
        if ReservEntry.FindSet(true) then
            repeat
                SupplyEntry := ReservEntry;
                SupplyEntry."Reservation Status" := "Reservation Status"::Surplus;
                SupplyEntry."Shipment Date" := 0D;
                SupplyEntry.Modify();
                StatusChanged := true;

                if DemandEntry.Get(ReservEntry."Entry No.", false) then begin
                    DemandEntry."Reservation Status" := "Reservation Status"::Surplus;
                    DemandEntry."Expected Receipt Date" := 0D;
                    DemandEntry.Modify();
                end;
            until ReservEntry.Next() = 0;
        if ReservEntry."Source Prod. Order Line" <> 0 then begin //split shipping
            ReservEntry.SetRange("Source Ref. No.", ReservEntry."Source Prod. Order Line");
            ReservEntry.SetRange("Source Prod. Order Line");
            ReservEntry.SetRange("Shipment Date");
            ReservEntry.SetRange("Reservation Status");
            if not ReservEntry.IsEmpty then
                ReservEntry.ModifyAll("Expected Receipt Date", NewDate);
            ReservEntry.SetRange("Shipment Date", 0D, CalcDate('-1D', NewDate));
            ReservEntry.SetRange("Reservation Status", "Reservation Status"::Tracking);
            ReservEntry.SetBaseLoadFields();
            if ReservEntry.FindSet(true) then
                repeat
                    SupplyEntry := ReservEntry;
                    SupplyEntry."Reservation Status" := "Reservation Status"::Surplus;
                    SupplyEntry."Shipment Date" := 0D;
                    SupplyEntry.Modify();
                    StatusChanged := true;

                    if DemandEntry.Get(ReservEntry."Entry No.", false) then begin
                        DemandEntry."Reservation Status" := "Reservation Status"::Surplus;
                        DemandEntry."Expected Receipt Date" := 0D;
                        DemandEntry.Modify();
                    end;
                until ReservEntry.Next() = 0;
        end;
    end;

    local procedure MoveTrackedDemand(ReservEntry: Record "Reservation Entry"; IsOrigin: Boolean)
    var
        DemandEntry: Record "Reservation Entry";
        NewReservEntry: Record "Reservation Entry";
        AutoMatchSalesLn: Codeunit "AVLB Auto Match Sales Line";
    begin
        ReservEntry.SetPointerFilter();
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        ReservEntry.SetBaseLoadFields();
        if ReservEntry.FindSet() then
            repeat
                if DemandEntry.Get(ReservEntry."Entry No.", false) then begin
                    NewReservEntry := DemandEntry;
                    NewReservEntry."Entry No." := 0;
                    NewReservEntry."Reservation Status" := "Reservation Status"::Surplus;
                    NewReservEntry."Expected Receipt Date" := 0D;
                    NewReservEntry.Insert(); //new entry no as now surplus
                    DemandEntry.Delete();
                    NewReservEntry.SetPointerFilter();
                    NewReservEntry.CalcSums("Quantity (Base)");
                    AutoMatchSalesLn.SetTotalQty(NewReservEntry."Quantity (Base)");
                    AutoMatchSalesLn.MatchSalesLine(NewReservEntry);
                end;
            until ReservEntry.Next() = 0;
        if IsOrigin then
            HandleSplittTransferLine(ReservEntry)
    end;

    local procedure HandleSplittTransferLine(ReservEntry: Record "Reservation Entry")
    var
        SplittTransfLnEntry: Record "Reservation Entry";
    begin
        SplittTransfLnEntry.SetRange("Transferred from Entry No.", ReservEntry."Entry No.");
        SplittTransfLnEntry.SetBaseLoadFields();
        if SplittTransfLnEntry.FindSet() then
            repeat
                MoveTrackedDemand(SplittTransfLnEntry, false);
            until SplittTransfLnEntry.Next() = 0;
    end;

    local procedure AutoMatchTransfLine(ReservEntry: Record "Reservation Entry") SkipDefaultAutoMatch: Boolean
    var
        Item: Record Item;
        SupplyReservEntry: Record "Reservation Entry";
        SupplyEntry: Record "Reservation Entry";
        OriginEntry: Record "Reservation Entry";
        TransLn: Record "Transfer Line";
        TrimReservMgt: Codeunit "AVLB Trim Reservation Mgt";
        QtyToCreate: Decimal;
        QtyToTrack: Decimal;
    begin
        if ReservEntry."Source Type" <> Database::"Transfer Line" then
            exit;
        if ReservEntry."Item No." = '' then
            exit;
        Item.Get(ReservEntry."Item No.");
        if Item."Order Tracking Policy" = Item."Order Tracking Policy"::None then
            exit;
        SetMainLocation();
        ReservEntry.SetPointerFilter();
        SupplyReservEntry.CopyFilters(ReservEntry);
        SupplyReservEntry.SetRange(Positive, true);
        SupplyReservEntry.SetRange("Source Subtype", 1);
        SupplyReservEntry.SetRange("Location Code", MainLocation);
        SupplyReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        SupplyReservEntry.SetBaseLoadFields();
        if SupplyReservEntry.FindSet() then
            repeat
                QtyToTrack := MatchDemand(SupplyReservEntry, MainLocation);
                if QtyToTrack > 0 then
                    Reprioritize(SupplyReservEntry, MainLocation, QtyToTrack);
                SkipDefaultAutoMatch := true
            until SupplyReservEntry.Next() = 0;

        if SupplyReservEntry."Source Prod. Order Line" <> 0 then begin
            SupplyReservEntry.SetRange("Source Ref. No.", SupplyReservEntry."Source Prod. Order Line");
            SupplyReservEntry.SetRange("Source Prod. Order Line");
            SupplyReservEntry.SetBaseLoadFields();
            if SupplyReservEntry.FindSet(true) then
                repeat
                    SupplyEntry := SupplyReservEntry;
                    if OriginEntry.Get(SupplyReservEntry."Transferred from Entry No.", SupplyReservEntry.Positive) then begin
                        SupplyEntry."Expected Receipt Date" := OriginEntry."Expected Receipt Date";
                        SupplyEntry.Modify();
                    end;
                    MatchDemand(SupplyEntry, MainLocation);
                    SkipDefaultAutoMatch := true
                until SupplyReservEntry.Next() = 0;
        end;
        TrimReservMgt.DefragPositiveSurplus(SupplyReservEntry."Item No.", SupplyReservEntry."Variant Code");
    end;

    local procedure MatchDemand(SupplyReservEntry: Record "Reservation Entry"; MainLocation: Code[10]) QtyToTrack: Decimal
    var
        DemandEntry: Record "Reservation Entry";
    begin
        QtyToTrack := SupplyReservEntry."Quantity (Base)";
        DemandEntry.SetRange(Positive, false);
        DemandEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        DemandEntry.SetRange("Location Code", MainLocation);
        DemandEntry.SetRange("Item No.", SupplyReservEntry."Item No.");
        DemandEntry.SetRange("Variant Code", SupplyReservEntry."Variant Code");
        DemandEntry.SetFilter("Shipment Date", '%1..', SupplyReservEntry."Expected Receipt Date");
        DemandEntry.SetBaseLoadFields();
        if DemandEntry.FindSet() then
            repeat
                case true of
                    Abs(DemandEntry."Quantity (Base)") = QtyToTrack:
                        QtyToTrack := FullyMatch(SupplyReservEntry, DemandEntry);
                    Abs(DemandEntry."Quantity (Base)") < QtyToTrack:
                        QtyToTrack := MatchDemandSurplus(SupplyReservEntry, DemandEntry, QtyToTrack);
                    Abs(DemandEntry."Quantity (Base)") > QtyToTrack:
                        QtyToTrack := MatchOverDemandSurplus(SupplyReservEntry, DemandEntry, QtyToTrack);
                end;
            until (DemandEntry.Next() = 0) or (QtyToTrack = 0);
    end;

    local procedure MatchDemandSurplus(var SupplyReservEntry: Record "Reservation Entry"; DemandEntry: Record "Reservation Entry"; QtyToTrack: Decimal) RestQty: Decimal
    var
        NewReservEntry: Record "Reservation Entry";
    begin
        DemandEntry."Reservation Status" := "Reservation Status"::Tracking;
        DemandEntry."Expected Receipt Date" := SupplyReservEntry."Expected Receipt Date";
        DemandEntry.Modify();
        //create new supply entry with same entry no. and qty as demand
        NewReservEntry := SupplyReservEntry;
        NewReservEntry."Entry No." := DemandEntry."Entry No.";
        NewReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        NewReservEntry.Validate("Quantity (Base)", Abs(DemandEntry."Quantity (Base)"));
        NewReservEntry."Shipment Date" := DemandEntry."Shipment Date";
        NewReservEntry."Creation Date" := Today;
        NewReservEntry.Insert();
        //Reduce orignal supply qty
        RestQty := QtyToTrack - Abs(DemandEntry."Quantity (Base)");
        SupplyReservEntry.Validate("Quantity (Base)", RestQty);
        SupplyReservEntry.Modify();
    end;

    local procedure MatchOverDemandSurplus(var SupplyReservEntry: Record "Reservation Entry"; DemandEntry: Record "Reservation Entry"; QtyToTrack: Decimal) RestQty: Decimal
    var
        NewDemandEntry: Record "Reservation Entry";
        NewSurpluEntry: Record "Reservation Entry";
        RestDemandSurplusQty: Decimal;
    begin
        RestDemandSurplusQty := Abs(DemandEntry."Quantity (Base)") - SupplyReservEntry."Quantity (Base)";

        SupplyReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        SupplyReservEntry."Shipment Date" := DemandEntry."Shipment Date";
        SupplyReservEntry.Modify();

        NewDemandEntry := DemandEntry;
        NewDemandEntry."Entry No." := SupplyReservEntry."Entry No.";
        NewDemandEntry.Positive := false;
        NewDemandEntry."Reservation Status" := "Reservation Status"::Tracking;
        NewDemandEntry.Validate("Quantity (Base)", -1 * QtyToTrack);
        NewDemandEntry."Expected Receipt Date" := SupplyReservEntry."Expected Receipt Date";
        NewDemandEntry."Creation Date" := Today;
        NewDemandEntry.Insert();

        NewSurpluEntry.TransferFields(DemandEntry, false);
        NewSurpluEntry."Entry No." := 0;
        NewSurpluEntry.Positive := false;
        NewSurpluEntry."Reservation Status" := "Reservation Status"::Surplus;
        NewSurpluEntry.Validate("Quantity (Base)", -1 * RestDemandSurplusQty);
        NewSurpluEntry."Creation Date" := Today;
        NewSurpluEntry.Insert();

        DemandEntry.Delete();

        RestQty := 0;
    end;

    local procedure FullyMatch(SupplyReservEntry: Record "Reservation Entry"; DemandEntry: Record "Reservation Entry") RestQty: Decimal
    var
        MatchReservEntry: Record "Reservation Entry";
    begin
        SupplyReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        SupplyReservEntry."Shipment Date" := DemandEntry."Shipment Date";
        SupplyReservEntry.Modify();

        MatchReservEntry.TransferFields(DemandEntry);
        if DemandEntry."Entry No." <> 0 then
            DemandEntry.Delete();
        MatchReservEntry."Entry No." := SupplyReservEntry."Entry No.";
        MatchReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        MatchReservEntry."Expected Receipt Date" := SupplyReservEntry."Expected Receipt Date";
        MatchReservEntry."Creation Date" := Today;
        MatchReservEntry.Insert();
        RestQty := 0;
    end;

    local procedure Reprioritize(SupplyReservEntry: Record "Reservation Entry"; MainLocation: Code[10]; QtyToReprioritize: Decimal)
    var
        DemandEntry: Record "Reservation Entry";
        MatchedEntry: Record "Reservation Entry";
    begin
        DemandEntry.SetRange(Positive, false);
        DemandEntry.SetRange("Reservation Status", "Reservation Status"::Tracking);
        DemandEntry.SetRange("Location Code", MainLocation);
        DemandEntry.SetRange("Item No.", SupplyReservEntry."Item No.");
        DemandEntry.SetRange("Variant Code", SupplyReservEntry."Variant Code");
        DemandEntry.SetFilter("Shipment Date", '%1..', SupplyReservEntry."Expected Receipt Date");
        DemandEntry.SetBaseLoadFields();
        if DemandEntry.FindSet() then
            repeat
                MatchedEntry.SetRange("Entry No.", DemandEntry."Entry No.");
                MatchedEntry.SetRange(Positive, true);
                MatchedEntry.SetRange("Source Type", Database::"Item Ledger Entry");
                if MatchedEntry.FindFirst() then begin
                    case true of
                        QtyToReprioritize = MatchedEntry."Quantity (Base)":
                            QtyToReprioritize := FullyReprioritizeMatch(DemandEntry, SupplyReservEntry, MatchedEntry);
                        QtyToReprioritize > MatchedEntry."Quantity (Base)":
                            QtyToReprioritize := ReprioritizeOverSupplySurplus(DemandEntry, SupplyReservEntry, MatchedEntry, QtyToReprioritize);
                        QtyToReprioritize < MatchedEntry."Quantity (Base)":
                            QtyToReprioritize := ReprioritizeUnderSupplySurplus(DemandEntry, SupplyReservEntry, MatchedEntry, QtyToReprioritize);
                    end;
                end;
            until (DemandEntry.Next() = 0) or (QtyToReprioritize = 0);
    end;

    local procedure FullyReprioritizeMatch(DemandEntry: Record "Reservation Entry";
SupplyEntry: Record "Reservation Entry";
ReprioritizeEntry: Record "Reservation Entry") RestQty: Decimal
    var
        NewReservEntry: Record "Reservation Entry";
    begin
        SupplyEntry."Reservation Status" := "Reservation Status"::Tracking;
        SupplyEntry."Shipment Date" := DemandEntry."Shipment Date";
        SupplyEntry.Modify();

        NewReservEntry := DemandEntry;
        if DemandEntry."Entry No." <> 0 then
            DemandEntry.Delete();
        NewReservEntry."Entry No." := SupplyEntry."Entry No.";
        NewReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        NewReservEntry."Expected Receipt Date" := SupplyEntry."Expected Receipt Date";
        NewReservEntry."Creation Date" := Today;
        NewReservEntry.Insert();

        ReprioritizeEntry."Reservation Status" := "Reservation Status"::Surplus;
        ReprioritizeEntry."Shipment Date" := 0D;
        ReprioritizeEntry.Modify();
        RestQty := 0;
    end;

    local procedure ReprioritizeOverSupplySurplus(DemandEntry: Record "Reservation Entry"; var SupplyReservEntry: Record "Reservation Entry"; ReprioritizeEntry: Record "Reservation Entry"; QtyToReprioritize: Decimal) RestSupplySurplusQty: Decimal
    var
        NewDemandEntry: Record "Reservation Entry";
        NewSurpluEntry: Record "Reservation Entry";
    begin
        RestSupplySurplusQty := QtyToReprioritize - ReprioritizeEntry."Quantity (Base)";
        NewSurpluEntry.TransferFields(SupplyReservEntry, false);
        NewSurpluEntry."Entry No." := 0;
        NewSurpluEntry.Positive := true;
        NewSurpluEntry."Reservation Status" := "Reservation Status"::Surplus;
        NewSurpluEntry.Validate("Quantity (Base)", RestSupplySurplusQty);
        NewSurpluEntry."Creation Date" := Today;
        NewSurpluEntry.Insert();

        SupplyReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        SupplyReservEntry."Shipment Date" := DemandEntry."Shipment Date";
        SupplyReservEntry.Validate("Quantity (Base)", ReprioritizeEntry."Quantity (Base)");
        SupplyReservEntry.Modify();

        NewDemandEntry := DemandEntry;
        NewDemandEntry."Entry No." := SupplyReservEntry."Entry No.";
        NewDemandEntry.Positive := false;
        NewDemandEntry."Reservation Status" := "Reservation Status"::Tracking;
        NewDemandEntry."Expected Receipt Date" := SupplyReservEntry."Expected Receipt Date";
        NewDemandEntry."Creation Date" := Today;
        NewDemandEntry.Insert();
        DemandEntry.Delete();

        ReprioritizeEntry."Reservation Status" := "Reservation Status"::Surplus;
        ReprioritizeEntry."Shipment Date" := 0D;
        ReprioritizeEntry.Modify();
    end;

    local procedure ReprioritizeUnderSupplySurplus(DemandEntry: Record "Reservation Entry"; var SupplyReservEntry: Record "Reservation Entry"; ReprioritizeEntry: Record "Reservation Entry"; QtyToReprioritize: Decimal) RestSupplySurplusQty: Decimal
    var
        NewDemandEntry: Record "Reservation Entry";
    begin
        RestSupplySurplusQty := ReprioritizeEntry."Quantity (Base)" - QtyToReprioritize;

        if SupplyReservEntry."Quantity (Base)" <> QtyToReprioritize then
            Error('SupplyReservEntry og QtyToReprioritize er ikke like');
        SupplyReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        SupplyReservEntry."Shipment Date" := DemandEntry."Shipment Date";
        SupplyReservEntry.Modify();

        NewDemandEntry := DemandEntry;
        NewDemandEntry."Entry No." := SupplyReservEntry."Entry No.";
        NewDemandEntry.Positive := false;
        NewDemandEntry."Reservation Status" := "Reservation Status"::Tracking;
        NewDemandEntry.Validate("Quantity (Base)", -1 * SupplyReservEntry."Qty. to Handle (Base)");
        NewDemandEntry."Expected Receipt Date" := SupplyReservEntry."Expected Receipt Date";
        NewDemandEntry."Creation Date" := Today;
        NewDemandEntry.Insert();

        DemandEntry.Validate("Quantity (Base)", -1 * RestSupplySurplusQty);
        DemandEntry.Modify();

        ReprioritizeEntry.Validate("Quantity (Base)", RestSupplySurplusQty);
        ReprioritizeEntry.Modify();
        RestSupplySurplusQty := 0;
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
        MainLocation: Code[10];
}