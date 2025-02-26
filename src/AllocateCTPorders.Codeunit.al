namespace Bragda.Availability;
using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Microsoft.Foundation.Company;

codeunit 50624 "AVLB Allocate CTP Orders"
{
    trigger OnRun()
    begin
        FindOrdersToAllocate();
    end;

    local procedure FindOrdersToAllocate()
    var
        ReservEntry: Record "Reservation Entry";
        SalesLn: Record "Sales Line";
        DateForCTP: Date;
    begin
        SetMainLocation();
        DateForCTP := CalcDate(SetupMgt.GetSetupValueAsDateFormula(IfwIds::SetupCapableToPromiseFormula), Today);
        ReservEntry.SetCurrentKey("Source ID", "Source Ref. No.", "Source Type", "Source Subtype", "Source Batch Name", "Source Prod. Order Line", "Reservation Status", "Shipment Date", "Expected Receipt Date");
        ReservEntry.SetRange(Positive, false);
        ReservEntry.SetRange("Source Type", Database::"Sales Line");
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        ReservEntry.SetFilter("Shipment Date", '..%1', DateForCTP);
        ReservEntry.SetRange("Location Code", MainLocation);
        ReservEntry.SetBaseLoadFields();
        if ReservEntry.FindSet() then
            repeat
                if SalesLn.Get("Sales Document Type"::Order, ReservEntry."Source ID", ReservEntry."Source Ref. No.") then begin
                    AutoMatchSalesLn.SetTotalQty(SalesLn."Outstanding Qty. (Base)");
                    AutoMatchSalesLn.MatchSalesLine(ReservEntry);
                    TrimReservMgt.DefragPositiveSurplus(SalesLn."No.", SalesLn."Variant Code");
                end;
            until ReservEntry.Next() = 0;
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
        SetupMgt: Codeunit "AVLB Setup Mgt";
        IfwIds: Enum "AVLB Setup Constants";
        AutoMatchSalesLn: Codeunit "AVLB Auto Match Sales Line";
        TrimReservMgt: Codeunit "AVLB Trim Reservation Mgt";
        MainLocation: Code[10];
}