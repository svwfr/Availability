namespace Byx.Availability;

using System.DataAdministration;
using System.Environment;

codeunit 50620 "AVLB Sandbox Cleaner"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Environment Cleanup", 'OnClearCompanyConfig', '', true, true)]
    local procedure ClearCompanyConfig(CompanyName: Text; SourceEnv: Enum "Environment Type"; DestinationEnv: Enum "Environment Type")
    begin
        if DestinationEnv = DestinationEnv::Sandbox then begin
            PointAPI2Sandbox();
        end;
    end;

    local procedure PointAPI2Sandbox()
    var
        FldBcEnvironment: Text;
    begin
        FldBcEnvironment := EnvInformation.GetEnvironmentName();
        SetupMgt.SetSetupValue(Format(IfwIds::SetupOauth2Environment), '', FldBcEnvironment, 1);
    end;

    var
        EnvInformation: Codeunit "Environment Information";
        SetupMgt: Codeunit "AVLB Setup Mgt";
        IfwIds: Enum "AVLB Setup Constants";
}