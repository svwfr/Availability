namespace Byx.Availability;
codeunit 50607 "AVLB Setup Mgt"
{
    procedure CreateIntegrationJobs()
    begin
        CreateIntegrationJob(IfwJobIds::"INVT.CHK.RQST", Enum::"IFW Cue Type"::Export, Enum::"IFW Job Type"::API, true, false);
        CreateIntegrationJob(IfwJobIds::"INVT.CHK.RSPS", Enum::"IFW Cue Type"::Export, Enum::"IFW Job Type"::API, true, false);
    end;

    procedure CreateIntegrationJob(NewIfwJobIds: Enum "IFW Job Id"; CueType: Enum "IFW Cue Type"; JobType: Enum "IFW Job Type"; Active: Boolean; DeactivateRunAgain: Boolean)
    var
        IfwJob: Record "IFW Job";
    begin
        IfwJob.CreateJob(GetIntegrationCode(), GetEnumName(NewIfwJobIds), '', Format(NewIfwJobIds), NewIfwJobIds.AsInteger(), CueType, JobType, GetJobHandlerCodeunitId(), Active, DeactivateRunAgain);
    end;

    procedure GetEnumName(NewIfwJobIds: Enum "IFW Job Id"): Text
    begin
        exit(NewIfwJobIds.Names.Get(NewIfwJobIds.Ordinals.IndexOf(NewIfwJobIds.AsInteger())));
    end;

    procedure GetEnumCaptionAsInteger(NewIfwIds: Enum "AVLB Setup Constants") RetVal: Integer
    begin
        Evaluate(RetVal, Format(NewIfwIds));
    end;

    procedure GetEnumName(NewIfwIds: Enum "IFW Integration Id"): Text
    begin
        exit(NewIfwIds.Names.Get(NewIfwIds.Ordinals.IndexOf(NewIfwIds.AsInteger())));
    end;

    procedure GetIntegrationCode(): Text[50]
    begin
        exit(CopyStr(GetEnumName(IfwIds::AVAIL), 1, 50));
    end;

    procedure GetIntegrationName(): Text[2048]
    begin
        exit(Format(IfwIds::AVAIL));
    end;

    procedure GetJobHandlerCodeunitId(): Integer
    begin
        exit(Codeunit::"IFW Job Handler Mgt");
    end;

    procedure GetSetupPageId(): Integer
    begin
        exit(Page::"AVLB Availability Setup");
    end;

    procedure GetSetupValueAsBoolean(IfwId: Enum "AVLB Setup Constants"): Boolean
    begin
        exit(IfwSetupValue.GetBoolean(GetIntegrationCode(), Format(IfwId)));
    end;

    procedure GetSetupValueAsDateFormula(IfwId: Enum "AVLB Setup Constants"): DateFormula
    begin
        exit(IfwSetupValue.GetDateFormula(GetIntegrationCode(), Format(IfwId)));
    end;

    procedure GetSetupValueAsGuid(IfwId: Enum "AVLB Setup Constants"): Guid
    begin
        exit(IfwSetupValue.GetGuid(GetIntegrationCode(), Format(IfwId)));
    end;

    procedure GetSetupValueAsText(IfwId: Enum "AVLB Setup Constants"): Text
    begin
        exit(IfwSetupValue.GetText(GetIntegrationCode(), Format(IfwId)));
    end;

    procedure SetSetupGroup(KeyValue: Text; NewDescription: Text; GroupId: Integer)
    begin
        IfwSetupValue.SetGroup(GetIntegrationCode(), KeyValue, NewDescription, GroupId);
    end;

    procedure SetSetupValue(KeyValue: Text; NewDescription: Text; NewValue: Variant; GroupId: Integer)
    begin
        IfwSetupValue.SetValue(GetIntegrationCode(), KeyValue, NewDescription, NewValue, GroupId);
    end;

    procedure SetupValueExist(KeyValue: Text) Success: Boolean
    begin
        Success := IfwSetupValue.Get(GetIntegrationCode(), KeyValue);
    end;

    var
        IfwSetupValue: Record "IFW Setup Value";
        IfwIds: Enum "IFW Integration Id";
        IfwJobIds: Enum "IFW Job Id";
}
