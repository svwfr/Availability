namespace Byx.Availability;
using System.Text;
using Microsoft.Intercompany.Setup;
using Microsoft.Sales.Document;
using Microsoft.Purchases.Document;
using Microsoft.Inventory.Tracking;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Transfer;

codeunit 50613 "AVLB Job InvtChkRsps Mgt" implements "IFW Job Handler"
{
    var
        CalcAtpSalesLine: Record "Sales Line";
        InvtCheckMgt: Codeunit "AVLB Inventory Check Mgt.";
        JsonMgt: Codeunit "AVLB Json Management";
        IfwToolsMgt: Codeunit "IFW Tools Mgt";
        SetupMgt: Codeunit "AVLB Setup Mgt";
        SingleInstanceMgt: Codeunit "AVLB Single Instance Mgt";
        ToolsMgt: Codeunit "AVLB IFW Tools Mgt";
        IfwConstants: Enum "AVLB Setup Constants";
        IfwJobIds: Enum "IFW Job Id";

    procedure PrepareJob(var IfwRec: Record "IFW Integration"; var IfwLog: Record "IFW Log"; var IfwJob: Record "IFW Job"): Boolean
    begin
        ToolsMgt.RunWithJobQueue(IfwLog);
        // if not ToolsMgt.RunWithJobQueue(IfwLog) then
        //     IfwLog.RunLogEntry(true);
        exit(true);
    end;

    procedure ProcessJob(var IfwRec: Record "IFW Integration"; var IfwLog: Record "IFW Log"; var IfwJob: Record "IFW Job"): Boolean
    var
        DummyOrderNo: Code[20];
        SentralWhse: Text[10];
        jsonRequest: Text;
        DocType: Text;
        UnableToFulfill: Boolean;
        WarningLbl: Label 'Warning', Locked = true;
        DeliveryDatesWarMsg: Label 'Could not fulfill shipment date for all or some sales lines';
        DeliveryDatesOkMsg: Label 'Sales lines shipment dates are within expected shipment dates';
    begin
        jsonRequest := IfwLog.GetInData();
        SentralWhse := CopyStr(SetupMgt.GetSetupValueAsText(IfwConstants::SetupInventoryChkLocation), 1, 10);
        DocType := GetDocType(jsonRequest);
        DummyOrderNo := BuildTempSaleslines(jsonRequest);
        UnableToFulfill := InvtCheckMgt.AlertLackOfInventory(DocType, DummyOrderNo, SentralWhse, IfwLog);
        CleanUpDummyRecords(DummyOrderNo);
        IfwLog."Process Status" := IfwLog."Process Status"::Success;
        if UnableToFulfill then begin
            IfwLog."Target Search Keys" := WarningLbl;
            IfwLog.SetUserMessage(DeliveryDatesWarMsg)
        end else
            IfwLog.SetUserMessage(DeliveryDatesOkMsg);
    end;

    procedure CreateLogEntry(jsonRequest: Text) JsonResponse: Text
    var
        IfwJob: Record "IFW Job";
        IfwLog: Record "IFW Log";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        CreatedNo: Integer;
        JobNotActiveErr: Label 'Job %1 not active', Locked = true;
        JobNotFoundErr: Label 'Job %1 not found', Locked = true;
        LogEntryFailedErr: Label 'Log Entry No. %1, failed in company %2 with error message:\\%3', Comment = '%1=LogNo,%2=CompName,%3=UserMsg';
    begin
        SingleInstanceMgt.SetSalesHeaderDocNo('');  // Reset global var, just in case it got stuck in ProcessJob
        if not IfwJob.Get(SetupMgt.GetIntegrationCode(), GetJobCode()) then
            exit(StrSubstNo(JobNotFoundErr, GetJobCode()));
        if not IfwJob.IsActive() then
            exit(StrSubstNo(JobNotActiveErr, GetJobCode()));

        jsonRequest := Base64.FromBase64(jsonRequest);

        IfwLog.CreateLogEntry(IfwJob, RecRef, CreatedNo, GetDocumentNo(jsonRequest), false);
        IfwLog.Get(CreatedNo);
        IfwLog."Source Search Keys" := GetICLogNo(jsonRequest);
        IfwLog.SetInData(jsonRequest);
        if IfwLog.RunLogEntry(true) then
            JsonResponse := FormatInventoryRespons(IfwLog)
        else begin
            IfwLog.Get(CreatedNo);
            JsonResponse := StrSubstNo(LogEntryFailedErr, IfwLog."Log No", CompanyName, IfwLog.GetUserMessage()).Replace('\', IfwToolsMgt.GetCRLF());
        end;
    end;

    local procedure BuildTempSaleslines(JsonRequest: Text) DummyOrderNo: Text[20]
    var
        CalcAtpSalesLine2: Record "Sales Line";
        SalesLineReserve: Codeunit "Sales Line-Reserve";
        Jobj: JsonObject;
        Jvalue: JsonValue;
        JToken: JsonToken;
        JsonLine: JsonToken;
        ICOrderNo: Code[20];
        VendorOrderNo: Code[20];
    begin
        VendorOrderNo := GetVendorNo(JsonRequest);
        ICOrderNo := GetDocumentNo(JsonRequest);
        Clear(DummyOrderNo);
        DummyOrderNo := CopyStr('DUMMY' + ICOrderNo, 1, 20);
        Jobj.ReadFrom(JsonRequest);
        Jobj.Get('lines', JToken);
        CalcAtpSalesLine2.SetRange("Document Type", "Sales Document Type"::Order);
        CalcAtpSalesLine2.SetRange("Document No.", DummyOrderNo);
        CalcAtpSalesLine2.DeleteAll(false);

        foreach JsonLine in JToken.AsArray() do begin
            CalcAtpSalesLine.Init();
            CalcAtpSalesLine."Document Type" := "Sales Document Type"::Order;
            CalcAtpSalesLine."Document No." := DummyOrderNo;
            CalcAtpSalesLine."Originally Ordered No." := ICOrderNo;
            CalcAtpSalesLine.Type := "Sales Line Type"::Item;
            if JsonMgt.TryGetJsonValue(JsonLine, 'lineNo', Jvalue) then
                CalcAtpSalesLine."Line No." := Jvalue.AsInteger();
            if JsonMgt.TryGetJsonValue(JsonLine, 'location', Jvalue) then
                CalcAtpSalesLine."Location Code" := CopyStr(Jvalue.AsCode(), 1, MaxStrLen(CalcAtpSalesLine."Location Code"));
            if JsonMgt.TryGetJsonValue(JsonLine, 'shipmentDate', Jvalue) then
                CalcAtpSalesLine.Validate("Shipment Date", Jvalue.AsDate());
            if JsonMgt.TryGetJsonValue(JsonLine, 'item', Jvalue) then
                CalcAtpSalesLine."No." := CopyStr(Jvalue.AsCode(), 1, MaxStrLen(CalcAtpSalesLine."No."));
            if JsonMgt.TryGetJsonValue(JsonLine, 'variant', Jvalue) then
                CalcAtpSalesLine."Variant Code" := CopyStr(Jvalue.AsCode(), 1, MaxStrLen(CalcAtpSalesLine."Variant Code"));
            if JsonMgt.TryGetJsonValue(JsonLine, 'outstandingQtyBase', Jvalue) then begin
                CalcAtpSalesLine."Quantity (Base)" := Jvalue.AsDecimal();
                CalcAtpSalesLine."Outstanding Qty. (Base)" := Jvalue.AsDecimal();
            end;
            if JsonMgt.TryGetJsonValue(JsonLine, 'reservedQtyBase', Jvalue) then
                CalcAtpSalesLine."Reserved Qty. (Base)" := Jvalue.AsDecimal();
            CalcAtpSalesLine.Insert(false);
            if NewLineToCheck(VendorOrderNo, CalcAtpSalesLine) then
                SalesLineReserve.VerifyQuantity(CalcAtpSalesLine, CalcAtpSalesLine2);
        end;
    end;

    local procedure NewLineToCheck(vendorOrderNo: Code[20]; var CalcAtpSalesLn: Record "Sales Line"): Boolean
    var
        SalesHdr: Record "Sales Header";
        SalesLn: Record "Sales Line";
        RestQty: Decimal;
    begin
        SalesHdr.SetRange("Document Type", "Sales Document Type"::Order);
        SalesHdr.SetRange("No.", vendorOrderNo);
        SalesHdr.SetRange("IC Direction", "IC Direction Type"::Incoming);
        if not SalesHdr.FindFirst() then
            exit(true);
        if not SalesLn.Get(SalesHdr."Document Type", SalesHdr."No.", CalcAtpSalesLn."Line No.") then
            exit(true);
        if SalesLn."Shipment Date" > CalcAtpSalesLn."Shipment Date" then
            if NotPossibleToMove(SalesLn, RestQty) then begin
                CalcAtpSalesLn."Outstanding Qty. (Base)" := RestQty;
                exit(true);
            end else
                exit(false);
        if SalesLn."Outstanding Qty. (Base)" >= CalcAtpSalesLn."Outstanding Qty. (Base)" then
            exit(false)
        else
            CalcAtpSalesLn."Outstanding Qty. (Base)" := CalcAtpSalesLn."Outstanding Qty. (Base)" - SalesLn."Outstanding Qty. (Base)";
        exit(true);
    end;

    local procedure NotPossibleToMove(SalesLn: Record "Sales Line"; var RestQty: Decimal): Boolean
    var
        ReservationEntryNeg: Record "Reservation Entry";
        ReservationEntryPos: Record "Reservation Entry";
    begin
        ReservationEntryNeg.SetRange("Source Type", Database::"Sales Line");
        ReservationEntryNeg.SetRange("Source id", SalesLn."Document No.");
        ReservationEntryNeg.SetRange("Source Ref. No.", SalesLn."Line No.");
        RestQty := SalesLn."Quantity (Base)";
        if ReservationEntryNeg.FindSet() then
            repeat
                if ReservationEntryPos.Get(ReservationEntryNeg."Entry No.", true) then
                    if ReservationEntryPos."Source Type" = Database::"Item Ledger Entry" then begin
                        if ReservationEntryPos."Quantity (Base)" = RestQty then
                            exit(false)
                        else
                            RestQty := RestQty - ReservationEntryPos."Quantity (Base)";
                    end;
                if ReservationEntryPos."Source Type" = Database::"Transfer Line" then begin
                    if ReservationEntryPos."Expected Receipt Date" >= SalesLn."Shipment Date" then
                        if ReservationEntryPos."Quantity (Base)" = RestQty then
                            exit(false)
                        else
                            RestQty := RestQty - ReservationEntryPos."Quantity (Base)";
                end;
                if ReservationEntryPos."Source Type" = Database::"Purchase Line" then begin
                    if ReservationEntryPos."Expected Receipt Date" >= SalesLn."Shipment Date" then
                        if ReservationEntryPos."Quantity (Base)" = RestQty then
                            exit(false)
                        else
                            RestQty := RestQty - ReservationEntryPos."Quantity (Base)";
                end;
            until (ReservationEntryNeg.Next() = 0) or (RestQty = 0);

        if RestQty = 0 then
            exit(false)
        else
            exit(true);
    end;

    local procedure FormatInventoryRespons(IfwLog: Record "IFW Log") ResponsBody: Text
    var
        Base64: Codeunit "Base64 Convert";
    begin
        ResponsBody := Base64.ToBase64(StrSubstNo('{"jsonRespons": %1}', IfwLog.GetOutData()));
    end;

    local procedure CleanUpDummyRecords(DummyOrderNo: Code[20])
    var
        SalesLineReserve: Codeunit "Sales Line-Reserve";
    begin
        CalcAtpSalesLine.SetRange("Document Type", "Sales Document Type"::Order);
        CalcAtpSalesLine.SetRange("Document No.", DummyOrderNo);
        if CalcAtpSalesLine.FindSet() then
            repeat
                SalesLineReserve.DeleteLine(CalcAtpSalesLine);
                CalcAtpSalesLine.Delete(false);
            until CalcAtpSalesLine.Next() = 0;
    end;

    local procedure GetDocType(JsonData: Text): Text
    var
        Jvalue: JsonValue;
    begin
        if JsonMgt.TryGetJsonValue(JsonData, 'docType', Jvalue) then
            exit(Jvalue.AsText());
    end;

    local procedure GetVendorNo(JsonData: Text): Code[20]
    var
        Jvalue: JsonValue;
    begin
        if JsonMgt.TryGetJsonValue(JsonData, 'vendorOrderNo', Jvalue) then
            exit(CopyStr(Jvalue.AsCode(), 1, 20));
    end;

    local procedure GetDocumentNo(JsonData: Text): Code[20]
    var
        Jvalue: JsonValue;
    begin
        if JsonMgt.TryGetJsonValue(JsonData, 'orderNo', Jvalue) then
            exit(CopyStr(Jvalue.AsCode(), 1, 20));
    end;

    local procedure GetICLogNo(JsonData: Text): Text[300]
    var
        Jvalue: JsonValue;
        LogLbl: Label 'Log No: %1', Locked = true;
    begin
        if JsonMgt.TryGetJsonValue(JsonData, 'logNo', Jvalue) then
            exit(StrSubstNo(LogLbl, Jvalue.AsInteger()));
    end;

    local procedure GetJobCode(): Text
    begin
        exit(SetupMgt.GetEnumName(IfwJobIds::"INVT.CHK.RSPS"));
    end;
}
