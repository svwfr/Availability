namespace Byx.Availability;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Microsoft.Foundation.Company;
using Microsoft.Inventory.Ledger;

codeunit 50619 "AVLB Trim Reservation Mgt"
{
    procedure TrimAllItems()
    var
        Item: Record Item;
    begin
        Item.LoadFields("No.");
        if Item.FindSet() then
            repeat
                TrimItem(Item);
            until Item.Next() = 0;
    end;

    procedure TrimItem(Item: Record Item)
    begin
        if RemoveDemand(Item."No.") then begin
            DefragPositiveSurplus(Item."No.", '');
            ReAddDemand(Item."No.")
        end else
            DefragPositiveSurplus(Item."No.", '');
    end;

    procedure DefragPositiveSurplus(ItemNo: Code[20]; VariantCode: Code[20])
    var
        PosReservEntry: Record "Reservation Entry";
        SumReservEntry: Record "Reservation Entry";
        DelReservEntry: Record "Reservation Entry";
    begin
        SetMainLocation();
        PosReservEntry.SetRange(Positive, true);
        PosReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        PosReservEntry.SetRange("Item No.", ItemNo);
        PosReservEntry.SetRange("Variant Code", VariantCode);
        PosReservEntry.SetRange("Location Code", MainLocation);
        PosReservEntry.SetBaseLoadFields();
        if PosReservEntry.FindSet() then
            repeat
                SumReservEntry := PosReservEntry;
                SumReservEntry.SetPointerFilter();
                SumReservEntry.SetRange("Source Prod. Order Line"); //remove from filter
                SumReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
                if SumReservEntry.Count > 1 then begin
                    SumReservEntry.CalcSums("Quantity (Base)");
                    SumReservEntry.Validate("Quantity (Base)", SumReservEntry."Quantity (Base)");
                    SumReservEntry.Modify();
                    DelReservEntry.CopyFilters(SumReservEntry);
                    DelReservEntry.SetFilter("Entry No.", '<>%1', SumReservEntry."Entry No.");
                    DelReservEntry.DeleteAll();
                end;
            until PosReservEntry.Next() = 0;
    end;

    procedure RemoveDemand(ItemNo: Code[20]) HasTrimmed: Boolean
    var
        SalesLine: Record "Sales Line";
        xSalesLine: Record "Sales Line";
        SalesLineReserve: Codeunit "Sales Line-Reserve";
    begin
        SalesLine.SetRange("Document Type", "Sales Document Type"::Order);
        SalesLine.SetRange(Type, "Sales Line Type"::Item);
        SalesLine.SetRange("No.", ItemNo);
        SalesLine.SetFilter("Outstanding Qty. (Base)", '>0');
        SalesLine.SetBaseLoadFields();
        if SalesLine.FindSet() then
            repeat
                xSalesLine := SalesLine;
                xSalesLine."Quantity (Base)" := 0;
                xSalesLine."Outstanding Qty. (Base)" := 0;
                SalesLineReserve.VerifyQuantity(xSalesLine, SalesLine);
                HasTrimmed := true;
            until SalesLine.Next() = 0;
    end;

    procedure ReAddDemand(ItemNo: Code[20])
    var
        SalesLine: Record "Sales Line";
        xSalesLine: Record "Sales Line";
        SalesLineReserve: Codeunit "Sales Line-Reserve";
    begin
        SalesLine.SetRange("Document Type", "Sales Document Type"::Order);
        SalesLine.SetRange(Type, "Sales Line Type"::Item);
        SalesLine.SetRange("No.", ItemNo);
        SalesLine.SetFilter("Outstanding Qty. (Base)", '>0');
        SalesLine.SetBaseLoadFields();
        if SalesLine.FindSet() then
            repeat
                xSalesLine := SalesLine;
                xSalesLine."Quantity (Base)" := 0;
                xSalesLine."Outstanding Qty. (Base)" := 0;
                SalesLineReserve.VerifyQuantity(SalesLine, xSalesLine);
            until SalesLine.Next() = 0;
    end;

    procedure TrackPairAudit() MissPairFilter: Text
    var
        CompInfo: Record "Company Information";
        ReservEntry: Record "Reservation Entry";
        ReservEntry2: Record "Reservation Entry";
    begin
        ReservEntry.SetFilter("Location Code", CompInfo."Location Code");
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Tracking);
        ReservEntry.SetLoadFields("Entry No.");
        ReservEntry2.CopyFilters(ReservEntry);
        if ReservEntry.FindSet() then
            repeat
                ReservEntry2.SetRange("Entry No.", ReservEntry."Entry No.");
                if ReservEntry2.Count < 2 then
                    if MissPairFilter = '' then
                        MissPairFilter := Format(ReservEntry."Entry No.")
                    else
                        MissPairFilter += '|' + Format(ReservEntry."Entry No.");
            until ReservEntry.Next() = 0;
    end;

    procedure DeleteEmptyILE() Items2RematchFilter: Text
    var
        CompInfo: Record "Company Information";
        ReservEntry: Record "Reservation Entry";
        ReservEntry2: Record "Reservation Entry";
    begin
        ReservEntry.SetFilter("Location Code", CompInfo."Location Code");
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Tracking);
        ReservEntry.SetRange("Source Type", Database::"Item Ledger Entry");
        ReservEntry.SetRange("Source Ref. No.", 0);
        ReservEntry.SetLoadFields("Item No.");
        if ReservEntry.FindSet() then
            repeat
                if Items2RematchFilter = '' then
                    Items2RematchFilter := ReservEntry."Item No."
                else
                    Items2RematchFilter += '|' + ReservEntry."Item No.";
                ReservEntry2.SetRange("Entry No.", ReservEntry."Entry No.");
                ReservEntry2.DeleteAll();
            until ReservEntry.Next() = 0;
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        if not ReservEntry.IsEmpty then
            ReservEntry.DeleteAll();
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
        MainLocation: Code[20];
}