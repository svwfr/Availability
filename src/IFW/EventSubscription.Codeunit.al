namespace Bragda.Availability;

codeunit 50621 "AVLB IFW Event Subscriptions"
{
    [EventSubscriber(ObjectType::codeunit, codeunit::"IFW Job Handler Mgt", 'OnPrepareJob', '', false, false)]
    local procedure IfwJobHandlerMgt_OnPrepareJob(var IfwLog: Record "IFW Log"; var IfwJob: Record "IFW Job"; var IsHandled: Boolean)
    var
        NoManualRunErr: Label 'Job "%1" %2, can not be run manually, it is triggered automatically when sales order is released', Comment = '%1=JobCode,%2=JobDescr';
    begin
        if IfwJob."Integration Code" <> SetupMgt.GetIntegrationCode() then
            exit;
        if IfwJob.Code <> SetupMgt.GetEnumName(IfwJobIds::"INVT.CHK.RQST") then
            exit;
        Error(NoManualRunErr, IfwJob.Code, IfwJob.Description);
    end;

    [EventSubscriber(ObjectType::codeunit, codeunit::"IFW Job Handler Mgt", 'OnProcessJob', '', false, false)]
    local procedure IfwJobHandlerMgt_OnProcessJob(var IfwLog: Record "IFW Log"; var IfwJob: Record "IFW Job"; var IsHandled: Boolean)
    var
        DummyIfwIntgr: Record "IFW Integration";
        CurrLanguage: Integer;
    begin
        if IfwJob."Integration Code" <> SetupMgt.GetIntegrationCode() then
            exit;
        CurrLanguage := GlobalLanguage;
        GlobalLanguage(1033);
        if IfwJob.Code = SetupMgt.GetEnumName(IfwJobIds::"INVT.CHK.RQST") then begin
            InvtChkRqstMgt.ProcessJob(DummyIfwIntgr, IfwLog, IfwJob); //run request
            IsHandled := true;
        end;
        if IfwJob.Code = SetupMgt.GetEnumName(IfwJobIds::"INVT.CHK.RSPS") then begin
            InvtChkRspsMgt.ProcessJob(DummyIfwIntgr, IfwLog, IfwJob); //run response
            IsHandled := true;
        end;
        GlobalLanguage(CurrLanguage);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"IFW Tools Mgt", OnBeforeShowSourceTarget, '', false, false)]
    local procedure "IFW Tools Mgt_OnBeforeShowSourceTarget"(var IfwLog: Record "IFW Log"; SourceType: Option; var RecIDOrRecRefOrRecordVariant: Variant; var RecRef: RecordRef; var Handled: Boolean)
    begin
        if SourceType = 1 then // 1 = Target
            Handled := InvtChkMgt.OpenInventoryCheckList(RecRef, IfwLog)
    end;

    var
        InvtChkMgt: Codeunit "AVLB Inventory Check Mgt.";
        InvtChkRqstMgt: Codeunit "AVLB Job InvtChkRqst Mgt";
        InvtChkRspsMgt: Codeunit "AVLB Job InvtChkRsps Mgt";
        SetupMgt: Codeunit "AVLB Setup Mgt";
        IfwJobIds: Enum "IFW Job Id";
}