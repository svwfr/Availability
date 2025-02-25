namespace Byx.Availability;
using Microsoft.Sales.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Item;

page 50602 "AVLB Available Sku FB"

{
    PageType = ListPart;
    ApplicationArea = All;
    UsageCategory = Lists;
    ModifyAllowed = false;
    InsertAllowed = false;
    Editable = false;
    SourceTable = "AVLB Availability Sku";
    // SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field(ItemNo; Rec.ItemNo)
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
        AvailQtyDict: Dictionary of [Code[10], decimal];
        VariantCode: Code[10];
        SkuQty: Decimal;
    begin
        if not Rec.IsEmpty then
            Rec.DeleteAll();
        if SalesLn.Type <> "Sales Line Type"::Item then
            exit;
        AvailQtyDict := AvailMgt.CalcStyleAvilibilityQty(SalesLn);
        foreach VariantCode in AvailQtyDict.Keys do begin
            Rec.ItemNo := SalesLn."No.";
            Rec.VariantCode := VariantCode;
            Rec.Quantity := AvailQtyDict.Get(VariantCode);
            Rec.Insert();
        end;
    end;

    var
        AvailMgt: Codeunit "AVLB Availability Mgt";
}