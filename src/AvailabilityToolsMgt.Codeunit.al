namespace Byx.Availability;
codeunit 50603 "AVLB Availability Tools Mgt"
{
    procedure GetCharsFromString(txtString: Text; txtCharsToKeep: Text) RetVal: Text
    begin
        exit(DelChr(txtString, '=', DelChr(txtString, '=', txtCharsToKeep)));
    end;

    procedure GetModuleInfo() RetVal: Text
    var
        Cnt: Integer;
        ModDepInfoList: List of [ModuleDependencyInfo];
        ModDepInfo: ModuleDependencyInfo;
        ModInfo: ModuleInfo;
        DetailsTxtBldr: TextBuilder;
    begin
        NavApp.GetCurrentModuleInfo(ModInfo);
        ModDepInfoList := ModInfo.Dependencies();

        DetailsTxtBldr.AppendLine('Module Information:');
        DetailsTxtBldr.AppendLine(StrSubstNo('  Id: %1', ModInfo.Id));
        DetailsTxtBldr.AppendLine(StrSubstNo('  Name: %1', ModInfo.Name));
        DetailsTxtBldr.AppendLine(StrSubstNo('  Publisher: %1', ModInfo.Publisher));
        DetailsTxtBldr.AppendLine(StrSubstNo('  Appversion: %1', ModInfo.AppVersion));
        DetailsTxtBldr.AppendLine(StrSubstNo('  Dataversion: %1', ModInfo.DataVersion));
        DetailsTxtBldr.AppendLine(StrSubstNo('  PackageId: %1', ModInfo.PackageId));
        foreach ModDepInfo in ModDepInfoList do begin
            Cnt += 1;
            DetailsTxtBldr.AppendLine('');
            DetailsTxtBldr.AppendLine(StrSubstNo('  Dependency #%1:', Cnt));
            DetailsTxtBldr.AppendLine(StrSubstNo('    Id: %1', ModDepInfo.Id));
            DetailsTxtBldr.AppendLine(StrSubstNo('    Name: %1', ModDepInfo.Name));
            DetailsTxtBldr.AppendLine(StrSubstNo('    Publisher: %1', ModDepInfo.Publisher));
        end;
        RetVal := DetailsTxtBldr.ToText();
    end;

    procedure GetBoolFieldValue(var RecRef: RecordRef; FieldName: Text) RetVal: Boolean
    var
        FldRef: FieldRef;
        i: Integer;
    begin
        for i := 1 to RecRef.FieldCount() do begin
            FldRef := RecRef.FieldIndex(i);
            if FldRef.Active() and (UpperCase(FldRef.Name) = UpperCase(FieldName)) then
                exit(FldRef.Value());
        end;
    end;

    procedure GetIntegerFieldValue(var RecRef: RecordRef; FieldName: Text) RetVal: Integer
    var
        FldRef: FieldRef;
        i: Integer;
    begin
        for i := 1 to RecRef.FieldCount() do begin
            FldRef := RecRef.FieldIndex(i);
            if FldRef.Active() and (UpperCase(FldRef.Name) = UpperCase(FieldName)) then
                exit(FldRef.Value());
        end;
    end;

    procedure GetTextFieldValue(var RecRef: RecordRef; FieldName: Text) RetVal: Text
    var
        FldRef: FieldRef;
        i: Integer;
    begin
        for i := 1 to RecRef.FieldCount() do begin
            FldRef := RecRef.FieldIndex(i);
            if FldRef.Active() and (UpperCase(FldRef.Name) = UpperCase(FieldName)) then
                exit(FldRef.Value());
        end;
    end;

}
