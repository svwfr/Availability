namespace Bragda.Availability;

using Microsoft.Sales.Document;

pageextension 50601 "AVLB Sales Order Subform" extends "Sales Order Subform"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        // Add changes to page actions here
    }

    trigger OnAfterGetCurrRecord()
    var
        AvailableSkuFB: Page "AVLB Available Sku FB";
    begin
        AvailableSkuFB.CalculateQty(Rec);
    end;
}