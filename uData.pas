unit uData;

interface

uses
  System.SysUtils, System.Classes, FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.Comp.DataSet,
  FireDAC.Phys.PG, FireDAC.Phys.PGDef, FireDAC.Stan.Intf, System.JSON, uPessoa, uEndereco, System.IOUtils, System.Generics.Collections;

type
  TMyDatabase = class(TFDConnection)
  private
    FDriverLink: TFDPhysPgDriverLink;
  public
    constructor Create(AOwner: TComponent); override;
    function ExecuteQuery(const SQL: string; Params: array of Variant): TFDQuery;
    function ExecuteInsert(const SQL: string; Params: array of Variant): Integer;
    function SalvarEndereco(id: Integer; jsonAddress: TJSONObject): boolean;
    function GetEnderecosAusentesAsJSON(): TJSONObject;
    function SalvarPessoa(pessoa: TPessoa): TJSONObject;
    function DeletarPessoa(pessoa: TPessoa): TJSONObject;
    function AlterarPessoa(pessoa: TPessoa): TJSONObject;
    function ConsultarEnderecoPorId(id: int64): TEndereco;
    function ConsultarEnderecoPorPessoa(id: int64): TEndereco;
    function AlterarEndereco(endereco: TEndereco): boolean;
    function DeletarEnderecoIntegracao(id: Integer): boolean;
    function SalvarLote(listaPessoas: TList<TPessoa>): TJSONObject;
  end;

implementation

constructor TMyDatabase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDriverLink := TFDPhysPgDriverLink.Create(nil);
  FDriverLink.VendorLib := 'C:\Program Files (x86)\PostgreSQL\10\bin\libpq.dll';
  Self.DriverName := 'PG';
  Self.Params.Values['Database'] := 'Teste';
  Self.Params.Values['User_Name'] := 'postgres';
  Self.Params.Values['Password'] := 'de08009';
  Self.Params.Values['Server'] := 'localhost';
  Self.LoginPrompt := False;
end;

function TMyDatabase.ExecuteQuery(const SQL: string; Params: array of Variant): TFDQuery;
var
  Query: TFDQuery;
  I: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Self;
    Query.SQL.Text := SQL;
    for I := Low(Params) to High(Params) do
    begin
      Query.Params[I].Value := Params[I];
    end;
    Query.Open;
    Result := Query;
  except
    on E: Exception do
    begin
      Query.Free;
      raise Exception.Create('Erro ao executar a query: ' + E.Message);
    end;
  end;
end;

function TMyDatabase.ExecuteInsert(const SQL: string; Params: array of Variant): Integer;
var
  Query: TFDQuery;
  I: Integer;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Self;
    Query.SQL.Text := SQL;

    for I := Low(Params) to High(Params) do
    begin
      Query.Params[I].Value := Params[I];
    end;

    Query.ExecSQL;
    Result := Query.RowsAffected;
  finally
    Query.Free;
  end;
end;

function TMyDatabase.SalvarEndereco(id: Integer; jsonAddress: TJSONObject): boolean;
var
  Query: TFDQuery;
  sqlQuery: string;
  uf, cidade, bairro, logradouro, complemento: string;
const
  _INSERT_ENDERECO_INTEGRACAO = 'INSERT INTO endereco_integracao (idendereco, dsuf, nmcidade, nmbairro, nmlogradouro, dscomplemento) VALUES (%d, ''%s'', ''%s'', ''%s'', ''%s'', ''%s'');';
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Self;
    try
      if jsonAddress.Values['erro'] = nil then
      begin
        bairro := jsonAddress.Values['bairro'].Value;
        logradouro := jsonAddress.Values['logradouro'].Value;
        uf := jsonAddress.Values['uf'].Value;
        cidade := jsonAddress.Values['localidade'].Value;
        complemento := jsonAddress.Values['complemento'].Value;
      end
      else
      begin
        bairro := 'Não encontrado';
        logradouro := 'Não encontrado';
        uf := 'Não encontrado';
        cidade := 'Não encontrado';
        complemento := 'Não encontrado';
      end;
      sqlQuery := Format(_INSERT_ENDERECO_INTEGRACAO, [id, uf, cidade, bairro, logradouro, complemento]);
      Query.SQL.Text := sqlQuery;
      Query.ExecSQL;
      Result := true;
    except
      on E: Exception do
      begin
        Result := False;
      end;
    end;
  finally
    Query.Free;
  end;
