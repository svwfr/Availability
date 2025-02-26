namespace Bragda.Availability;
codeunit 50618 "AVLB Transf-Reserv Report"
{
    trigger OnRun()
    begin
        TransfReservRecreate.SetReportOnly(true);
        TransfReservRecreate.Run();
    end;

    var
        TransfReservRecreate: Codeunit "AVLB Reserv Matching Recreate";
}