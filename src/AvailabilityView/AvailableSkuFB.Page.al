namespace Byx.Availability;
using Microsoft.Sales.Document;

page 50602 "AVLB Available Sku FB"

{
    PageType = ListPart;
    ApplicationArea = All;
    UsageCategory = Lists;
    ModifyAllowed = false;
    InsertAllowed = false;
    Editable = false;
    SourceTable = "AVLB Availability Sku";

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field(ItemNo;Rec.ItemNo)
                {
                    Caption = 'Item';
                    ToolTip = 'Specifies the value of the ItemNo field.', Locked = true;
                }
                field(VariantCode; Rec.VariantCode)
                {
                    Caption = 'Variant';
                    ToolTip = 'Specifies the value of the VariantCode field.', Locked = true;
                }
                field(Quantity; Rec.Quantity)
                {
                    Caption = 'Quantity';
                    ToolTip = 'Specifies the value of the Quantity field.', Locked = true;
                }
            }
        }
    }

    procedure CalculateQty(SalesLn: Record "Sales Line")
    var
        AVLBQuery: Query "AVLB Calc SKU Qty. Query";
    begin
        if not Rec.IsEmpty then
            Rec.DeleteAll();
        if SalesLn.Type <> "Sales Line Type"::Item then
            exit;
        AVLBQuery.SetFilter(ItemFilter, SalesLn."No.");
        AVLBQuery.SetFilter(LocationFilter, SalesLn."Location Code");
        AVLBQuery.SetFilter(ExpRcptDate,'..%1',SalesLn."Shipment Date");
        AVLBQuery.Open();
        while AVLBQuery.Read() do begin
            Rec.ItemNo := AVLBQuery.ItemNo;
            if AVLBQuery.Variant_Code = '' then
                Rec.VariantCode := 'N/A'
            else
                Rec.VariantCode := AVLBQuery.Variant_Code;
            Rec.Quantity := AVLBQuery.QuantityBase;
            Rec.Insert();
        end;
    end;
}