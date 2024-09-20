program servidor;
{$APPTYPE GUI}

{$R *.dres}

uses
  Vcl.Forms,
  Web.WebReq,
  IdHTTPWebBrokerBridge,
  untMain in 'untMain.pas' {fMain},
  untSrvMetodosGerais in 'untSrvMetodosGerais.pas' {srvMetodosGerais: TDataModule},
  untWM in 'untWM.pas' {WM: TWebModule},
  uPessoa in 'uPessoa.pas',
  uScanTableThread in 'uScanTableThread.pas',
  uData in 'uData.pas',
  uEndereco in 'uEndereco.pas';

{$R *.res}

begin
  if WebRequestHandler <> nil then
    WebRequestHandler.WebModuleClass := WebModuleClass;
  Application.Initialize;
  Application.CreateForm(TfMain, fMain);
  Application.Run;
end.
