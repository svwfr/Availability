namespace Bragda.Availability;
using Microsoft.Sales.Document;
using Microsoft.Purchases.Document;
using Microsoft.Sales.History;
using Microsoft.Intercompany.Partner;
using Microsoft.Intercompany.Setup;

codeunit 50605 "AVLB IC Management"
{
    procedure IsICPartner(SalesShipmentHeader: Record "Sales Shipment Header"): Boolean
    var
        ICPartner: Record "IC Partner";
    begin
        ICPartner.SetRange("Customer No.", SalesShipmentHeader."Sell-to Customer No.");
        exit(not ICPartner.IsEmpty)
    end;

    procedure IsICPartner(SalesHeader: Record "Sales Header"): Boolean
    var
        ICPartner: Record "IC Partner";
    begin
        ICPartner.SetRange("Customer No.", SalesHeader."Sell-to Customer No.");
        exit(not ICPartner.IsEmpty)
    end;

    procedure IsICPartner(PurchHdr: Record "Purchase Header"): Boolean
    var
        ICPartner: Record "IC Partner";
    begin
        ICPartner.SetRange("Vendor No.", PurchHdr."Buy-from Vendor No.");
        exit(not ICPartner.IsEmpty)
    end;

    procedure IsSupplyCompany(): Boolean
    var
        ICSetup: Record "IC Setup";
    begin
        ICSetup.SetFilter("SCB IC Company Type", '>=1');
        exit(not ICSetup.IsEmpty);
    end;
}