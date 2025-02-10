namespace Byx.Availability;

using System.Security.Authentication;

codeunit 50601 "AVLB WebServiceHttp Mgt"
{
    var
        SetupMgt: Codeunit "AVLB Setup Mgt";
        IfwIds: Enum "AVLB Setup Constants";

    procedure AddBcEnvironment2Url(Url: Text): Text
    begin
        if Url.Contains('%3') then
            exit(StrSubstNo(Url, SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2TenantId), SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2Environment), SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2CompanyGuid)))
        else
            if Url.Contains('%1') then
                exit(StrSubstNo(Url, SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2TenantId), SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2Environment)))
            else
                exit(Url);
    end;

    procedure GetToken() AccessToken: SecretText
    var
        OAuth2: Codeunit OAuth2;
        TokenErr: Label 'Failed to retrieve access token\%1', Comment = '%1=ErrorMsg';
        Scopes: List of [Text];
        ClientId: Text;
        ClientSecret: SecretText;
        OAuthAuthorityUrl: Text;
    begin
        Scopes.Add('https://api.businesscentral.dynamics.com/.default');
        ClientId := SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2ClientId);
        ClientSecret := SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2ClientSecret);
        OAuthAuthorityUrl := StrSubstNo(Format(IfwIds::SetupOauth2TokenUrl), SetupMgt.GetSetupValueAsText(IfwIds::SetupOauth2TenantId));

        if (not OAuth2.AcquireAuthorizationCodeTokenFromCache(ClientId, ClientSecret, '', OAuthAuthorityUrl, Scopes, AccessToken)) or AccessToken.IsEmpty() then
            OAuth2.AcquireTokenWithClientCredentials(ClientId, ClientSecret, OAuthAuthorityUrl, '', Scopes, AccessToken);

        if AccessToken.IsEmpty() then
            Error(TokenErr, GetLastErrorText());

        exit(AccessToken);
    end;

    procedure InvokeApi(RequestMethod: Enum "AVLB Http Request Method"; Url: Text; RequestContent: Text) ResponseContent: Text
    var
        IfwToolsMgt: Codeunit "IFW Tools Mgt";
        WebHttpClient: HttpClient;
        WebHttpContent: HttpContent;
        WebHttpHeaders: HttpHeaders;
        WebHttpResponse: HttpResponseMessage;
        ResponseErr: Label 'The web service returned an error message:\Status code: %1\Description: %2\\Request Details:\%3: %4\\Content: %5', Comment = '%1=HttpStatusCode,%2=HttpReasonPhrase,%3=RequestMethod,%4=RequestUrl,%5=RequestContent', Locked = true;
    begin
        WebHttpClient.DefaultRequestHeaders().Add('Authorization', SecretStrSubstNo('Bearer %1', GetToken()));
        if RequestContent <> '' then begin
            WebHttpContent.WriteFrom(RequestContent);
            WebHttpContent.GetHeaders(WebHttpHeaders);
            WebHttpHeaders.Clear();
            WebHttpHeaders.Add('Content-Type', 'application/json');
        end;

        case RequestMethod of
            RequestMethod::Get:
                WebHttpClient.Get(Url, WebHttpResponse);
            RequestMethod::Post:
                WebHttpClient.Post(Url, WebHttpContent, WebHttpResponse);
            RequestMethod::Put:
                WebHttpClient.Put(Url, WebHttpContent, WebHttpResponse);
            RequestMethod::Delete:
                WebHttpClient.Delete(Url, WebHttpResponse);
        end;

        WebHttpResponse.Content.ReadAs(ResponseContent);
        if not WebHttpResponse.IsSuccessStatusCode then
            Error(StrSubstNo(ResponseErr, WebHttpResponse.HttpStatusCode, WebHttpResponse.ReasonPhrase, RequestMethod, Url, RequestContent).Replace('\', IfwToolsMgt.GetCRLF()));
    end;

    procedure InvokeGet(Url: Text): Text
    begin
        exit(InvokeApi(Enum::"AVLB Http Request Method"::Get, Url, ''));
    end;

    procedure InvokePost(Url: Text; RequestContent: Text) Respons: Text
    begin
        Respons := InvokeApi(Enum::"AVLB Http Request Method"::Post, Url, RequestContent);
    end;
}
