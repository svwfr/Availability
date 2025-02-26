namespace Bragda.Availability;

using Microsoft.Inventory.Tracking;

query 50600 "AVLB Calc SKU Qty. Query"
{
    QueryType = Normal;

    elements
    {
        dataitem(ResrvEntry; "Reservation Entry")
        {
            DataItemTableFilter = Positive = const(true), "Reservation Status" = const("Reservation Status"::Surplus);
            column(ItemNo; "Item No.")
            {
                Caption = 'Item No.';
            }
            column(Variant_Code; "Variant Code")
            {
                Caption = 'Item Variant';
            }
            column(QuantityBase; "Quantity (Base)")
            {
                Caption = 'Qty';
                Method = Sum;
            }
            filter(LocationFilter; "Location Code")
            {

            }
            filter(ItemFilter; "Item No.")
            {

            }
            filter(VariantFilter; "Variant Code")
            {

            }
            filter(ExpRcptDate; "Expected Receipt Date")
            {

            }
        }
    }
}