end;

function TMyDatabase.GetEnderecosAusentesAsJSON(): TJSONObject;
var
  FDQuery: TFDQuery;
  JSONObj: TJSONObject;
  JSONArray: TJSONArray;
begin
  FDQuery := TFDQuery.Create(nil);
  try
    FDQuery.Connection := Self;
    FDQuery.SQL.Text := 'SELECT idendereco, dscep FROM endereco p WHERE NOT EXISTS (SELECT 1 FROM endereco_integracao e WHERE e.idendereco = p.idendereco);';
    FDQuery.Open;
    JSONArray := TJSONArray.Create;
    while not FDQuery.Eof do
    begin
      JSONObj := TJSONObject.Create;
      JSONObj.AddPair('idendereco', TJSONNumber.Create(FDQuery.FieldByName('idendereco').AsLargeInt));
      JSONObj.AddPair('cep', FDQuery.FieldByName('dscep').AsString);
      JSONArray.AddElement(JSONObj);
      FDQuery.Next;
    end;
    Result := TJSONObject.Create;
    Result.AddPair('enderecos', JSONArray);
  finally
    FDQuery.Free;
  end;
end;

function TMyDatabase.SalvarPessoa(pessoa: TPessoa): TJSONObject;
const
  _INSERT_PESSOA = 'INSERT INTO pessoa (flnatureza, dsdocumento, nmprimeiro, nmsegundo, dtregistro) VALUES (%d, ''%s'', ''%s'', ''%s'', ''%s'') RETURNING idpessoa;';
  _INSERT_ENDERECO = 'INSERT INTO endereco (idpessoa, dscep) VALUES (%d, ''%s'');';
var
  Query: TFDQuery;
  Transaction: TFDTransaction;
  sqlQueryPessoa: string;
  sqlQueryEndereco: string;
begin
  Query := TFDQuery.Create(nil);
  Transaction := TFDTransaction.Create(nil);
  try
    Query.Connection := Self;
    Transaction.Connection := Self;
    Self.StartTransaction;
    try
      sqlQueryPessoa := Format(_INSERT_PESSOA, [pessoa.Natureza, pessoa.Documento, pessoa.Nome, pessoa.Sobrenome, DateToStr(now)]);
      Query.Open(sqlQueryPessoa);
      pessoa.IdPessoa := Query.Fields[0].AsLargeInt;
      sqlQueryEndereco := Format(_INSERT_ENDERECO, [pessoa.IdPessoa, pessoa.Cep]);
      Query.ExecSQL(sqlQueryEndereco);
      Self.Commit;
      Result := pessoa.ToJSON;
      Result.AddPair('sucesso', true);
    except
      on E: Exception do
      begin
        Self.Rollback;
        Result := TJSONObject.Create;
        Result.AddPair('erro', E.Message);
        Result.AddPair('sucesso', False);
      end;
    end;
  finally
    Query.Free;
  end;
end;

function TMyDatabase.DeletarPessoa(pessoa: TPessoa): TJSONObject;
const
  _DELETE_PESSOA = 'DELETE FROM pessoa where idpessoa=%d';
var
  Query: TFDQuery;
  Transaction: TFDTransaction;
  sqlDeletePessoa: string;
