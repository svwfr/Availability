namespace Byx.Availability;
using Microsoft.Inventory.Location;
using System.Environment.Configuration;
using Microsoft.Inventory.Item.Catalog;
using System.Environment;
using Microsoft.Foundation.Company;

page 50600 "AVLB Availability Setup"
{
    ApplicationArea = All;
    Caption = 'Availability Setup';
    DeleteAllowed = false;
    InsertAllowed = false;
    LinksAllowed = false;
    PageType = NavigatePage;
    ShowFilter = false;
    SourceTable = "IFW Setup";
    SourceTableTemporary = true;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(Step1)
            {
                ShowCaption = false;
                Visible = CurrentStep = 1;

                group(ChkInventoryGrp)
                {
                    Caption = 'Inventory Check';
                    group(InventoryChkGrp)
                    {
                        ShowCaption = false;
                        field(FldChkInventoryActive; FldInventoryChkActive)
                        {
                            Caption = 'Inventory Check Active';
                            ToolTip = 'If active, inventory will be checked for all lines when sales order is released';
                        }
                        field(FldChkInventoryLocation; FldInventoryChkLocation)
                        {
                            Caption = 'Location Code';
                            TableRelation = Location.Code;
                            ToolTip = 'Only sales orders with this location code will be checked';
                        }
                        field(FldInventoryChkAbakionUserID; FldInventoryChkAbakionUserID)
                        {
                            Caption = 'Abakion User ID';
                            ToolTip = 'Need to identify Abakion User ID in Microsoft Entra Setup. To exclude log entry calls from this user';
                            trigger OnLookup(var Text: Text): Boolean
                            var
                                AADApp: Record "AAD Application";
                            begin
                                if Page.RunModal(Page::"AAD Application List", AADApp) = Action::LookupOK then
                                    FldInventoryChkAbakionUserID := AADApp."User ID";
                            end;
                        }
                    }
                    group(CapableToPromiseFormulaGrp)
                    {
                        ShowCaption = false;
                        Visible = FldCentralWarehouse;
                        field(FldCapableToPromiseFormula; FldCapableToPromiseFormula)
                        {
                            Caption = 'Capable-to-Promise Formula';
                            ToolTip = 'Date formula to calculate the earliest date that the item can be available if it is to be produced, purchased, or transferred, assuming that the item is not in inventory and no orders are scheduled';
                        }
                    }
                    group(Oauth2Grp)
                    {
                        Caption = 'BC Authentication/API', Locked = true;
                        Visible = not FldCentralWarehouse;
                        field(FldClientId; FldAzureClientId)
                        {
                            Caption = 'Azure Client Id', Locked = true;
                            ToolTip = 'OAuth 2.0 Microsoft Azure Client Id', Locked = true;
                        }
                        field(FldClientSecret; FldAzureClientSecret)
                        {
                            Caption = 'Azure Client Secret', Locked = true;
                            ExtendedDatatype = Masked;
                            ToolTip = 'OAuth 2.0 Microsoft Azure Client Secret', Locked = true;
                        }
                        field(FldTenantGuid; FldBcTenantId)
                        {
                            Caption = 'BC Tenant Id', Locked = true;
                            ToolTip = 'Business Central tenant to connect to', Locked = true;
                        }
                        field(FldEnvironment; FldBcEnvironment)
                        {
                            Caption = 'BC Environment', Locked = true;
                            ToolTip = 'Business Central environment to connect to (Production/Sandbox)', Locked = true;
                        }
                        field(FldCompanyGuid; FldBcCompanyGuid)
                        {
                            Caption = 'BC Company GUID', Locked = true;
                            ToolTip = 'Business Central company GUID to connect to', Locked = true;
                            trigger OnLookup(var Text: Text): Boolean
                            begin
                                LookupCompanyGuid();
                            end;
                        }
                    }
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action(ModuleInfoAction)
            {
                Caption = 'Info', Locked = true;
                Image = Info;
                InFooterBar = true;

                trigger OnAction()
                var
                    ToolsMgt: Codeunit "AVLB Setup Tools Mgt";
                begin
                    Message(ToolsMgt.GetModuleInfo());
                end;
            }
            // action(BackAction)
            // {
            //     Caption = '&Back';
            //     Enabled = (CurrentStep > 1);
            //     Image = PreviousRecord;
            //     InFooterBar = true;

            //     trigger OnAction()
            //     begin
            //         CurrentStep := CurrentStep - 1;
            //         CurrPage.Update();
            //     end;
            // }
            // action(NextAction)
            // {
            //     Caption = '&Next';
            //     Enabled = (CurrentStep >= 1) and (CurrentStep < 4);
            //     Image = NextRecord;
            //     InFooterBar = true;

            //     trigger OnAction()
            //     begin
            //         CurrentStep := CurrentStep + 1;
            //         CurrPage.Update(true);
            //     end;
            // }
            action(FinishAction)
            {
                Caption = '&Finish';
                Enabled = CurrentStep = 1;
                Image = Approve;
                InFooterBar = true;

                trigger OnAction()
                begin
                    CompleteSetup();
                    CurrPage.Close();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        CurrentStep := 1;
        InitTemporarySetup();
        FldCentralWarehouse := IC_Mgt.IsSupplyCompany();
    end;

    procedure CompleteSetup()
    var
        IfwRec: Record "IFW Integration";
        IfwSetup: Record "IFW Setup";
        GuidedExp: Codeunit "Guided Experience";
        IsHandled: Boolean;
        SetupExists: Boolean;
        GroupId: Integer;
        CurrModuleInfo: ModuleInfo;
    begin
        OnBeforeCompleteAssistedSetup(IsHandled);
        if IsHandled then
            exit;

        NavApp.GetCurrentModuleInfo(CurrModuleInfo);
        IfwRec.InitIntegration(SetupMgt.GetIntegrationCode(), SetupMgt.GetIntegrationName(), true, CurrModuleInfo.Id(), SetupMgt.GetSetupPageId());

        SetupExists := IfwSetup.Get(Rec."Integration Code");
        IfwSetup.TransferFields(Rec);
        if SetupExists then
            IfwSetup.Modify(true)
        else
            IfwSetup.Insert(true);

        // Save setup values
        GroupId := 1;
        SetupMgt.SetSetupGroup(Format(GroupId), SetupMgt.GetIntegrationName() + ' Assisted Setup Values', GroupId);  // Optional, just to make tree view work in page 76260 "IFW Setup Values"
        SetupMgt.SetSetupValue(Format(IfwIds::SetupInventoryChkActive), '', FldInventoryChkActive, GroupId);
        SetupMgt.SetSetupValue(Format(IfwIds::SetupInventoryChkAbakionUserID), '', FldInventoryChkAbakionUserID, GroupId);
        SetupMgt.SetSetupValue(Format(IfwIds::SetupInventoryChkLocation), '', FldInventoryChkLocation, GroupId);
        SetupMgt.SetSetupValue(Format(IfwIds::SetupCapableToPromiseFormula), '', FldCapableToPromiseFormula, GroupId);
        SetupMgt.SetSetupValue(Format(IfwIds::SetupOauth2ClientId), '', FldAzureClientId, GroupId);
        SetupMgt.SetSetupValue(Format(IfwIds::SetupOauth2ClientSecret), '', FldAzureClientSecret, GroupId);
        SetupMgt.SetSetupValue(Format(IfwIds::SetupOauth2Environment), '', FldBcEnvironment, GroupId);
        SetupMgt.SetSetupValue(Format(IfwIds::SetupOauth2TenantId), '', FldBcTenantId, GroupId);
        SetupMgt.SetSetupValue(Format(IfwIds::SetupOauth2CompanyGuid), '', FldBcCompanyGuid, GroupId);
        // SetupMgt.SetSetupValue(Format(IfwIds::SetupAutoWarehouseLocation), '', FldAutoWarehouseLocation, GroupId);

        SetupMgt.CreateIntegrationJobs();

        if GuidedExp.Exists(Enum::"Guided Experience Type"::"Assisted Setup", ObjectType::Page, SetupMgt.GetSetupPageId()) then
            GuidedExp.CompleteAssistedSetup(ObjectType::Page, SetupMgt.GetSetupPageId());

        OnAfterCompleteAssistedSetup(IfwSetup);
    end;

    procedure GetJsonValueAsTxt(TokenPath: Text; JToken: JsonToken) JValue: Text
    begin
        Clear(JValue);
        JToken.SelectToken(TokenPath, JToken);
        if not JToken.AsValue().IsNull then
            exit(JToken.AsValue().AsText());
    end;

    procedure InitTemporarySetup()
    var
        IfwSetup: Record "IFW Setup";
        IsHandled: Boolean;
    begin
        OnBeforeInitAssistedSetup(IsHandled);
        if IsHandled then
            exit;

        if IfwSetup.Get(SetupMgt.GetIntegrationCode()) then begin
            Rec.TransferFields(IfwSetup);

            // Get saved setup values
            FldAzureClientId := SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2ClientId);
            FldAzureClientSecret := SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2ClientSecret);
            FldBcEnvironment := SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2Environment);
            FldBcTenantId := SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2TenantId);
            FldBcCompanyGuid := SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2CompanyGuid);
            FldInventoryChkActive := SetupMgt.GetSetupValueAsBoolean(IfwIds::SetupInventoryChkActive);
            FldInventoryChkAbakionUserID := SetupMgt.GetSetupValueAsGuid(IfwIds::SetupInventoryChkAbakionUserID);
            FldInventoryChkLocation := SetupMgt.GetSetupValueAsText(IfwIds::SetupInventoryChkLocation);
            FldCapableToPromiseFormula := SetupMgt.GetSetupValueAsDateFormula(IfwIds::SetupCapableToPromiseFormula);
        end else begin
            Rec.Init();
            Rec."Integration Code" := SetupMgt.GetIntegrationCode();
            // Set default setup values
            Evaluate(FldCapableToPromiseFormula, '60D');
        end;
        Rec.Insert();

        OnAfterInitAssistedSetup(IfwSetup, Rec);
    end;


    local procedure GetCnt(InternalType: Enum "IFW Internal Mapping Type"): Text
    var
        SetupMappings: Page "IFW Setup Mappings";
    begin
        exit(SetupMappings.GetCntAsText(SetupMgt.GetIntegrationCode(), InternalType));
    end;

    local procedure DrillDownMappings(InternalType: Enum "IFW Internal Mapping Type"; MappingComment: Text; ShowMappingId2: Boolean)
    var
        SetupMappings: Page "IFW Setup Mappings";
    begin
        SetupMappings.InitPage(SetupMgt.GetIntegrationCode(), InternalType, MappingComment, ShowMappingId2);
        SetupMappings.RunModal();
    end;

    local procedure LookupCompanyGuid()
    var
        Company: Record Company;
        Companies: Page Companies;
    begin
        Companies.LookupMode(true);
        Companies.SetRecord(Company);
        if Companies.RunModal() = Action::LookupOK then begin
            Companies.GetRecord(Company);
            FldBcCompanyGuid := DelChr(Company.SystemId, '<>', '{}');
        end;
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCompleteAssistedSetup(var SetupRec: Record "IFW Setup")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterInitAssistedSetup(var SetupRec: Record "IFW Setup"; var IfwSetupTemp: Record "IFW Setup")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCompleteAssistedSetup(var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeInitAssistedSetup(var IsHandled: Boolean)
    begin
    end;

    var
        SetupMgt: Codeunit "AVLB Setup Mgt";
        IC_Mgt: Codeunit "AVLB IC Management";
        FldCapableToPromiseFormula: DateFormula;
        FldAutoPostPrintActive: Boolean;
        FldAutoPostPrintAutoPost: Boolean;
        FldAutoPostPrintAutoPrint: Boolean;
        FldPostSOShipInvActive: Boolean;
        FldPostSOShipAutoPost: Boolean;
        FldPostSOInvAutoPost: Boolean;
        FldAssortmentCheckActive: Boolean;
        FldAutoPrintWarehousePick: Boolean;
        FldBlockReservedActive: Boolean;
        FldCentralWarehouse: Boolean;
        FldICDropShipmentActive: Boolean;
        FldInternalPricingActive: Boolean;
        FldInventoryChkActive: Boolean;
        FldLandedCostActive: Boolean;
        FldSalesMultipleActive: Boolean;
        FldSetDefaultQuantity: Boolean;
        FldDistrResrvAutoRelease: Boolean;
        FldLandedCostPalletCostLCY: Decimal;
        IfwIds: Enum "AVLB Setup Constants";
        CurrentStep: Integer;
        FldAutoPostPrintPrinterId: Text;
        FldAutoWarehouseLocation: Text;
        FldAzureClientId: Text;
        FldAzureClientSecret: Text;
        FldBcCompanyGuid: Text;
        FldBcEnvironment: Text;
        FldBcTenantId: Text;
        FldICDropShipmentInventory: Text;
        FldInventoryChkAbakionUserID: Guid;
        FldInventoryChkLocation: Text;
        FldLandedCostPalletUOM: Text;
        FldLandedCostShipmentMethod: Text;
        FldAutoPostPrintLocation: Text;
        FldAutoPostWhseMgrUserId: Guid;
        FldAutoPostWhseMgrPrinterId: Text;
        FldInternalPricingProdFamilyDim: Text;
        FldInventoryPickEmailAddr: Text;
        FldAutoPrintWarehousePickPrinterId: Text;
}
