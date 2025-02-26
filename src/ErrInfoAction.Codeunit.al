namespace Bragda.Availability;

using System.Automation;
using System.Utilities;
using Microsoft.Purchases.Document;
using Microsoft.Intercompany.Setup;
using Microsoft.Sales.Document;
using System.Security.User;
using Microsoft.Foundation.Shipping;

codeunit 50604 "AVLB ErrorInfoAction"
{
    procedure Cancel(ErrInfo: ErrorInfo)
    var
        IfwLog: Record "IFW Log";
    begin
        if IfwLog.Get(ErrInfo.RecordId) then begin
            IfwLog."Process Status" := Enum::"IFW Process Status Type"::Success;
            IfwLog.Modify();
        end;
    end;

    procedure UpdateLines(ErrInfo: ErrorInfo)
    var
        IfwLog: Record "IFW Log";
        SalesHdr: Record "Sales Header";
        PurchHdr: Record "Purchase Header";
        JsonLine: JsonToken;
        JLines: JsonToken;
        Jvalue: JsonValue;
        OrderNo: Code[20];
        DocType: Text;
        LineNo: Integer;
        ShipDate: Date;
        Success: Boolean;
    begin
        Success := IfwLog.Get(ErrInfo.RecordId);
        JLines := GetJlinesToken(IfwLog, DocType, OrderNo);

        if CompleteShipping(DocType, OrderNo) then begin
            ShipDate := Today;
            foreach JsonLine in JLines.AsArray() do begin
                if not Success then
                    break;
                if JsonMgt.TryGetJsonValue(JsonLine, 'newShptDate', Jvalue) then begin
                    if ShipDate < Jvalue.AsDate() then
                        ShipDate := Jvalue.AsDate();
                end;
            end;
            UpdateHeader(OrderNo, ShipDate);
        end else begin
            foreach JsonLine in JLines.AsArray() do begin
                if not Success then
                    break;
                if JsonMgt.TryGetJsonValue(JsonLine, 'lineNo', Jvalue) then
                    LineNo := Jvalue.AsInteger();
                if JsonMgt.TryGetJsonValue(JsonLine, 'newShptDate', Jvalue) then
                    ShipDate := Jvalue.AsDate();
                UpdateLines(DocType, OrderNo, LineNo, ShipDate);
            end;
        end;

        if Success then begin
            IfwLog."Process Status" := Enum::"IFW Process Status Type"::Success;
            IfwLog.Modify();

            case DocType of
                SalesHdr.TableName:
                    if SalesHdr.Get("Sales Document Type"::Order, OrderNo) then
                        ReleaseOrSendApproval(SalesHdr);
                PurchHdr.TableName:
                    if PurchHdr.Get("Purchase Document Type"::Order, OrderNo) then
                        ReleaseOrSendApproval(PurchHdr);
                else
                    Message('Something wrong');
            end;
        end;
    end;

    procedure ForceRelease(ErrInfo: ErrorInfo)
    var
        IfwLog: Record "IFW Log";
        SalesHdr: Record "Sales Header";
        PurchHdr: Record "Purchase Header";
        UserSetup: Record "User Setup";
        ConfirmMgt: Codeunit "Confirm Management";
        JsonLine: JsonToken;
        JLines: JsonToken;
        OrderNo: Code[20];
        DocType: Text;
        ConfirmReleaseMsg: Label 'Unable to fulfill shipment date expectations, do you still want to force release and violate company policy?';
        WhoToBlameMsg: label 'The order was forced released by user: %1, for order: %4 %2, at: [%3]', Comment = '%1=user id, %2 = order no, %3=Forced Date, %4= DocType';
        NothingHappendMsg: label 'The Order is still Open, and you can change the lines to meet your company policy';
        NoOrderToReleaseMsg: Label 'Didn''t find any order to release';
        ForcedByMsg: Label 'Forced by %1', Locked = true;
        NotAllowedToForceMsg: Label 'You are not authorized to Force this order. Please consult with your supervisor.';
    begin
        UserSetup.SetRange(ForceAvail, true);
        if not UserSetup.IsEmpty then begin //if no one has been assigned, then everyone is allowed
            UserSetup.SetRange("User ID", UserId);
            if UserSetup.IsEmpty then begin
                Message(NotAllowedToForceMsg);
                exit;
            end;
        end;
        IfwLog.Get(ErrInfo.RecordId);
        JLines := GetJlinesToken(IfwLog, DocType, OrderNo);
        JLines.AsArray().Get(0, JsonLine);

        case DocType of
            SalesHdr.TableName:
                begin
                    if SalesHdr.Get("Sales Document Type"::Order, OrderNo) then
                        if ConfirmMgt.GetResponseOrDefault(ConfirmReleaseMsg, false) then begin
                            SingleInstanceMgt.SetSkipRunInvCheck(true);
                            RlseSalesDoc.ReleaseSalesHeader(SalesHdr, false);
                            ICReleaseFunction(DocType, OrderNo);
                            IfwLog."Process Status" := IfwLog."Process Status"::Warning;
                            IfwLog."Target Search Keys" := StrSubstNo(ForcedByMsg, UserId);
                            IfwLog.SetCustomData(StrSubstNo(WhoToBlameMsg, UserId, DocType, OrderNo, CurrentDateTime));
                        end else
                            Message(NothingHappendMsg)
                    else
                        message(NoOrderToReleaseMsg);
                end;
            PurchHdr.TableName:
                begin
                    if PurchHdr.Get("Purchase Document Type"::Order, OrderNo) then
                        if ConfirmMgt.GetResponseOrDefault(ConfirmReleaseMsg, false) then begin
                            SingleInstanceMgt.SetSkipRunInvCheck(true);
                            RlsePurchDoc.ReleasePurchaseHeader(PurchHdr, false);
                            ICReleaseFunction(DocType, OrderNo);
                            IfwLog."Process Status" := IfwLog."Process Status"::Warning;
                            IfwLog."Target Search Keys" := StrSubstNo(ForcedByMsg, UserId);
                            IfwLog.SetCustomData(StrSubstNo(WhoToBlameMsg, UserId, DocType, OrderNo, CurrentDateTime));
                        end else
                            Message(NothingHappendMsg)
                    else
                        message(NoOrderToReleaseMsg);
                end;
            else
                message(NoOrderToReleaseMsg);
        end;
        if IfwLog."Process Status" <> Enum::"IFW Process Status Type"::Warning then begin
            IfwLog."Process Status" := Enum::"IFW Process Status Type"::Success;
            IfwLog.Modify();
        end;
    end;

    local procedure GetJlinesToken(IfwLog: Record "IFW Log"; var DocType: Text; var OrderNo: Code[20]) JLines: JsonToken;
    var
        JobInvtChkRqstMgt: Codeunit "AVLB Job InvtChkRqst Mgt";
        UpdateLinesJson: JsonObject;
        Jtoken: JsonToken;
    begin
        UpdateLinesJson.ReadFrom(IfwLog.GetInData());
        if IfwLog."Parameter String" = JobInvtChkRqstMgt.GetLocalTxt() then begin
            UpdateLinesJson.SelectToken('lines[0].docType', Jtoken);
            DocType := Jtoken.AsValue().AsText();
            UpdateLinesJson.SelectToken('lines[0].docNo', Jtoken);
            OrderNo := CopyStr(Jtoken.AsValue().AsCode(), 1, 20);
            UpdateLinesJson.Get('lines', JLines)
        end else begin
            UpdateLinesJson.SelectToken('jsonRespons.lines[0].docType', Jtoken);
            DocType := Jtoken.AsValue().AsText();
            UpdateLinesJson.SelectToken('jsonRespons.lines[0].docNo', Jtoken);
            OrderNo := CopyStr(Jtoken.AsValue().AsCode(), 1, 20);
            UpdateLinesJson.Get('jsonRespons', Jtoken);
            Jtoken.AsObject().Get('lines', JLines);
        end;
    end;

    local procedure CompleteShipping(DocType: text; OrderNo: Code[20]): Boolean
    var
        SalesHdr: Record "Sales Header";
    begin
        if DocType <> SalesHdr.TableName then
            exit(false);
        if SalesHdr.Get("sales document type"::Order, OrderNo) then
            exit(SalesHdr."Shipping Advice" = "Sales Header Shipping Advice"::Complete);
    end;

    local procedure UpdateHeader(OrderNo: Code[20]; ShipDate: Date)
    var
        SalesHdr: Record "Sales Header";
    begin
        if SalesHdr.Get("sales document type"::Order, OrderNo) then begin
            SalesHdr."Shipment Date" := ShipDate;
            SalesHdr."Requested Delivery Date" := ShipDate; //mandatory for Abakion
            SalesHdr.UpdateSalesLinesByFieldNo(SalesHdr.FieldNo("Requested Delivery Date"), false);
        end;
    end;

    local procedure UpdateLines(DocType: text; OrderNo: Code[20]; LineNo: Integer; ShipDate: Date) Success: Boolean
    var
        SalesHdr: Record "Sales Header";
        PurchHdr: Record "Purchase Header";
        SalesLn: Record "Sales Line";
        PurchLn: Record "Purchase Line";
    begin
        case DocType of
            SalesHdr.TableName:
                if SalesLn.Get("Sales Document Type"::Order, OrderNo, LineNo) then begin
                    SalesLn."Requested Delivery Date" := ShipDate;
                    SalesLn.Validate("Shipment Date", ShipDate);
                    Success := SalesLn.Modify(true);
                end;
            PurchHdr.TableName:
                if PurchLn.Get("Purchase Document Type"::Order, OrderNo, LineNo) then begin
                    PurchLn.Validate("Order Date", ShipDate);
                    PurchLn."Requested Receipt Date" := PurchLn."Planned Receipt Date";
                    Success := PurchLn.Modify(true);
                end;
        end;
    end;

    local procedure ReleaseOrSendApproval(SalesHdr: Record "Sales Header")
    var
        ApprovalsMgmt: Codeunit "Approvals Mgmt.";
    begin
        if ApprovalsMgmt.IsSalesApprovalsWorkflowEnabled(SalesHdr) then
            ApprovalsMgmt.OnSendSalesDocForApproval(SalesHdr)
        else
            RlseSalesDoc.PerformManualRelease(SalesHdr); //This Event trigger Abakion IC sync
    end;

    local procedure ReleaseOrSendApproval(PurchHdr: Record "Purchase Header")
    var
        ApprovalsMgmt: Codeunit "Approvals Mgmt.";
    begin
        if ApprovalsMgmt.IsPurchaseApprovalsWorkflowEnabled(PurchHdr) then
            ApprovalsMgmt.OnSendPurchaseDocForApproval(PurchHdr)
        else
            RlsePurchDoc.PerformManualRelease(PurchHdr);
    end;

    local procedure ICReleaseFunction(DocType: text; OrderNo: Code[20])
    var
        SalesHdr: Record "Sales Header";
        PurchHdr: Record "Purchase Header";
        GlobalICSetup: Record "IC Setup";
        SCBICFunctions: Codeunit "SCB IC Functions";
    begin
        GlobalICSetup.SetFilter("IC Partner Code", '<>%1', '');
        if GlobalICSetup.IsEmpty then
            exit;
        GlobalICSetup.SetRange("SCB IC for Web Orders", false);

        SalesHdr."SCB Manual Order" := GlobalICSetup.IsEmpty; //set to true if "for web orders"
        case DocType of
            SalesHdr.TableName:
                if SalesHdr.Get(SalesHdr."Document Type"::Order, OrderNo) and (SalesHdr.Status = "Sales Document Status"::Released) then
                    SCBICFunctions.SalesRelease(SalesHdr);
            PurchHdr.TableName:
                if PurchHdr.Get(PurchHdr."Document Type"::"Order", OrderNo) and (PurchHdr.Status = "Purchase Document Status"::Released) then
                    SCBICFunctions.PurchRelease(PurchHdr);
        end;
    end;

    var
        JsonMgt: Codeunit "AVLB Json Management";
        RlseSalesDoc: Codeunit "Release Sales Document";
        RlsePurchDoc: Codeunit "Release Purchase Document";
        SingleInstanceMgt: Codeunit "AVLB Single Instance Mgt";
}