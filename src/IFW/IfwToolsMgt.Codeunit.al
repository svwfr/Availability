namespace Bragda.Availability;

codeunit 50608 "AVLB IFW Tools Mgt"
{
    procedure RunWithJobQueue(var IfwLog: Record "IFW Log") Success: Boolean
    var
        SecondsToStart: Integer;
    begin
        Success := TaskScheduler.CanCreateTask();
        if not Success then
            exit;
        Evaluate(SecondsToStart, Format(Enum::"AVLB Setup Constants"::"3"));
        IfwLog.RunWithJobQueue(SecondsToStart, Format(Enum::"AVLB Setup Constants"::IFW));
    end;
}