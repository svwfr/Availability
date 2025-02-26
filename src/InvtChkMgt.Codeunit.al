namespace Bragda.Availability;

using Microsoft.Inventory.Tracking;
using Microsoft.Sales.Document;
using Microsoft.Inventory.Availability;
using Microsoft.Inventory.Item;

codeunit 50610 "AVLB Inventory Check Mgt."
{
    procedure AlertLackOfInventory(DocType: Text; SalesOrderNo: Code[20]; Location: Code[10]; var IfwLog: Record "IFW Log") AlertUser: Boolean
    var
        ReservEntry: Record "Reservation Entry";
        Item: Record Item;
        StealEngineMgt: Codeunit "AVLB Steal Engine Mgt.";
        OutDataTxtBldr: TextBuilder;
        LogMessageTxtBldr: TextBuilder;
        ResponsArray: JsonArray;
        SurplusDate: Date;
        QtyNegSurplus: Decimal;
        HasUnableHeaderTxt: Boolean;
        DateForCTP: Date;
        SurplusDates: Dictionary of [Date, Decimal];
        ItemFilter: Text;
        UnableToFulfillErr: Label 'Unable to fulfill shipment date expectations:';
    begin
        AlertUser := false;
        DateForCTP := CalcDate(SetupMgt.GetSetupValueAsDateFormula(IfwIds::SetupCapableToPromiseFormula), Today);
        ReservEntry.SetCurrentKey("Source ID", "Source Ref. No.", "Source Type", "Source Subtype", "Source Batch Name", "Source Prod. Order Line", "Reservation Status", "Shipment Date", "Expected Receipt Date");
        ReservEntry.SetRange("Source ID", SalesOrderNo);
        ReservEntry.SetRange("Source Type", Database::"Sales Line");
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        ReservEntry.SetFilter("Shipment Date", '<%1', DateForCTP);
        ReservEntry.SetRange("Location Code", Location);

        if ReservEntry.IsEmpty then
            exit(false) //The order has been tracked or is beyond the CTP date.
        else
            if ReservEntry.FindSet() then
                repeat
                    if not HasUnableHeaderTxt then begin
                        OutDataTxtBldr.AppendLine(UnableToFulfillErr);
                        HasUnableHeaderTxt := true;
                    end;
                    QtyNegSurplus := ReservEntry."Quantity (Base)";
                    if not StealEngineMgt.AbelToStealStock(ReservEntry, DateForCTP) then begin
                        AlertUser := true;
                        FindNextPostSurplusDate(DateForCTP, Location, ReservEntry."Item No.", QtyNegSurplus, SurplusDates);
                        if SurplusDates.Count = 0 then
                            PrepareResponse(DocType, SalesOrderNo, ReservEntry."Source Ref. No.", DateForCTP, Abs(QtyNegSurplus), LogMessageTxtBldr, OutDataTxtBldr, ResponsArray, ItemFilter)
                        else
                            foreach SurplusDate in SurplusDates.Keys() do
                                PrepareResponse(DocType, SalesOrderNo, ReservEntry."Source Ref. No.", SurplusDate, SurplusDates.Get(SurplusDate), LogMessageTxtBldr, OutDataTxtBldr, ResponsArray, ItemFilter)
                    end;
                until ReservEntry.Next() = 0;
        if AlertUser then
            FinishResponse(LogMessageTxtBldr, OutDataTxtBldr, ResponsArray, ItemFilter, IfwLog);
        exit(AlertUser);
    end;

    procedure OpenInventoryCheckList(RecRef: RecordRef; IfwLog: Record "IFW Log") IsHandled: Boolean
    var
        IfwJob: Record "IFW Job";
        ResvrEntry: Record "Reservation Entry";
        IfwJobIds: Enum "IFW Job Id";
    begin
        if RecRef.Number() <> Database::"Reservation Entry" then
            exit;
        if not IfwJob.GetJob(IfwLog, IfwJob) then
            exit;
        if not IfwJob.IsActive() then
            exit;
        if (IfwJob.Code = SetupMgt.GetEnumName(IfwJobIds::"INVT.CHK.RQST")) or (IfwJob.Code = SetupMgt.GetEnumName(IfwJobIds::"INVT.CHK.RSPS")) then begin
            ResvrEntry.SetView(RecRef.GetView());
            Page.Run(Page::"AVLB Inventory Check List", ResvrEntry);
            IsHandled := true;
        end;
    end;

    local procedure FindNextPostSurplusDate(DateForCTP: Date; Location: Code[10]; ItemNo: Code[20]; var QtyNegSurplus: Decimal; var SurplusDates: Dictionary of [Date, Decimal])
    var
        ReservEntry: Record "Reservation Entry";
        RestDeliveryQty: Decimal;
        AddDeliveryQty: Decimal;
    begin
        Clear(SurplusDates);
        ReservEntry.SetCurrentKey("Reservation Status", "Item No.", "Variant Code", "Location Code", "Expected Receipt Date");
        ReservEntry.SetRange(Positive, true);
        ReservEntry.SetRange("Reservation Status", "Reservation Status"::Surplus);
        ReservEntry.SetRange("Item No.", ItemNo);
        ReservEntry.SetRange("Location Code", Location);
        ReservEntry.SetFilter("Expected Receipt Date", '>%1', 0D);
        if ReservEntry.FindSet() then
            repeat
                RestDeliveryQty := QtyNegSurplus;
                QtyNegSurplus += ReservEntry."Qty. to Handle (Base)";
                if QtyNegSurplus < 0 then
                    if SurplusDates.ContainsKey(ReservEntry."Expected Receipt Date") then begin
                        AddDeliveryQty := SurplusDates.Get(ReservEntry."Expected Receipt Date");
                        SurplusDates.Set(ReservEntry."Expected Receipt Date", ReservEntry."Quantity (Base)" + AddDeliveryQty);
                    end else
                        SurplusDates.Add(ReservEntry."Expected Receipt Date", ReservEntry."Qty. to Handle (Base)")
                else
                    if SurplusDates.ContainsKey(ReservEntry."Expected Receipt Date") then begin
                        AddDeliveryQty := SurplusDates.Get(ReservEntry."Expected Receipt Date");
                        SurplusDates.Set(ReservEntry."Expected Receipt Date", AddDeliveryQty + Abs(RestDeliveryQty));
                    end else
                        SurplusDates.Add(ReservEntry."Expected Receipt Date", Abs(RestDeliveryQty))
            until (ReservEntry.Next() = 0) or (QtyNegSurplus >= 0);
        if QtyNegSurplus < 0 then
            SurplusDates.Add(DateForCTP, Abs(QtyNegSurplus));

    end;

    local procedure PrepareResponse(DocType: Text; OrderNo: Code[20]; LineNo: Integer; SupplementDate: Date; QtyNeed: Decimal; var LogMessageTxtBldr: TextBuilder; var OutDataTxtBldr: TextBuilder; var ResponsArray: JsonArray; var ItemFilter: Text)
    var
        SalesLn: Record "Sales Line";
        TempOrderPromisingLine: Record "Order Promising Line" temporary;
        OrgOrderNo: Code[20];
        LogMessageLbl: Label 'Calculated: %1 is %2 for line %3, SKU: %4 #%5 (%6: %7)', Comment = '%1=FldCap,%2=EarliestDate,%3=LineNo,%4=ItemNo,%5= Variant, %6=FldCap, %7=ShptDate';
        NotAvailableErr: Label '%1 [%2] for line %3, SKU %4 #%5 is not possible. %6 is %7 for qty: %8', Comment = '%1=FldCap,%2=ShptDate,%3=LineNo,%4=ItemNo, %4=variant, %6=FldCap,%7=EarliestDate, %8=Qty';
    begin
        if SalesLn.Get("Sales Document Type"::Order, OrderNo, LineNo) then begin
            if ItemFilter = '' then
                ItemFilter := SalesLn."No."
            else
                ItemFilter += '|' + SalesLn."No.";
            if SalesLn."Originally Ordered No." <> '' then
                OrgOrderNo := SalesLn."Originally Ordered No."
            else
                OrgOrderNo := OrderNo;
            TempOrderPromisingLine."Source Line No." := SalesLn."Line No.";
            TempOrderPromisingLine."Quantity (Base)" := QtyNeed;
            TempOrderPromisingLine."Original Shipment Date" := SalesLn."Shipment Date";
            TempOrderPromisingLine."Earliest Shipment Date" := SupplementDate;

            LogMessageTxtBldr.AppendLine(StrSubstNo(LogMessageLbl,
                TempOrderPromisingLine.FieldCaption("Earliest Shipment Date"),
                Format(TempOrderPromisingLine."Earliest Shipment Date", 0, '<Day,2>.<Month,2>.<Year4>'),
                SalesLn."Line No.",
                SalesLn."No.",
                SalesLn."Variant Code",
                SalesLn.FieldCaption("Shipment Date"),
                Format(SalesLn."Shipment Date", 0, '<Day,2>.<Month,2>.<Year4>')));

            OutDataTxtBldr.AppendLine(StrSubstNo(NotAvailableErr,
                SalesLn.FieldCaption("Shipment Date"),
                Format(SalesLn."Shipment Date", 0, '<Day,2>.<Month,2>.<Year4>'),
                SalesLn."Line No.",
                SalesLn."No.",
                SalesLn."Variant Code",
                TempOrderPromisingLine.FieldCaption("Earliest Shipment Date"),
                Format(TempOrderPromisingLine."Earliest Shipment Date", 0, '<Day,2>.<Month,2>.<Year4>'), TempOrderPromisingLine."Quantity (Base)"));
            OutDataTxtBldr.AppendLine();

            CreateConstructedJsonResponse(DocType, OrgOrderNo, TempOrderPromisingLine, ResponsArray);
        end;
    end;

    local procedure FinishResponse(LogMessageTxtBldr: TextBuilder; OutDataTxtBldr: TextBuilder; ResponsArray: JsonArray; ItemFilter: Text; var IfwLog: Record "IFW Log")
    var
        ResponsObject: JsonObject;
        ResponsTxt: Text;
    begin
        if LogMessageTxtBldr.Length > 0 then
            IfwLog.SetLogMessage(LogMessageTxtBldr.ToText());
        ResponsObject.Add('logNo', IfwLog."Log No");
        if OutDataTxtBldr.Length = 0 then
            ResponsObject.Add('status', 'OK')
        else begin
            ResponsObject.Add('status', 'Warning');
            ResponsObject.Add('userMsg', OutDataTxtBldr.ToText());
            ResponsObject.Add('lines', ResponsArray.AsToken());
        end;
        ResponsObject.WriteTo(ResponsTxt);
        // IfwLog."Target Record View" := SetReservationView(ItemFilter);
        ifwlog.UpdateTargetRecRef(SetReservationView(ItemFilter), false);

        if IfwLog."Parameter String" = JobInvtChkRqstMgt.GetLocalTxt() then
            IfwLog.SetInData(ResponsTxt)
        else
            IfwLog.SetOutData(ResponsTxt);
    end;

    local procedure SetReservationView(ItemFilter: Text) RecRef: RecordRef
    var
        ReservEntry: Record "Reservation Entry";
        IfwConstants: Enum "AVLB Setup Constants";
    begin
        ReservEntry.SetRange("Location Code", CopyStr(SetupMgt.GetSetupValueAsText(IfwConstants::SetupInventoryChkLocation), 1, 10));
        ReservEntry.SetFilter("Item No.", ItemFilter);
        RecRef.GetTable(ReservEntry);
        // exit(ReservEntry.GetView());
    end;

    local procedure CreateConstructedJsonResponse(DocType: Text; OrgOrderNo: Code[20]; OrderPromisingLine: Record "Order Promising Line"; var ResponsArray: JsonArray)
    var
        OrderLine: JsonObject;
    begin
        OrderLine.Add('docType', DocType);
        OrderLine.Add('docNo', OrgOrderNo);
        OrderLine.Add('lineNo', OrderPromisingLine."Source Line No.");
        OrderLine.Add('orgShptDate', OrderPromisingLine."Original Shipment Date");
        OrderLine.Add('newShptDate', OrderPromisingLine."Earliest Shipment Date");
        ResponsArray.Add(OrderLine);
    end;

    var
        SetupMgt: Codeunit "AVLB Setup Mgt";
        JobInvtChkRqstMgt: Codeunit "AVLB Job InvtChkRqst Mgt";
        IfwIds: Enum "AVLB Setup Constants";
}