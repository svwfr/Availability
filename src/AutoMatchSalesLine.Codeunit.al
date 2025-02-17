namespace Byx.Availability;

using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
using Microsoft.Foundation.Company;
using Microsoft.Sales.Document;

codeunit 50602 "AVLB Auto Match Sales Line"
{
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Line-Reserve", OnBeforeVerifyQuantity, '', false, false)]
    local procedure "Sales Line-Reserve_OnBeforeVerifyQuantity"(var NewSalesLine: Record "Sales Line")
    begin
        TotalQty := NewSalesLine."Outstanding Qty. (Base)";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reservation Management", OnAutoTrackOnCheckSourceType, '', false, false)]
    local procedure AutoTrackOnCheckSourceType(var ReservationEntry: Record "Reservation Entry"; var ShouldExit: Boolean)
    begin
        if ShouldExit then
            exit;
        ShouldExit := MatchSalesLine(ReservationEntry);
    end;

    procedure MatchSalesLine(DemandReservEntry: Record "Reservation Entry") SkipDefaultAutoMatch: Boolean
    var
        Item: Record Item;
        QtyToTrack: Decimal;
    begin
        if DemandReservEntry."Source Type" <> Database::"Sales Line" then
            exit;
        if DemandReservEntry."Item No." = '' then
            exit;
        Item.Get(DemandReservEntry."Item No.");
        if Item."Order Tracking Policy" = Item."Order Tracking Policy"::None then
            exit;

        DemandReservEntry.Lock();
        QtyToTrack := Abs(TotalQty) - QuantityTracked(DemandReservEntry); //skal være 20 og ikkke 21 pga én går mot varepost

        if QtyToTrack = 0 then
            exit; //ms code update date will run

        MatchSupply(DemandReservEntry, QtyToTrack, SkipDefaultAutoMatch);
        Clear(TotalQty);
    end;

    procedure SetTotalQty(NewTotalQty:Decimal)
    begin
       TotalQty := NewTotalQty; 
    end;

    local procedure MatchSupply(DemandReservEntry: Record "Reservation Entry"; QtyToTrack: Decimal; var ExitDefaultAutoMatch: Boolean)
    var
        SupplyReservEntry: Record "Reservation Entry";
        AvailabilityDate: Date;
    begin
        QtyToTrack := Abs(QtyToTrack);
        AvailabilityDate := DemandReservEntry."Shipment Date";
        SupplyReservEntry.SetCurrentKey("Reservation Status", "Item No.", "Variant Code", "Location Code", "Expected Receipt Date");
        SupplyReservEntry.SetAscending("Expected Receipt Date", false);
        SupplyReservEntry.SetRange(Positive, true);
        SupplyReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        SupplyReservEntry.SetRange("Item No.", DemandReservEntry."Item No.");
        SupplyReservEntry.SetRange("Variant Code", DemandReservEntry."Variant Code");
        SupplyReservEntry.SetRange("Location Code", DemandReservEntry."Location Code");
        SupplyReservEntry.SetRange("Expected Receipt Date", 0D, AvailabilityDate);
        SupplyReservEntry.SetBaseLoadFields();
        if SupplyReservEntry.FindSet() then
            repeat
                case true of
                    SupplyReservEntry.Quantity = QtyToTrack:
                        QtyToTrack := FullyMatch(DemandReservEntry, SupplyReservEntry);
                    SupplyReservEntry."Quantity (Base)" < QtyToTrack:
                        QtyToTrack := MatchSurplus(DemandReservEntry, SupplyReservEntry, QtyToTrack);
                    SupplyReservEntry."Quantity (Base)" > QtyToTrack:
                        QtyToTrack := MatchOverSurplus(DemandReservEntry, SupplyReservEntry, QtyToTrack);
                end;
            until (SupplyReservEntry.Next() = 0) or (QtyToTrack = 0);

        if QtyToTrack > 0 then
            CreateDemandSurplus(DemandReservEntry, QtyToTrack);
        ExitDefaultAutoMatch := true;
    end;

    local procedure FullyMatch(DemandReservEntry: Record "Reservation Entry"; SupplyReservEntry: Record "Reservation Entry") RestQty: Decimal
    var
        MatchReservEntry: Record "Reservation Entry";
    begin
        SupplyReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        SupplyReservEntry."Shipment Date" := DemandReservEntry."Shipment Date";
        SupplyReservEntry.Modify();

        MatchReservEntry.TransferFields(DemandReservEntry);
        if DemandReservEntry."Entry No." <> 0 then
            DemandReservEntry.Delete();
        MatchReservEntry."Entry No." := SupplyReservEntry."Entry No.";
        MatchReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        MatchReservEntry.Validate("Quantity (Base)", (-1 * SupplyReservEntry."Quantity (Base)"));
        MatchReservEntry."Expected Receipt Date" := SupplyReservEntry."Expected Receipt Date";
        MatchReservEntry."Creation Date" := Today;
        MatchReservEntry.Insert();
        RestQty := 0;
    end;

    local procedure MatchSurplus(DemandReservEntry: Record "Reservation Entry"; SupplyReservEntry: Record "Reservation Entry"; QtyToTrack: Decimal) RestQty: Decimal
    var
        NewReservEntry: Record "Reservation Entry";
    begin
        SupplyReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        SupplyReservEntry."Shipment Date" := DemandReservEntry."Shipment Date";
        SupplyReservEntry.Modify();

        NewReservEntry := DemandReservEntry;
        NewReservEntry."Entry No." := SupplyReservEntry."Entry No.";
        NewReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        NewReservEntry.Validate("Quantity (Base)", (-1 * SupplyReservEntry."Quantity (Base)"));
        NewReservEntry."Expected Receipt Date" := SupplyReservEntry."Expected Receipt Date";
        NewReservEntry."Creation Date" := Today;
        NewReservEntry.Insert();
        RestQty := QtyToTrack - SupplyReservEntry."Quantity (Base)";

        if DemandReservEntry."Entry No." <> 0 then begin
            DemandReservEntry."Reservation Status" := "Reservation Status"::Surplus;
            DemandReservEntry.Validate("Quantity (Base)", -1 * RestQty);
            DemandReservEntry."Expected Receipt Date" := 0D;
            DemandReservEntry.Modify()
        end;
    end;

    local procedure MatchOverSurplus(DemandReservEntry: Record "Reservation Entry"; SupplyReservEntry: Record "Reservation Entry"; QtyToTrack: Decimal) RestQty: Decimal
    var
        ReservEntry: Record "Reservation Entry";
    begin
        SupplyReservEntry.Validate("Quantity (Base)", SupplyReservEntry."Quantity (Base)" - QtyToTrack);
        SupplyReservEntry.Modify();

        ReservEntry.TransferFields(SupplyReservEntry, false);
        ReservEntry.Positive := true;
        ReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        ReservEntry.Validate("Quantity (Base)", QtyToTrack);
        ReservEntry."Shipment Date" := DemandReservEntry."Shipment Date";
        ReservEntry."Creation Date" := Today;
        ReservEntry.Insert();

        DemandReservEntry."Entry No." := ReservEntry."Entry No.";
        DemandReservEntry."Reservation Status" := "Reservation Status"::Tracking;
        DemandReservEntry.Validate("Quantity (Base)", (-1 * QtyToTrack));
        DemandReservEntry."Expected Receipt Date" := ReservEntry."Expected Receipt Date";
        DemandReservEntry.Insert();
        RestQty := 0;
    end;

    local procedure CreateDemandSurplus(DemandReservEntry: Record "Reservation Entry"; SurplusDemandQty: Decimal)
    begin
        if DemandReservEntry."Entry No." <> 0 then
            exit;
        DemandReservEntry.Positive := false;
        DemandReservEntry."Reservation Status" := "Reservation Status"::Surplus;
        DemandReservEntry.Validate("Quantity (Base)", (-1 * SurplusDemandQty));
        DemandReservEntry."Creation Date" := Today;
        DemandReservEntry.Insert();
    end;

    local procedure QuantityTracked(var ReservEntry: Record "Reservation Entry") QtyTracked: Decimal
    var
        TrackedReservEntry: Record "Reservation Entry";
    begin
        TrackedReservEntry := ReservEntry;
        TrackedReservEntry."Quantity (Base)" := 0;
        TrackedReservEntry.SetPointerFilter();
        TrackedReservEntry.SetRange(Positive, false);
        TrackedReservEntry.SetRange("Reservation Status", "Reservation Status"::Tracking);
        if not TrackedReservEntry.IsEmpty then
            TrackedReservEntry.CalcSums("Quantity (Base)");
        QtyTracked := Abs(TrackedReservEntry."Quantity (Base)");
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
        TotalQty: Decimal;
        MainLocation: Code[10];
}