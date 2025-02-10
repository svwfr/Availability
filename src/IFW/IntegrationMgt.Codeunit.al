namespace Byx.Availability;

codeunit 50606 "AVLB Integration Mgt" implements "IFW Integration Handler"
{
    procedure GetAssistedSetupPageId(): Integer
    begin
        exit(Page::"AVLB Availability Setup");
    end;

    procedure GetAssistedSetupDescription(var SetupDescription: Text)
    begin
    end;

    procedure GetAssistedSetupHelpUrl(var SetupHelpUrl: Text)
    begin
    end;

    procedure OnExistsAssistedSetup(IntegrationId: enum "IFW Integration Id"; SetupPageId: Integer)
    begin
    end;

    procedure OnAfterInsertAssistedSetup(IntegrationId: enum "IFW Integration Id"; SetupPageId: Integer)
    begin
    end;

    procedure OnMissingAssistedSetupPageId(IntegrationId: enum "IFW Integration Id")
    begin
    end;
}