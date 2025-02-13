namespace Byx.Availability;

using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Item;
using Microsoft.Foundation.Company;
using Microsoft.Inventory.Transfer;

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
            MoveTrackedDemand(ReservationEntry);
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reservation Engine Mgt.", OnBeforeCloseReservEntry, '', false, false)]
    local procedure OnBeforeCloseReservEntry(var ReservEntry: Record "Reservation Entry"; var ReTrack: Boolean; DeleteAll: Boolean; var SkipDeleteReservEntry: Boolean)
    begin
        if (ReservEntry."Source Type" = Database::"Transfer Line") and ReservEntry.Positive and
        (ReservEntry."Reservation Status" = "Reservation Status"::Tracking) then
            SkipDeleteReservEntry := true;
    end;

    local procedure SetTracked2Surplus(ReservEntry: Record "Reservation Entry"; NewDate: Date) StatusChanged: Boolean
    var
        DemandEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetPointerFilter();
        ReservEntry.ModifyAll("Expected Receipt Date", NewDate);
        ReservEntry.SetRange("Shipment Date", 0D, CalcDate('-1D', NewDate));
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Tracking);
        ReservEntry.SetBaseLoadFields();
        if ReservEntry.FindSet(true) then
            repeat
                ReservEntry."Reservation Status" := "Reservation Status"::Surplus;
                ReservEntry."Shipment Date" := 0D;
                ReservEntry.Modify();
                StatusChanged := true;

                if DemandEntry.Get(ReservEntry."Entry No.", false) then begin
                    DemandEntry."Reservation Status" := "Reservation Status"::Surplus;
                    DemandEntry."Expected Receipt Date" := 0D;
                    DemandEntry.Modify();
                end;
            until ReservEntry.Next() = 0;
    end;

    local procedure MoveTrackedDemand(ReservEntry: Record "Reservation Entry")
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
    end;

    local procedure AutoMatchTransfLine(ReservEntry: Record "Reservation Entry") SkipDefaultAutoMatch: Boolean
    var
        Item: Record Item;
        SupplyReservEntry: Record "Reservation Entry";
        TransLn: Record "Transfer Line";
        TrimReservMgt: Codeunit "AVLB Trim Reservation Mgt";
        QtyToCreate: Decimal;
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
                MatchDemand(SupplyReservEntry, MainLocation);
                SkipDefaultAutoMatch := true
            until SupplyReservEntry.Next() = 0
        else begin
            SupplyReservEntry.SetFilter("Source Prod. Order Line", SupplyReservEntry.GetFilter("Source Ref. No."));
            SupplyReservEntry.SetRange("Source Ref. No.");
            if SupplyReservEntry.FindSet() then begin
                repeat
                    MatchDemand(SupplyReservEntry, MainLocation);
                until SupplyReservEntry.Next() = 0;
                SkipDefaultAutoMatch := true;
                TrimReservMgt.DefragPositiveSurplus(SupplyReservEntry."Item No.", SupplyReservEntry."Variant Code");
            end;
        end;
    end;

    local procedure MatchDemand(SupplyReservEntry: Record "Reservation Entry"; Location: Code[10])
    var
        DemandEntry: Record "Reservation Entry";
        QtyToTrack: Decimal;
    begin
        QtyToTrack := SupplyReservEntry."Quantity (Base)";
        DemandEntry.SetRange(Positive, false);
        DemandEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        DemandEntry.SetRange("Location Code", Location);
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
        ReservEntry: Record "Reservation Entry";
        RestDemandSurplusQty: Decimal;
    begin
        RestDemandSurplusQty := DemandEntry."Quantity (Base)" - SupplyReservEntry."Quantity (Base)";

        SupplyReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        SupplyReservEntry."Shipment Date" := DemandEntry."Shipment Date";
        SupplyReservEntry.Modify();

        DemandEntry."Entry No." := SupplyReservEntry."Entry No.";
        DemandEntry."Reservation Status" := "Reservation Status"::Tracking;
        DemandEntry.Validate("Quantity (Base)", QtyToTrack);
        DemandEntry.Validate("Expected Receipt Date", SupplyReservEntry."Expected Receipt Date");
        DemandEntry.Modify();

        ReservEntry.TransferFields(DemandEntry, false);
        ReservEntry.Positive := false;
        ReservEntry."Reservation Status" := "Reservation Status"::Surplus;
        ReservEntry.Validate("Quantity (Base)", RestDemandSurplusQty);
        ReservEntry."Shipment Date" := SupplyReservEntry."Shipment Date";
        ReservEntry."Creation Date" := Today;
        ReservEntry.Insert();

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