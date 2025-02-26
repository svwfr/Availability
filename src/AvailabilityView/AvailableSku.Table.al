namespace Bragda.Availability;

table 50600 "AVLB Availability Sku"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; ItemNo; Code[20])
        {
            DataClassification = CustomerContent;

        }
        field(2; VariantCode; Code[10])
        {
            DataClassification = CustomerContent;

        }
        field(3; Quantity; Decimal)
        {
            DataClassification = CustomerContent;

        }
    }

    keys
    {
        key(Key1; ItemNo, VariantCode)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
        // Add changes to field groups here
    }

    trigger OnInsert()
    begin

    end;

    trigger OnModify()
    begin

    end;

    trigger OnDelete()
    begin

    end;

    trigger OnRename()
    begin

    end;

}