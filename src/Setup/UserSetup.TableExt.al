namespace Bragda.Availability;

using System.Security.User;

tableextension 50600 "AVLB User Setup" extends "User Setup"
{
    fields
    {
        field(50600; ForceAvail; Boolean)
        {
            Caption = 'Force Availability';
            DataClassification = CustomerContent;
            ToolTip = 'If only specific users should be able to Force an Inventory Check when placing an order, please select those users here.';
        }
    }

    keys
    {
        // Add changes to keys here
    }

    fieldgroups
    {
        // Add changes to field groups here
    }

    var
}