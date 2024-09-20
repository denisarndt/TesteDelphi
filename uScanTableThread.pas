unit uScanTableThread;

interface

uses
  System.Classes,
  System.SysUtils, System.JSON, System.Net.HttpClient, uData;

type
  TScanTableThread = class(TThread)
  private
    FDatabase: TMyDatabase;
    FInterval: Integer;
    procedure ScanTable;
    function GetEnderecoViaCEP(CEP: string): TJSONObject;
  protected
    procedure Execute; override;
  public
    constructor Create(AInterval: Integer);
    destructor Destroy; override;
  end;

implementation

{ TScanTableThread }

constructor TScanTableThread.Create(AInterval: Integer);
begin
  inherited Create(True);
  FDatabase := TMyDatabase.Create(nil);
  FInterval := AInterval;
  FreeOnTerminate := True;
  Suspended := false;
end;

destructor TScanTableThread.Destroy;
begin
  FDatabase.Free;
  inherited;
end;

procedure TScanTableThread.Execute;
begin
  while not Terminated do
  begin
    try
      ScanTable;
      Sleep(FInterval);
    except
      on E: Exception do
      begin
      end;
    end;
  end;
end;

function TScanTableThread.GetEnderecoViaCEP(CEP: string): TJSONObject;
var
  HttpClient: THTTPClient;
  Response: IHTTPResponse;
  URL, JsonResponse, CleanedJSonResponse: string;
  JSONObj: TJSONObject;
begin
  HttpClient := THTTPClient.Create;
  try
    URL := 'https://viacep.com.br/ws/' + CEP + '/json/';
    Response := HttpClient.Get(URL);
    if Response.StatusCode = 200 then
    begin
      JsonResponse := Response.ContentAsString(TEncoding.UTF8);
      CleanedJSonResponse := StringReplace(JsonResponse, #$A, '', [rfReplaceAll]);
      JSONObj := TJSONObject.ParseJSONValue(CleanedJSonResponse) as TJSONObject;
      Result := JSONObj;
    end
    else
      raise Exception.Create('Erro ao acessar a API do ViaCEP. Status: ' + IntToStr(Response.StatusCode));
  finally
    HttpClient.Free;
  end;
end;

procedure TScanTableThread.ScanTable;
var
  JsonAusentes, JsonViaCepResponse: TJSONObject;
  JsonArray: TJSONArray;
  id: Integer;
  CEP: string;
  ArrayElement: TJSonValue;
begin
  JsonAusentes := FDatabase.GetEnderecosAusentesAsJSON();
  try
    JsonArray := JsonAusentes.GetValue<TJSONArray>('enderecos');
    for ArrayElement in JsonArray do
    begin
      id := ArrayElement.GetValue<Integer>('idendereco');
      CEP := ArrayElement.GetValue<string>('cep');
      JsonViaCepResponse := GetEnderecoViaCEP(CEP);
      FDatabase.SalvarEndereco(id, JsonViaCepResponse);
    end;
  except

  end;
end;

end.
