unit uPessoa;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.DateUtils, System.Generics.Collections;

type
  TPessoa = class
  private
    FIdPessoa: Int64;
    FNome: string;
    FSobrenome: string;
    FDocumento: string;
    FCep: string;
    FDataRegistro: TDate;
    FNatureza: integer;
  public
    constructor Create(); overload;
    constructor Create(AJson: TJSONObject); overload;
    constructor Create(const ANome, ASobrenome, ADocumento: string; ADataRegistro: TDateTime; ANatureza: integer; ACep: string); overload;
    procedure FromJSON(AJson: TJSONObject);
    function ToJSON: TJSONObject;
    function ToJSONList(const JSONData: TJSONObject): TList<TPessoa>;
    property IdPessoa: Int64 read FIdPessoa write FIdPessoa;
    property Nome: string read FNome write FNome;
    property Sobrenome: string read FSobrenome write FSobrenome;
    property Documento: string read FDocumento write FDocumento;
    property Natureza: integer read FNatureza write FNatureza;
    property Cep: string read FCep write FCep;
    property DataRegistro: TDate read FDataRegistro write FDataRegistro;
  end;

implementation

{ TPessoa }

constructor TPessoa.Create();
begin
  inherited Create;
end;

constructor TPessoa.Create(AJson: TJSONObject);
begin
  inherited Create;
  FromJSON(AJson);
end;

constructor TPessoa.Create(const ANome, ASobrenome, ADocumento: string; ADataRegistro: TDateTime; ANatureza: integer; ACep: string);
begin
  FNome := ANome;
  FSobrenome := ASobrenome;
  FDocumento := ADocumento;
  FDataRegistro := ADataRegistro;
  FNatureza := ANatureza;
  FCep := ACep;
end;

procedure TPessoa.FromJSON(AJson: TJSONObject);
begin
  if Assigned(AJson) then
  begin
    if AJson.Values['idpessoa'] <> nil then
      FIdPessoa := AJson.Values['idpessoa'].AsType<Int64>;
    if AJson.Values['primeiro_nome'] <> nil then
      FNome := AJson.Values['primeiro_nome'].Value;
    if AJson.Values['segundo_nome'] <> nil then
      FSobrenome := AJson.Values['segundo_nome'].Value;
    if AJson.Values['documento'] <> nil then
      FDocumento := AJson.Values['documento'].Value;
    if AJson.Values['natureza'] <> nil then
      FNatureza := AJson.Values['natureza'].Value.ToInteger;
    if AJson.Values['cep'] <> nil then
      FCep := AJson.Values['cep'].Value;
    if AJson.Values['data_registro'] <> nil then
      FDataRegistro := ISO8601ToDate(AJson.Values['data_registro'].Value);
  end;
end;

function TPessoa.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('idpessoa', TJSONNumber.Create(FIdPessoa));
  Result.AddPair('nome', FNome);
  Result.AddPair('sobrenome', FSobrenome);
  Result.AddPair('documento', FDocumento);
  Result.AddPair('natureza', FNatureza);
  Result.AddPair('cep', FCep);
  Result.AddPair('dataregistro', DateToISO8601(FDataRegistro));
end;

function TPessoa.ToJSONList(const JSONData: TJSONObject): TList<TPessoa>;
var
  JSONArray: TJSONArray;
  JSONObject: TJSONObject;
  PessoaObj: TJSONObject;
  i: integer;
  ListaPessoas: TList<TPessoa>;
  Nome, Sobrenome, Documento, Cep: string;
  DataRegistro: TDateTime;
  Natureza: integer;
begin
  ListaPessoas := TList<TPessoa>.Create;
  try
    JSONArray := JSONData.GetValue<TJSONArray>('pessoas');
    if not Assigned(JSONArray) then
      raise Exception.Create('Formato de JSON inválido. "pessoas" não encontrado.');
    for i := 0 to JSONArray.Count - 1 do
    begin
      JSONObject := JSONArray.Items[i] as TJSONObject;
      PessoaObj := JSONObject.GetValue<TJSONObject>('pessoa');
      if not Assigned(PessoaObj) then
        raise Exception.Create('Objeto "pessoa" não encontrado.');
      Nome := PessoaObj.GetValue<string>('nome');
      Sobrenome := PessoaObj.GetValue<string>('sobrenome');
      Documento := PessoaObj.GetValue<string>('documento');
      Cep := PessoaObj.GetValue<string>('cep');
      DataRegistro:=now;
      Natureza := PessoaObj.GetValue<integer>('natureza');
      ListaPessoas.Add(TPessoa.Create(Nome, Sobrenome, Documento, DataRegistro, Natureza, Cep));
    end;
    Result := ListaPessoas;
  except
    on E: Exception do
    begin
      ListaPessoas.Free;
      raise Exception.Create('Erro ao processar o JSON: ' + E.Message);
    end;
  end;
end;

end.
