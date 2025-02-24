namespace Byx.Availability;

using Microsoft.Sales.Document;

pageextension 50600 MyExtension extends "Sales Order"
{
    layout
    {
        // Add changes to page layout here
        addfirst(factboxes)
        {
            part(AvailableSku;"AVLB Available Sku FB")
            {
                ApplicationArea = All;
                Caption = 'Availability SKU';
                Editable = false;
                Provider = SalesLines;
                SubPageLink = ItemNo = field("No.");
            }
        }
    }
    
    actions
    {
        // Add changes to page actions here
    }
    
    var
}