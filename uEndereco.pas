unit uEndereco;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.DateUtils;

type
  TEndereco = class
  private
    FIdEndereco: Int64;
    FIdPessoa: Int64;
    FCep: string;
  public
    constructor Create(AJson: TJSONObject);
    procedure FromJSON(AJson: TJSONObject);
    function ToJSON: TJSONObject;
    property IdPessoa: Int64 read FIdPessoa write FIdPessoa;
    property IdEndereco: Int64 read FIdEndereco write FIdEndereco;
    property Cep: string read FCep write FCep;
  end;

implementation

{ TPessoa }

constructor TEndereco.Create(AJson: TJSONObject);
begin
  inherited Create;
  FromJSON(AJson);
end;

procedure TEndereco.FromJSON(AJson: TJSONObject);
begin
  if Assigned(AJson) then
  begin
    if AJson.Values['idpessoa'] <> nil then
      FIdPessoa := AJson.Values['idpessoa'].AsType<Int64>;
    if AJson.Values['idendereco'] <> nil then
      FIdEndereco := AJson.Values['idendereco'].AsType<Int64>;
    if AJson.Values['cep'] <> nil then
      FCep := AJson.Values['cep'].Value;
  end;
end;

function TEndereco.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('idpessoa', TJSONNumber.Create(FIdPessoa));
  Result.AddPair('idendereco', TJSONNumber.Create(FIdEndereco));
  Result.AddPair('cep', FCep);
end;

end.
