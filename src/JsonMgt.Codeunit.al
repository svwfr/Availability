namespace Bragda.Availability;
codeunit 50614 "AVLB Json Management"
{
    procedure TryGetJsonValue(JtokenAsText: Text; TokenKey: Text; var Jvalue: JsonValue): Boolean
    var
        Jobject: JsonObject;
    begin
        Jobject.ReadFrom(JtokenAsText);
        exit(TryGetJsonValue(Jobject, TokenKey, Jvalue));
    end;

    procedure TryGetJsonValue(Jtoken: JsonToken; TokenKey: Text; var Jvalue: JsonValue): Boolean
    var
        Jobject: JsonObject;
    begin
        Jvalue.SetValueToUndefined();
        if Jtoken.IsArray() then
            exit(false);
        if Jtoken.IsValue() then begin
            Jvalue := Jtoken.AsValue();
            exit(true);
        end;
        Jobject := Jtoken.AsObject();
        if Jobject.Get(TokenKey, Jtoken) then begin
            Jvalue := Jtoken.AsValue();

            if Jvalue.IsNull() or Jvalue.IsUndefined() then
                exit(false);
            exit(true);
        end;
        exit(false);
    end;

    procedure TryGetJsonValue(Jobject: JsonObject; ObjectKey: Text; var Jvalue: JsonValue): Boolean
    var
        Jtoken: JsonToken;
    begin
        if Jobject.Get(ObjectKey, Jtoken) then begin
            Jvalue := Jtoken.AsValue();
            if Jvalue.IsNull() or Jvalue.IsUndefined() then
                exit(false);
            exit(true);
        end;
        exit(false);
    end;

    procedure TryGetJsonObject(Jtoken: JsonToken; TokenKey: Text; var Jobject: JsonObject): Boolean
    begin
        if Jtoken.IsArray() then
            exit(false);
        if Jtoken.IsValue then
            exit(false);
        Jobject := Jtoken.AsObject();
        if Jobject.Get(TokenKey, Jtoken) then
            if Jtoken.IsObject then begin
                Jobject := Jtoken.AsObject();
                exit(true)
            end else
                exit(false)
        else
            exit(false);
    end;

    procedure AddObjectToArray(var JArray: JsonArray; JObject: JsonObject)
    begin
        JArray.Add(JObject);
    end;

    procedure AddValueToArray(var JArray: JsonArray; Input: Variant)
    var
        JValue: JsonValue;
    begin
        JValue.SetValue(Format(Input, 0, 9));
        JArray.Add(JValue);
    end;

    procedure AddValueToObject(var JObject: JsonObject; JKey: Text; Input: Variant)
    var
        JValue: JsonValue;
    begin
        JValue.SetValue(Format(Input, 0, 9));
        JObject.Add(JKey, JValue);
    end;

    procedure AddDecValueToObject(var JObject: JsonObject; JKey: Text; Input: Decimal)
    var
        JValue: JsonValue;
    begin
        JValue.SetValue(Input);
        JObject.Add(JKey, JValue);
    end;

    procedure AddArrayToObject(var JObject: JsonObject; JKey: Text; JArray: JsonArray)
    begin
        JObject.Add(JKey, JArray);
    end;

    procedure AddObjectToObject(var JObject: JsonObject; JKey: Text; JObject2: JsonObject)
    begin
        JObject.Add(JKey, JObject2);
    end;

}