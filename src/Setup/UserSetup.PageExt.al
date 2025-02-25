namespace Byx.Availability;

using System.Security.User;

pageextension 50602 "AVLB User Setup" extends "User Setup"
{
    layout
    {
        addlast(Control1)
        {
            field(ForceAvail; Rec.ForceAvail)
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
}