begin
  Query := TFDQuery.Create(nil);
  Transaction := TFDTransaction.Create(nil);
  try
    Query.Connection := Self;
    Transaction.Connection := Self;
    Self.StartTransaction;
    try
      sqlDeletePessoa := Format(_DELETE_PESSOA, [pessoa.IdPessoa]);
      Query.ExecSQL(sqlDeletePessoa);
      Self.Commit;
      Result := pessoa.ToJSON;
      Result.AddPair('sucesso', true);
    except
      on E: Exception do
      begin
        Self.Rollback;
        Result := TJSONObject.Create;
        Result.AddPair('erro', E.Message);
        Result.AddPair('sucesso', False);
      end;
    end;
  finally
    Query.Free;
  end;
end;

function TMyDatabase.AlterarPessoa(pessoa: TPessoa): TJSONObject;
var
  Query: TFDQuery;
  Transaction: TFDTransaction;
begin
  Query := TFDQuery.Create(nil);
  Transaction := TFDTransaction.Create(nil);
  try
    Query.Connection := Self;
    Transaction.Connection := Self;
    Self.StartTransaction;
    try
      Query.SQL.Text := 'UPDATE pessoa SET flnatureza = :natureza,' + 'dsdocumento =:documento, nmprimeiro =:primeiro_nome, nmsegundo =:segundo_nome ' + 'WHERE idpessoa=:idpessoa;';
      Query.ParamByName('natureza').AsInteger := pessoa.Natureza;
      Query.ParamByName('documento').AsString := pessoa.Documento;
      Query.ParamByName('primeiro_nome').AsString := pessoa.Nome;
      Query.ParamByName('segundo_nome').AsString := pessoa.Sobrenome;
      Query.ParamByName('idpessoa').AsLargeInt := pessoa.IdPessoa;
      Query.ExecSQL;
      Self.Commit;
      Result := pessoa.ToJSON;
      Result.AddPair('sucesso', true);
    except
      on E: Exception do
      begin
        Self.Rollback;
        Result := TJSONObject.Create;
        Result.AddPair('erro', E.Message);
        Result.AddPair('sucesso', False);
      end;
    end;
  finally
    Query.Free;
  end;
end;

function TMyDatabase.AlterarEndereco(endereco: TEndereco): boolean;
const
  _UPDATE_ENDERECO = 'UPDATE endereco SET dscep=''%s'' WHERE idendereco=%d;';
var
  Query: TFDQuery;
  Transaction: TFDTransaction;
  sqlUpdateEndereco: string;
begin
  Query := TFDQuery.Create(nil);
  Transaction := TFDTransaction.Create(nil);
  try
    Query.Connection := Self;
    Transaction.Connection := Self;
    Self.StartTransaction;
    try
      sqlUpdateEndereco := Format(_UPDATE_ENDERECO, [endereco.Cep, endereco.IdEndereco]);
      Query.ExecSQL(sqlUpdateEndereco);
      Self.Commit;
      Result := Query.RowsAffected > 0;
    except
      on E: Exception do
      begin
        Self.Rollback;
        Result := False;
      end;
    end;
  finally
    Query.Free;
  end;
end;

function TMyDatabase.ConsultarEnderecoPorId(id: int64): TEndereco;
var
  FDQuery: TFDQuery;
  JSONObj: TJSONObject;
  JSONArray: TJSONArray;
begin
  FDQuery := TFDQuery.Create(nil);
  try
    try
      FDQuery.Connection := Self;
      FDQuery.SQL.Text := 'SELECT idendereco, dscep, idpessoa FROM endereco WHERE idendereco=' + inttostr(id) + ';';
      FDQuery.Open;
      if not FDQuery.IsEmpty then
      begin
        Result.Cep := FDQuery.FieldByName('dscep').AsString;
        Result.IdEndereco := FDQuery.FieldByName('idendereco').AsLargeInt;
        Result.IdPessoa := FDQuery.FieldByName('idpessoa').AsLargeInt;
      end
      else
        Result.IdEndereco := -1;
    except
      Result.IdEndereco := -2;
    end;
  finally
    FDQuery.Free;
  end;
end;

