page 50601 "AVLB Inventory Check List"
{
    Caption = 'Inventory Check List', Locked = true;
    PageType = List;
    UsageCategory = Administration;
    ApplicationArea = All;
    SourceTable = "Reservation Entry";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {

                field("Location Code"; Rec."Location Code")
                {
                    ToolTip = 'Specifies the Location of the items that have been reserved in the entry.', Locked = true;
                }
                field("Entry No."; Rec."Entry No.")
                {
                    ToolTip = 'Specifies the number of the entry, as assigned from the specified number series when the entry was created.', Locked = true;
                }
                field("Item No."; Rec."Item No.")
                {
                    ToolTip = 'Specifies the number of the item that has been reserved in this entry.', Locked = true;
                }
                field("Variant Code"; Rec."Variant Code")
                {
                    ToolTip = 'Specifies the variant of the item on the line.';
                }
                field(Quantity; Rec.Quantity)
                {
                    ToolTip = 'Specifies the quantity of the record.', Locked = true;
                }
                field("Reservation Status"; Rec."Reservation Status")
                {
                    ToolTip = 'Specifies the status of the reservation.', Locked = true;
                }
                field("Source Type"; Rec."Source Type")
                {
                    ToolTip = 'Specifies for which source type the reservation entry is related to.', Locked = true;
                }
                field("Source Subtype"; Rec."Source Subtype")
                {
                    ToolTip = 'Specifies which source subtype the reservation entry is related to.', Locked = true;
                }
                field("Source Batch Name"; Rec."Source Batch Name")
                {
                    ToolTip = 'Specifies the journal batch name if the reservation entry is related to a journal or requisition line.', Locked = true;
                }
                field("Source ID"; Rec."Source ID")
                {
                    ToolTip = 'Specifies which source ID the reservation entry is related to.', Locked = true;
                }
                field("Source Ref. No."; Rec."Source Ref. No.")
                {
                    ToolTip = 'Specifies a reference number for the line, which the reservation entry is related to.', Locked = true;
                }
                field("Expected Receipt Date"; Rec."Expected Receipt Date")
                {
                    ToolTip = 'Specifies the date on which the reserved items are expected to enter inventory.', Locked = true;
                }
                field("Shipment Date"; Rec."Shipment Date")
                {
                    ToolTip = 'Specifies when items on the document are shipped or were shipped. A shipment date is usually calculated from a requested delivery date plus lead time.', Locked = true;
                }
                field("Untracked Surplus"; Rec."Untracked Surplus")
                {
                    ToolTip = 'Specifies the value of the Untracked Surplus field.', Comment = '%', Locked = true;
                }
                field(SystemCreatedAt; Rec.SystemCreatedAt)
                {
                    ToolTip = 'Specifies the value of the SystemCreatedAt field.', Comment = '%', Locked = true;
                }
                field(SystemCreatedBy; Rec.SystemCreatedBy)
                {
                    Visible = false;
                    ToolTip = 'Specifies the value of the SystemCreatedBy field.', Comment = '%', Locked = true;
                }
                field(SystemModifiedAt; Rec.SystemModifiedAt)
                {
                    Visible = false;
                    ToolTip = 'Specifies the value of the SystemModifiedAt field.', Comment = '%', Locked = true;
                }
                field(SystemModifiedBy; Rec.SystemModifiedBy)
                {
                    Visible = false;
                    ToolTip = 'Specifies the value of the SystemModifiedBy field.', Comment = '%', Locked = true;
                }

            }
        }
        area(Factboxes)
        {

        }
    }

    actions
    {
        area(Processing)
        {
            action(Navigate)
            {
                Caption = 'Navigate';
                Image = Navigate;
                ToolTip = 'Open the source card';

                trigger OnAction()
                var
                    TransHdr: Record "Transfer Header";
                    SalesHdr: Record "Sales Header";
                    ItemLedgEntry: Record "Item Ledger Entry";
                begin
                    case Rec."Source Type" of
                        database::"Transfer Line":
                            begin
                                TransHdr.Get(Rec."Source ID");
                                Page.RunModal(Page::"Transfer Order", TransHdr);
                            end;
                        Database::"Sales Line":
                            begin
                                SalesHdr.Get(SalesHdr."Document Type"::Order, Rec."Source ID");
                                Page.RunModal(Page::"Sales Order", SalesHdr);
                            end;
                        Database::"Item Ledger Entry":
                            begin
                                ItemLedgEntry.Get(Rec."Source Ref. No.");
                                ItemLedgEntry.SetRange("Item No.", ItemLedgEntry."Item No.");
                                ItemLedgEntry.SetRange("Variant Code", ItemLedgEntry."Variant Code");
                                ItemLedgEntry.SetRange(Open, true);
                                Page.RunModal(Page::"Item Ledger Entries", ItemLedgEntry);
                            end;
                    end;
                end;
            }

            group("Item Availability by")
            {
                Caption = 'Item Availability by';
                Image = ItemAvailability;
                action(ByEvent)
                {
                    Caption = 'Availability By Event';
                    Image = "Event";
                    ToolTip = 'View how the actual and the projected available balance of an item will develop over time according to supply and demand events.';

                    trigger OnAction()
                    var
                        Item: Record Item;
                        FutureDate: Date;
                    begin
                        Item.Get(Rec."Item No.");
                        FutureDate := CalcDate('<1Y>', Today);
                        ItemAvailFormsMgt.FilterItem(Item, Rec."Location Code", Rec."Variant Code", FutureDate);
                        ItemAvailFormsMgt.ShowItemAvailabilityByEvent(Item, CopyStr(Item.Description, 1, 80), Rec."Shipment Date", FutureDate, false)
                    end;
                }
            }
            group("Analysis")
            {
                Caption = 'Analysis';
                Image = AnalysisViewDimension;
                action(TrackPairAudit)
                {
                    Caption = 'Track Pair Audit';
                    Image = CopySerialNo;
                    ToolTip = 'For status <tracking>, there should always be a pair (positive/negative). If not so, this action will expose these single tracking entries.';

                    trigger OnAction()
                    var
                        FilterToView: Text;
                        AllGoodMsg: Label 'No tracked entries were found that were not paired', Locked = true;
                    begin
                        FilterToView := TrimTrackedRecMgt.TrackPairAudit();
                        if FilterToView <> '' then begin
                            Rec.SetFilter("Entry No.", FilterToView);
                            CurrPage.Update();
                        end else
                            Message(AllGoodMsg);
                    end;
                }
                action(DeleteEmptyILE)
                {
                    Caption = 'Delete Empty ILE';
                    Image = CopySerialNo;
                    ToolTip = 'Reservation entry for ILE without source ref will be deleted';

                    trigger OnAction()
                    var
                        Item: Record Item;
                        FilterToView: Text;
                        AllGoodMsg: Label 'Non empty ILE entries was found', Locked = true;
                    begin
                        FilterToView := TrimTrackedRecMgt.DeleteEmptyILE();
                        if FilterToView <> '' then begin
                            Item.SetFilter("No.", FilterToView);
                            Report.Run(Report::"AVLB Trim Reservation Entries", false, false, Item);
                            Rec.SetFilter("Item No.", FilterToView);
                            CurrPage.Update();
                        end else
                            Message(AllGoodMsg);
                    end;
                }
            }
        }

        area(Promoted)
        {
            actionref(ByEvent_Promoted; ByEvent)
            { }
            actionref(Navigate_Promoted; Navigate)
            { }

        }
    }

    trigger OnOpenPage()
    var
        CompInfo: Record "Company Information";
    begin
        CompInfo.Get();
        Rec.Ascending(false);
        Rec.FilterGroup(2);
        Rec.SetFilter("Location Code", CompInfo."Location Code");
        Rec.FilterGroup(0);
    end;

    var
        ItemAvailFormsMgt: Codeunit "Item Availability Forms Mgt";
        TrimTrackedRecMgt: Codeunit "AVLB Trim Reservation Mgt";
}