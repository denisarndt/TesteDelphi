unit untSrvMetodosGerais;

interface

uses System.SysUtils, System.Classes, System.Json,
  System.DateUtils, FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool,
  FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.PG, FireDAC.Phys.PGDef,
  FireDAC.DApt, FireDAC.VCLUI.Wait, FireDAC.Comp.UI, FireDAC.Stan.StorageJSON,
  FireDAC.Stan.StorageBin, Data.DB, FireDAC.Comp.Client, uData, System.Generics.Collections;

type
{$METHODINFO ON}
  TsrvMetodosGerais = class(TDataModule)
    FDStanStorageBinLink1: TFDStanStorageBinLink;
    FDStanStorageJSONLink1: TFDStanStorageJSONLink;
    procedure DataModuleCreate(Sender: TObject);
  private
    { Private declarations }
    FDatabase: TMyDatabase;

  public
    { Public declarations }
    function InsertPessoa(const APessoa: TJSONObject): TJSONObject;
    function DeletePessoa(const APessoa: TJSONObject): TJSONObject;
    function UpdatePessoa(const APessoa: TJSONObject): TJSONObject;
    function InsertPessoas(const Apessoas: TJSONObject): TJSONObject;
  end;
{$METHODINFO OFF}

implementation

{$R *.dfm}

uses System.StrUtils, uPessoa, uEndereco;

procedure TsrvMetodosGerais.DataModuleCreate(Sender: TObject);
begin
  FDatabase := TMyDatabase.Create(nil);
end;

function TsrvMetodosGerais.InsertPessoa(const APessoa: TJSONObject): TJSONObject;
//Exemplo de JSON de insersao de pessoa
//{
//  "natureza":2,
//  "documento": "0002",
//  "primeiro_nome": "Vera",
//  "segundo_nome": "Lucia",
//  "cep": "65036-351"
//}
var
  pessoa: TPessoa;
  j: TJSONObject;
begin
  try
    pessoa := TPessoa.Create(APessoa);
    result := FDatabase.SalvarPessoa(pessoa);
  except
    on E: Exception do
    begin
      j := TJSONObject.Create();
      j.AddPair('exception', E.Message);
      result := j;
    end;
  end;
end;

function TsrvMetodosGerais.DeletePessoa(const APessoa: TJSONObject): TJSONObject;
//Exemplo de JSON de delecao de pessoa
//{
//  "idpessoa": 41
//}
var
  pessoa: TPessoa;
  j: TJSONObject;
begin
  try
    pessoa := TPessoa.Create(APessoa);
    result := FDatabase.DeletarPessoa(pessoa);
  except
    on E: Exception do
    begin
      j := TJSONObject.Create();
      j.AddPair('exception', E.Message);
      result := j;
    end;
  end;
end;

function TsrvMetodosGerais.InsertPessoas(const Apessoas: TJSONObject): TJSONObject;
//Exemplo de JSON de salvamento em lote:
//{
//  "pessoas": [
//    {
//      "pessoa": {
//        "id": 1,
//        "nome": "Carlos",
//        "sobrenome": "Santos",
//        "documento": "11122233344",
//        "data_registro": "2023-05-10",
//        "natureza": 5,
//        "cep": "01001-000"
//      }
//    },
//    {
//      "pessoa": {
//        "id": 2,
//        "nome": "Ana",
//        "sobrenome": "Pereira",
//        "documento": "55566677788",
//        "data_registro": "2022-11-25",
//        "natureza": 12,
//        "cep": "20040-010"
//      }
//    },
//    {
//      "pessoa": {
//        "id": 3,
//        "nome": "Luiz",
//        "sobrenome": "Moraes",
//        "documento": "99988877766",
//        "data_registro": "2024-01-15",
//        "natureza": 8,
//        "cep": "30110-010"
//      }
//    }
//  ]
//}
var
  p: TPessoa;
  ListaPessoas: TList<TPessoa>;
  j: TJSONObject;
begin
  try
    p := TPessoa.Create;
    ListaPessoas := p.ToJSONList(Apessoas);
    result := FDatabase.SalvarLote(ListaPessoas);
  except
    on E: Exception do
    begin
      j := TJSONObject.Create();
      j.AddPair('exception', E.Message);
      result := j;
    end;
  end;
end;

function TsrvMetodosGerais.UpdatePessoa(const APessoa: TJSONObject): TJSONObject;
//Exemplo de JSON de update de pessoa
//{
//  "idpessoa":37,
//  "natureza":1,
//  "documento": "0001",
//  "primeiro_nome": "Luiz",
//  "segundo_nome": "Carlos",
//  "cep": "96020-550"
//}
var
  pessoa, pessoa2: TPessoa;
  endereco: TEndereco;

  j: TJSONObject;
begin
  try
    pessoa := TPessoa.Create(APessoa);
    endereco := FDatabase.ConsultarEnderecoPorPessoa(pessoa.IdPessoa);
    // se a pessoa a ser alterada tenha cep diferente do anterior
    if pessoa.Cep <> endereco.Cep then
    begin
      endereco.Cep := pessoa.Cep;
      // altera a tabela de endereco para o novo cep
      FDatabase.AlterarEndereco(endereco);
      // deleta o endereco lido da via api para ser atualizado posteriormente pela thread
      FDatabase.DeletarEnderecoIntegracao(endereco.IdEndereco);
    end;
    // altera demais dados da pessoa
    pessoa2 := TPessoa.Create(APessoa);
    result := FDatabase.AlterarPessoa(pessoa2);
  except
    on E: Exception do
    begin
      j := TJSONObject.Create();
      j.AddPair('exception', E.Message);
      result := j;
    end;
  end;
end;

end.