function TMyDatabase.ConsultarEnderecoPorPessoa(id: int64): TEndereco;
var
  FDQuery: TFDQuery;
  JSONObj: TJSONObject;
  JSONArray: TJSONArray;
begin
  FDQuery := TFDQuery.Create(nil);
  try
    try
      FDQuery.Connection := Self;
      FDQuery.SQL.Text := 'SELECT idendereco, dscep, idpessoa FROM endereco WHERE idpessoa=' + inttostr(id) + ';';
      FDQuery.Open;
      if not FDQuery.IsEmpty then
      begin
        Result.Cep := FDQuery.FieldByName('dscep').AsString;
        Result.IdEndereco := FDQuery.FieldByName('idendereco').AsLargeInt;
        Result.IdPessoa := FDQuery.FieldByName('idpessoa').AsLargeInt;
      end
      else
        Result.IdEndereco := -1;
    except
      Result.IdEndereco := -2;
    end;
  finally
    FDQuery.Free;
  end;
end;

function TMyDatabase.DeletarEnderecoIntegracao(id: Integer): boolean;
const
  _DELETE_ENDERECO_INTEGRACAO = 'DELETE FROM endereco_integracao where idendereco=%d';
var
  Query: TFDQuery;
  Transaction: TFDTransaction;
  sqlDeletePessoa: string;
begin
  Query := TFDQuery.Create(nil);
  Transaction := TFDTransaction.Create(nil);
  try
    Query.Connection := Self;
    Transaction.Connection := Self;
    Self.StartTransaction;
    try
      sqlDeletePessoa := Format(_DELETE_ENDERECO_INTEGRACAO, [id]);
      Query.ExecSQL(sqlDeletePessoa);
      Self.Commit;
      Result := Query.RowsAffected > 0;
    except
      on E: Exception do
      begin
        Self.Rollback;
        Result := False;
      end;
    end;
  finally
    Query.Free;
  end;
end;

function TMyDatabase.SalvarLote(listaPessoas: TList<TPessoa>): TJSONObject;
var
  pessoa: TPessoa;
  FDQuery: TFDQuery;
  IdPessoa: int64;
  savedCounter: int64;
begin
  FDQuery := TFDQuery.Create(nil);
  try
    FDQuery.Connection := Self;
    Self.StartTransaction;
    try
      savedCounter := 0;
      for pessoa in listaPessoas do
      begin
        FDQuery.SQL.Text := 'INSERT INTO pessoa (nmprimeiro, nmsegundo, dsdocumento, dtregistro, flnatureza) ' + 'VALUES (:nmprimeiro, :nmsegundo, :dsdocumento, :dtregistro, :flnatureza) RETURNING idpessoa;';
        FDQuery.ParamByName('nmprimeiro').AsString := pessoa.Nome;
        FDQuery.ParamByName('nmsegundo').AsString := pessoa.Sobrenome;
        FDQuery.ParamByName('dsdocumento').AsString := pessoa.Documento;
        FDQuery.ParamByName('dtregistro').AsDate := now;
        FDQuery.ParamByName('flnatureza').AsInteger := pessoa.Natureza;
        FDQuery.Open;
        IdPessoa := FDQuery.Fields[0].AsLargeInt;
        FDQuery.SQL.Text := 'INSERT INTO endereco (idpessoa, dscep) VALUES (:idpessoa, :cep);';
        FDQuery.ParamByName('idpessoa').AsLargeInt := IdPessoa;
        FDQuery.ParamByName('cep').AsString := pessoa.Cep;
        FDQuery.ExecSQL;
        savedCounter := savedCounter + 1;
      end;
      Self.Commit;
      Result := TJSONObject.Create;
      Result.AddPair('registros', savedCounter);
      Result.AddPair('sucesso', true);
    except
      on E: Exception do
      begin
        Self.Rollback;
        Result := TJSONObject.Create;
        Result.AddPair('erro', E.Message);
        Result.AddPair('sucesso', False);
      end;
    end;
  finally
    FDQuery.Free;
  end;
end;

end.
