namespace Byx.Availability;

using Microsoft.Sales.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Item;

codeunit 50623 "AVLB Availability Mgt"
{

    procedure CalcSkuAviliblityQty(SalesLn: Record "Sales Line") AvailabilitySkuQty: Decimal
    var
        ReservEntry: Record "Reservation Entry";
    begin
        if SalesLn.Type <> "Sales Line Type"::Item then
            exit;
        ReservEntry.SetCurrentKey("Item No.", "Variant Code", "Location Code", "Reservation Status", "Shipment Date", "Expected Receipt Date", "Serial No.", "Lot No.", "Package No.");
        ReservEntry.SetRange(Positive, true);
        ReservEntry.SetRange("Item No.", SalesLn."No.");
        ReservEntry.SetRange("Variant Code", SalesLn."Variant Code");
        ReservEntry.SetRange("Location Code", SalesLn."Location Code");
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        ReservEntry.SetFilter("Expected Receipt Date", '..%1', SalesLn."Shipment Date");
        OnBeforeCalcSkuAviliblityQty(ReservEntry, SalesLn);
        ReservEntry.CalcSums("Quantity (Base)");
        AvailabilitySkuQty := ReservEntry."Quantity (Base)";
    end;

    procedure QryCalcSkuAviliblityQty(SalesLn: Record "Sales Line") AvailabilityQty: Decimal
    var
        AvilSkuQtyQuery: Query "AVLB Calc SKU Qty. Query";
    begin
        if SalesLn.Type <> "Sales Line Type"::Item then
            exit;
        AvilSkuQtyQuery.SetFilter(ItemFilter, SalesLn."No.");
        AvilSkuQtyQuery.SetFilter(VariantFilter, SalesLn."Variant Code");
        AvilSkuQtyQuery.SetFilter(LocationFilter, SalesLn."Location Code");
        AvilSkuQtyQuery.SetFilter(ExpRcptDate, '..%1', SalesLn."Shipment Date");
        OnBeforeCalculateAviliblitySkuQty(AvilSkuQtyQuery, SalesLn);
        AvilSkuQtyQuery.Open();
        while AvilSkuQtyQuery.Read() do begin
            AvailabilityQty := AvilSkuQtyQuery.QuantityBase;
        end;
    end;

    procedure CalcStyleAviliblityQty(SalesLn: Record "Sales Line") AvailQtyDict: Dictionary of [Code[10], decimal]
    var
        ItemVariant: Record "Item Variant";
        ReservEntry: Record "Reservation Entry";
    begin
        
        if SalesLn.Type <> "Sales Line Type"::Item then
            exit;
        ReservEntry.SetCurrentKey("Item No.", "Variant Code", "Location Code", "Reservation Status", "Shipment Date", "Expected Receipt Date", "Serial No.", "Lot No.", "Package No.");
        ReservEntry.SetRange(Positive, true);
        ReservEntry.SetRange("Item No.", SalesLn."No.");
        ReservEntry.SetRange("Location Code", SalesLn."Location Code");
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        ReservEntry.SetFilter("Expected Receipt Date", '..%1', SalesLn."Shipment Date");

        ItemVariant.SetRange("Item No.", SalesLn."No.");
        ItemVariant.SetBaseLoadFields();
        OnBeforeCalcStyleAviliblityQty(ItemVariant, ReservEntry, SalesLn);
        if ItemVariant.FindSet() then
            repeat
                ReservEntry.SetRange("Variant Code", ItemVariant.Code);
                ReservEntry.CalcSums("Quantity (Base)");
                AvailQtyDict.Add(ItemVariant.Code, ReservEntry."Quantity (Base)");
            until ItemVariant.Next() = 0;
    end;

    procedure QryCalcStyleAviliblityQty(SalesLn: Record "Sales Line") AvailQtyDict: Dictionary of [Code[10], decimal]
    var
        AvilStyleQtyQuery: Query "AVLB Calc SKU Qty. Query";
    begin
        if SalesLn.Type <> "Sales Line Type"::Item then
            exit;
        AvilStyleQtyQuery.SetFilter(ItemFilter, SalesLn."No.");
        AvilStyleQtyQuery.SetFilter(LocationFilter, SalesLn."Location Code");
        AvilStyleQtyQuery.SetFilter(ExpRcptDate, '..%1', SalesLn."Shipment Date");
        OnBeforeCalculateAviliblityStyleQty(AvilStyleQtyQuery, SalesLn);
        AvilStyleQtyQuery.Open();
        while AvilStyleQtyQuery.Read() do begin
            AvailQtyDict.Add(AvilStyleQtyQuery.Variant_Code, AvilStyleQtyQuery.QuantityBase);
        end;
    end;

    procedure GetUnmatchedQty(SalesLn: Record "Sales Line") SurplusQty: Decimal
    var
        ReservEntry: Record "Reservation Entry";
    begin
        ReservEntry.SetCurrentKey("Source Type", "Source Subtype", "Source ID", "Source Batch Name", "Source Prod. Order Line", "Source Ref. No.");
        ReservEntry.SetRange("Source Type", Database::"Sales Line");
        ReservEntry.SetRange("Source ID", SalesLn."Document No.");
        ReservEntry.SetRange("Source Ref. No.", SalesLn."Line No.");
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        ReservEntry.CalcSums("Quantity (Base)");
        SurplusQty := Abs(ReservEntry."Quantity (Base)");
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCalculateAviliblitySkuQty(var AvilSkuQtyQuery: Query "AVLB Calc SKU Qty. Query"; SalesLn: Record "Sales Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCalculateAviliblityStyleQty(var AvilStyleQtyQuery: Query "AVLB Calc SKU Qty. Query"; SalesLn: Record "Sales Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCalcSkuAviliblityQty(var ReservEntry: Record "Reservation Entry"; SalesLn: Record "Sales Line")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCalcStyleAviliblityQty(var ItemVariant: Record "Item Variant"; var ReservEntry: Record "Reservation Entry"; SalesLn: Record "Sales Line")
    begin
    end;

}