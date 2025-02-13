namespace Byx.Availability;

using System.Text;
using Microsoft.Intercompany.Setup;
using Microsoft.Sales.Document;
using Microsoft.Purchases.Document;
using Microsoft.Inventory.Item.Catalog;

codeunit 50612 "AVLB Job InvtChkRqst Mgt" implements "IFW Job Handler"
{
    var
        Base64: Codeunit "Base64 Convert";
        JsonMgt: Codeunit "AVLB Json Management";
        SetupMgt: Codeunit "AVLB Setup Mgt";
        WebServiceHttpMgt: Codeunit "AVLB WebServiceHttp Mgt";
        ToolsMgt: Codeunit "AVLB IFW Tools Mgt";
        IfwConstants: Enum "AVLB Setup Constants";
        IfwJobIds: Enum "IFW Job Id";
        UserMsg: Text;

    procedure PrepareJob(var IfwRec: Record "IFW Integration"; var IfwLog: Record "IFW Log"; var IfwJob: Record "IFW Job"): Boolean
    begin
        ToolsMgt.RunWithJobQueue(IfwLog);
        // if not ToolsMgt.RunWithJobQueue(IfwLog) then
        //     IfwLog.RunLogEntry(true);
        exit(true);
    end;

    procedure ProcessJob(var IfwRec: Record "IFW Integration"; var IfwLog: Record "IFW Log"; var IfwJob: Record "IFW Job"): Boolean
    var
        Jobj: JsonObject;
        Jvalue: JsonValue;
        DecodedRespons: Text;
        ResponsRaw: Text;
        RequestContent: Text;
        RequestUrl: Text;
        DeliveryDatesOkMsg: Label 'Sales lines delivery dates are within expected shipment dates';
        RequestContentLbl: Label 'Request Content: %1', Comment = '%1=RequestContent', Locked = true;
        RequestUrlLbl: Label 'Post Request: %1', Comment = '%1=Url', Locked = true;
        LogLbl: Label 'Log No: %1', Locked = true;
    begin
        if IfwLog."Parameter String" = GetLocalTxt() then
            LocalProcessJob(IfwLog)
        else begin
            RequestUrl := WebServiceHttpMgt.AddBcEnvironment2Url(Format(IfwConstants::SetupOauth2ChkInventoryUrl));
            RequestContent := FormatInventoryRequest(IfwLog);
            ResponsRaw := WebServiceHttpMgt.InvokePost(RequestUrl, RequestContent);
            Jobj.ReadFrom(ResponsRaw);
            JsonMgt.TryGetJsonValue(Jobj, 'value', Jvalue);
            if not TryDecoBase64(Jvalue.AsText(), DecodedRespons) then begin
                DecodedRespons := Jvalue.AsText();
                IfwLog."Process Status" := IfwLog."Process Status"::Error;
                IfwLog."Hide ShowMessage" := true;
                IfwLog.SetUserMessage(DecodedRespons);
                IfwLog.Modify();
                exit;
            end;
            IfwLog.SetInData(DecodedRespons);
            IfwLog."Target Search Keys" := StrSubstNo(LogLbl, GetICLogNo(DecodedRespons));
            IfwLog.SetLogMessage(StrSubstNo(RequestUrlLbl, RequestUrl));
            IfwLog.SetLogMessage(StrSubstNo(RequestContentLbl, RequestContent));
        end;
        UserMsg := GetJsonResponseMsg(IfwLog.GetInData());
        if UserMsg <> '' then begin
            IfwLog."Process Status" := IfwLog."Process Status"::Warning;
            IfwLog."Hide ShowMessage" := true;
            IfwLog.SetUserMessage(UserMsg);
        end else begin
            IfwLog."Process Status" := IfwLog."Process Status"::Success;
            IfwLog."Hide ShowMessage" := true;
            IfwLog.SetUserMessage(DeliveryDatesOkMsg);
        end;
    end;

    procedure CreateInvtCheckLogEntry(var SalesHeader: Record "Sales Header"; var IfwLog: Record "IFW Log") Success: Boolean
    var
        IfwJob: Record "IFW Job";
        ICSetup: Record "IC Setup";
        RecRef: RecordRef;
        CreatedNo: Integer;
    begin
        if not DoCreateLogEntry(SalesHeader, IfwJob) then
            exit(false);
        RecRef.GetTable(SalesHeader);
        RecRef.Reset();
        RecRef.SetRecFilter();
        if ICSetup.Get() and (ICSetup."SCB IC Company Type" = Enum::"SCB IC Company Type"::"Sales Company") then
            IfwLog.CreateLogEntry(IfwJob, RecRef, CreatedNo, GetICtxt(), false)
        else
            IfwLog.CreateLogEntry(IfwJob, RecRef, CreatedNo, GetLocalTxt(), false);

        IfwLog.Get(CreatedNo);
        IfwLog.SetOutData(CreateSalesLineRequest(SalesHeader, IfwLog."Log No"));
        exit(true);
    end;

    procedure CreateInvtCheckLogEntry(var PurchaseHdr: Record "Purchase Header"; var IfwLog: Record "IFW Log") Success: Boolean
    var
        IfwJob: Record "IFW Job";
        ICSetup: Record "IC Setup";
        RecRef: RecordRef;
        CreatedNo: Integer;
    begin
        if not DoCreateLogEntry(PurchaseHdr, IfwJob) then
            exit(false);
        RecRef.GetTable(PurchaseHdr);
        RecRef.Reset();
        RecRef.SetRecFilter();
        if ICSetup.Get() and (ICSetup."SCB IC Company Type" = Enum::"SCB IC Company Type"::"Sales Company") then
            IfwLog.CreateLogEntry(IfwJob, RecRef, CreatedNo, GetICtxt(), false)
        else
            IfwLog.CreateLogEntry(IfwJob, RecRef, CreatedNo, GetLocalTxt(), false);
        IfwLog.Get(CreatedNo);

        IfwLog.SetOutData(CreateSalesLineRequest(PurchaseHdr, IfwLog."Log No"));
        exit(true);
    end;

    procedure RunInvCheckLogEntry(IfwLog: Record "IFW Log") Success: Boolean
    begin
        if IsWebshopOrder(IfwLog) then
            exit(true);
        IfwLog.RunLogEntry(true);
        Success := IfwLog."Process Status" = IfwLog."Process Status"::Success;
        if IfwLog."Process Status" = IfwLog."Process Status"::Error then
            Error(IfwLog.GetUserMessage());
        if IfwLog."Process Status" <> IfwLog."Process Status"::Success then
            CustomerWarningAction(IfwLog)
    end;

    procedure GetLocalTxt(): Text[250]
    begin
        exit('Local Request');
    end;

    local procedure IsWebshopOrder(var IfwLog: Record "IFW Log") IsWebshopOrder: Boolean
    var
        SingleInstanceMgt: Codeunit "AVLB Single Instance Mgt";
        IsWebShopMsg: Label 'The Sales order is a web order, inventory check has been skipped';
    begin
        IsWebshopOrder := false;
        OnCheckIsWebshopOrder(IfwLog, IsWebshopOrder);
        if IsWebshopOrder then begin
            if not SingleInstanceMgt.GetSkipInvCheckForWebOrders() then
                exit(false);
            IfwLog."Process Status" := IfwLog."Process Status"::Success;
            IfwLog.SetUserMessage(IsWebShopMsg);
            IfwLog.EndProcess();
            SingleInstanceMgt.SetSkipInvCheckForWebOrders(false);
        end;
    end;

    local procedure GetICtxt(): Text[250]
    begin
        exit('IC Request');
    end;

    local procedure DoCreateLogEntry(var SalesHeader: Record "Sales Header"; var IfwJob: Record "IFW Job"): Boolean;
    var
        IfwLogSearch: Record "IFW Log";
        IfwToolsMgt: Codeunit "IFW Tools Mgt";
        SingleInstanceMgt: Codeunit "AVLB Single Instance Mgt";
        RecRef: RecordRef;
        CurrDT: DateTime;
        SysDT: DateTime;
    begin
        if SalesHeader.Status <> SalesHeader.Status::Open then
            exit(false);
        if SingleInstanceMgt.GetSkipRunInvCheck() then
            exit(false);
        if Format(UserSecurityId()) = Format(SetupMgt.GetSetupValueAsGuid(IfwConstants::SetupInventoryChkAbakionUserID)) then
            exit(false);
        SalesHeader.CalcFields("Completely Shipped");
        if SalesHeader."Completely Shipped" then
            exit(false);
        if not SetupMgt.GetSetupValueAsBoolean(IfwConstants::SetupInventoryChkActive) then
            exit(false);
        if SetupMgt.GetSetupValueAsText(IfwConstants::SetupInventoryChkLocation) <> SalesHeader."Location Code" then
            exit(false);
        if not IfwJob.Get(SetupMgt.GetIntegrationCode(), SetupMgt.GetEnumName(IfwJobIds::"INVT.CHK.RQST")) then
            exit(false);
        if not IfwJob.IsActive() then
            exit(false);
        RecRef.GetTable(SalesHeader);
        IfwLogSearch.LoadFields("Integration Code", "Job Code", "Source Search Keys", SystemCreatedAt);
        IfwLogSearch.SetCurrentKey("Source Search Keys");
        IfwLogSearch.SetRange("Integration Code", SetupMgt.GetIntegrationCode());
        IfwLogSearch.SetRange("Job Code", SetupMgt.GetEnumName(Enum::"IFW Job Id"::"INVT.CHK.RQST"));
        IfwLogSearch.SetRange("Source Search Keys", IfwToolsMgt.GetRecordKeyValues(RecRef));
        if not IfwLogSearch.FindLast() then
            exit(true);
        CurrDT := CurrentDateTime;
        SysDT := IfwLogSearch.SystemCreatedAt + 2000;  // Let 2 seconds pass before allowing a new request to be sent
        if CurrDT > SysDT then
            exit(true);
    end;

    local procedure DoCreateLogEntry(var PurchaseHdr: Record "Purchase Header"; var IfwJob: Record "IFW Job"): Boolean;
    var
        IfwLogSearch: Record "IFW Log";
        IfwToolsMgt: Codeunit "IFW Tools Mgt";
        SingleInstanceMgt: Codeunit "AVLB Single Instance Mgt";
        ICMgt: Codeunit "AVLB IC Management";
        RecRef: RecordRef;
        CurrDT: DateTime;
        SysDT: DateTime;
    begin
        if PurchaseHdr.Status <> PurchaseHdr.Status::Open then
            exit(false);
        if SingleInstanceMgt.GetSkipRunInvCheck() then
            exit(false);
        if Format(UserSecurityId()) = Format(SetupMgt.GetSetupValueAsGuid(IfwConstants::SetupInventoryChkAbakionUserID)) then
            exit(false);
        PurchaseHdr.CalcFields("Completely Received");
        if PurchaseHdr."Completely Received" then
            exit(false);
        if not SetupMgt.GetSetupValueAsBoolean(IfwConstants::SetupInventoryChkActive) then
            exit(false);
        if not ICMgt.IsICPartner(PurchaseHdr) then
            exit(false);
        if not IfwJob.Get(SetupMgt.GetIntegrationCode(), SetupMgt.GetEnumName(IfwJobIds::"INVT.CHK.RQST")) then
            exit(false);
        if not IfwJob.IsActive() then
            exit(false);
        RecRef.GetTable(PurchaseHdr);
        IfwLogSearch.LoadFields("Integration Code", "Job Code", "Source Search Keys", SystemCreatedAt);
        IfwLogSearch.SetCurrentKey("Source Search Keys");
        IfwLogSearch.SetRange("Integration Code", SetupMgt.GetIntegrationCode());
        IfwLogSearch.SetRange("Job Code", SetupMgt.GetEnumName(Enum::"IFW Job Id"::"INVT.CHK.RQST"));
        IfwLogSearch.SetRange("Source Search Keys", IfwToolsMgt.GetRecordKeyValues(RecRef));
        if not IfwLogSearch.FindLast() then
            exit(true);
        CurrDT := CurrentDateTime;
        SysDT := IfwLogSearch.SystemCreatedAt + 2000;  // Let 2 seconds pass before allowing a new request to be sent
        if CurrDT > SysDT then
            exit(true);
    end;

    local procedure CreateSalesLineRequest(SalesHdr: Record "Sales Header"; LogNo: Integer) JsonLinesRequestTxt: Text
    var
        SalesLn: Record "Sales Line";
        JsonLines: JsonArray;
        JsonLine: JsonObject;
        JsonLineRequest: JsonObject;
        DocType: Text;
        OrderNo: Text;
        VendorOrderNo: Text;
    begin
        DocType := SalesHdr.TableName;
        OrderNo := SalesHdr."No.";
        SalesLn.SetRange("Document Type", SalesHdr."Document Type");
        SalesLn.SetRange("Document No.", SalesHdr."No.");
        SalesLn.SetRange(Type, "Sales Line Type"::Item);
        SalesLn.SetRange("Special Order", false);
        SalesLn.LoadFields("Line No.", "No.", "Outstanding Qty. (Base)", "Reserved Qty. (Base)", "Shipment Date", "Location Code");
        if not SalesLn.FindSet() then
            exit;
        VendorOrderNo := SalesLn."SCB Vendor Order No."; //Wilfa Norway
        repeat
            if SalesLn.IsInventoriableItem() or SkipDueToDropShipment(SalesLn) then begin
                JsonLine.Add('lineNo', SalesLn."Line No.");
                JsonLine.Add('item', SalesLn."No.");
                JsonLine.Add('variant', SalesLn."Variant Code");
                JsonLine.Add('outstandingQtyBase', SalesLn."Outstanding Qty. (Base)");
                JsonLine.Add('reservedQtyBase', SalesLn."Reserved Qty. (Base)");
                JsonLine.Add('shipmentDate', SalesLn."Shipment Date");
                JsonLine.Add('location', SalesLn."Location Code");
                JsonLines.Add(JsonLine);
                Clear(JsonLine);
            end;
        until SalesLn.Next() = 0;
        JsonLineRequest.Add('logNo', LogNo);
        JsonLineRequest.Add('docType', DocType);
        JsonLineRequest.Add('orderNo', OrderNo);
        JsonLineRequest.Add('vendorOrderNo', VendorOrderNo);
        JsonLineRequest.Add('lines', JsonLines.AsToken());
        JsonLineRequest.WriteTo(JsonLinesRequestTxt)
    end;

    local procedure CreateSalesLineRequest(PurchaseHdr: Record "Purchase Header"; LogNo: Integer) JsonLinesRequestTxt: Text
    var
        PurchLn: Record "Purchase Line";
        JsonLines: JsonArray;
        JsonLine: JsonObject;
        JsonLineRequest: JsonObject;
        DocType: Text;
        OrderNo: Text;
        VendorOrderNo: Text;
        InvtChkLocation: Text;
    begin
        OrderNo := PurchaseHdr."No.";
        DocType := PurchaseHdr.TableName;
        VendorOrderNo := PurchaseHdr."Vendor Order No.";
        InvtChkLocation := SetupMgt.GetSetupValueAsText(IfwConstants::SetupInventoryChkLocation);
        PurchLn.SetRange("Document Type", PurchaseHdr."Document Type");
        PurchLn.SetRange("Document No.", PurchaseHdr."No.");
        PurchLn.SetRange(Type, "Sales Line Type"::Item);
        PurchLn.SetRange("Special Order", false);
        PurchLn.LoadFields("Line No.", "No.", "Outstanding Qty. (Base)", "Reserved Qty. (Base)", "Order Date", "Location Code");
        if not PurchLn.FindSet() then
            exit;
        repeat
            if PurchLn.IsInventoriableItem() then begin
                JsonLine.Add('lineNo', PurchLn."Line No.");
                JsonLine.Add('item', PurchLn."No.");
                JsonLine.Add('outstandingQtyBase', PurchLn."Outstanding Qty. (Base)");
                JsonLine.Add('reservedQtyBase', PurchLn."Reserved Qty. (Base)");
                JsonLine.Add('shipmentDate', PurchLn."Order Date");
                JsonLine.Add('location', InvtChkLocation);
                JsonLines.Add(JsonLine);
                Clear(JsonLine);
            end;
        until PurchLn.Next() = 0;
        JsonLineRequest.Add('logNo', LogNo);
        JsonLineRequest.Add('docType', DocType);
        JsonLineRequest.Add('orderNo', OrderNo);
        JsonLineRequest.Add('vendorOrderNo', VendorOrderNo);
        JsonLineRequest.Add('lines', JsonLines.AsToken());
        JsonLineRequest.WriteTo(JsonLinesRequestTxt)
    end;

    local procedure SkipDueToDropShipment(SalesLn: Record "Sales Line"): Boolean
    var
        PurchasingCode: Record Purchasing;
    begin
        if not SalesLn."Drop Shipment" then
            exit(false);
        PurchasingCode.SetRange(Code, SalesLn."Purchasing Code");
        PurchasingCode.SetRange("SCB Intercompany", true);
        if PurchasingCode.IsEmpty then
            exit(true);
    end;

    local procedure FormatInventoryRequest(var IfwLog: Record "IFW Log") RequestBody: Text
    begin
        RequestBody := StrSubstNo('{"jsonRequest": "%1"}', Base64.ToBase64(IfwLog.GetOutData()));
    end;

    local procedure LocalProcessJob(var IfwLog: Record "IFW Log")
    var
        SalesHdr: Record "Sales Header";
        InvtCheckMgt: Codeunit "AVLB Inventory Check Mgt.";
        DocType: Text;
        UnableToFulfill: Boolean;
        WarningLbl: Label 'Warning', Locked = true;
    begin
        SalesHdr.GetBySystemId(IfwLog."Source SystemId");
        DocType := SalesHdr.TableName;
        UnableToFulfill := InvtCheckMgt.AlertLackOfInventory(DocType, SalesHdr."No.", SalesHdr."Location Code", IfwLog);
        if UnableToFulfill then
            IfwLog."Target Search Keys" := WarningLbl;
    end;

    local procedure GetJsonResponseMsg(JsonData: Text): Text
    var
        ResponsToken: JsonToken;
        Jvalue: JsonValue;
    begin
        if GetJsonRespons(JsonData, ResponsToken) then
            if JsonMgt.TryGetJsonValue(ResponsToken, 'userMsg', Jvalue) then
                exit(Jvalue.AsText());
    end;

    local procedure GetICLogNo(JsonData: Text): Text[300]
    var
        ResponsToken: JsonToken;
        Jvalue: JsonValue;
    begin
        if GetJsonRespons(JsonData, ResponsToken) then
            if JsonMgt.TryGetJsonValue(ResponsToken, 'logNo', Jvalue) then
                exit(CopyStr(Jvalue.AsText(), 1, 300));
    end;

    local procedure GetJsonRespons(JsonData: Text; var ResponsToken: JsonToken): Boolean
    var
        Jobj: JsonObject;
    begin
        //if OK, then "empty" jsonobj. sent {"jsonRespons": }
        if StrLen(JsonData) > 25 then
            if Jobj.ReadFrom(JsonData) then
                if Jobj.Get('jsonRespons', ResponsToken) then
                    exit(true)
                else begin
                    ResponsToken := Jobj.AsToken();
                    exit(true);
                end;
        exit(false);
    end;

    local procedure CustomerWarningAction(IfwLog: Record "IFW Log")
    var
        InventoryCheckInfo: ErrorInfo;
        ReleaseWarningMsg: Label 'Warning: By release; you will "reserve" your item(s) to a date not available. Use with caution';
        ShipmentTooltipMsg: Label 'Updates all lines with suggested new shipment date, and release the order.';
        CancelTooltipMsg: Label 'Cancel the release, and no changes will occur.';
    begin
        InventoryCheckInfo.ErrorType(ErrorType::Client);
        InventoryCheckInfo.Verbosity(Verbosity::Warning);
        InventoryCheckInfo.Title('Inventory Check');
        InventoryCheckInfo.Message(IfwLog.GetUserMessage());
        InventoryCheckInfo.AddAction('Force Release', codeunit::"AVLB ErrorInfoAction", 'ForceRelease', ReleaseWarningMsg);
        InventoryCheckInfo.AddAction('Update', codeunit::"AVLB ErrorInfoAction", 'UpdateLines', ShipmentTooltipMsg);
        InventoryCheckInfo.AddAction('Cancel', codeunit::"AVLB ErrorInfoAction", 'Cancel', CancelTooltipMsg);
        InventoryCheckInfo.RecordId(IfwLog.RecordId);
        Error(InventoryCheckInfo)
    end;

    [TryFunction]
    local procedure TryDecoBase64(TextToDecode: Text; var DecodedText: Text)
    begin
        if TextToDecode = '' then
            Error('Respons is blank');
        DecodedText := Base64.FromBase64(TextToDecode);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCheckIsWebshopOrder(var IfwLog: Record "IFW Log"; var IsWebshopOrder: Boolean)
    begin
    end;
}
