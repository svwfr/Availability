namespace Byx.Availability;
codeunit 50615 "AVLB Single Instance Mgt"
{
    SingleInstance = true;

    var
        InventoryCheckRunning: Boolean;
        JobCreWhsePickRunning: Boolean;
        JobCreWhseShptRunning: Boolean;
        UpdatingSalesLineQty: Boolean;
        SkipContainerCodeCheck: Boolean;
        OverridePrinterName: Text[250];
        SkipRunInvCheck: Boolean;
        SkipInvCheckForWebOrders: Boolean;
        FirstWhseDocNo: Code[20];
        LastWhseDocNo: Code[20];
        SalesHeaderDocNo: Code[20];
        ExternalDocNo: Code[35];
        ValueEntryNo: Integer;

    procedure SetSalesHeaderDocNo(NewSalesHeaderDocNo: Code[20])
    begin
        SalesHeaderDocNo := NewSalesHeaderDocNo;
    end;

    procedure GetSalesHeaderDocNo(): Code[20]
    begin
        exit(SalesHeaderDocNo);
    end;

    procedure GetInventoryCheckRunning(): Boolean
    begin
        exit(InventoryCheckRunning);
    end;

    procedure GetSkipRunInvCheck(): Boolean
    begin
        exit(SkipRunInvCheck);
    end;

    procedure SetInventoryCheckRunning(NewValue: Boolean)
    begin
        InventoryCheckRunning := NewValue;
    end;

    procedure SetSkipRunInvCheck(NewValue: Boolean)
    begin
        SkipRunInvCheck := NewValue;
    end;

    procedure GetSkipInvCheckForWebOrders(): Boolean
    begin
        exit(SkipInvCheckForWebOrders);
    end;

    procedure SetSkipInvCheckForWebOrders(NewValue: Boolean)
    begin
        SkipInvCheckForWebOrders := NewValue;
    end;
}
