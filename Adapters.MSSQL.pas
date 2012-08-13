(*
* Copyright (c) 2012, Linas Naginionis
* Contacts: lnaginionis@gmail.com or support@soundvibe.net
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * Neither the name of the <organization> nor the
*       names of its contributors may be used to endorse or promote products
*       derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*)
unit Adapters.MSSQL;

interface

{$IFDEF MSWINDOWS}

uses
  Adapters.ADO, SysUtils, Mapping.Attributes;

{
  Must use OLEDB povider because ODBC providers are buggy with SQL SERVER
  see: http://stackoverflow.com/questions/4877576/how-to-make-ado-parameter-to-update-sql-server-datetime-column

  Connection string example: 'Provider=SQLOLEDB.1;Password=master;Persist Security Info=True;'+
    'User ID=VIKARINA;Initial Catalog=ViktorDemo;Data Source=FILE_SERVER';


}

type
  TMSSQLResultsetAdapter = class(TADOResultSetAdapter);

  TMSSQLStatementAdapter = class(TADOStatementAdapter);

  TMSSQLConnectionAdapter = class(TADOConnectionAdapter)
  public
    function GetDriverName: string; override;
  end;

  TMSSQLTransactionAdapter = class(TADOTransactionAdapter);

  TMSSQLServerSQLGenerator = class(TADOSQLGenerator)
  public
    function GetDriverName(): string; override;
    function GenerateGetLastInsertId(AIdentityColumn: Column): string; override;
    function GeneratePagedQuery(const ASql: string; const ALimit, AOffset: Integer): string; override;
  end;

  EMSSQLStatementAdapterException = Exception;

{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

uses
  SQL.Register
  ,StrUtils
  ;

{ TMSSQLServerSQLGenerator }

function TMSSQLServerSQLGenerator.GenerateGetLastInsertId(AIdentityColumn: Column): string;
begin
  Result := 'SELECT SCOPE_IDENTITY();';
end;

function TMSSQLServerSQLGenerator.GeneratePagedQuery(const ASql: string; const ALimit,
  AOffset: Integer): string;
var
  LBuilder: TStringBuilder;
  LSQL: string;
begin
  LBuilder := TStringBuilder.Create;
  LSQL := ASql;
  try
    if EndsStr(';', LSQL) then
      SetLength(LSQL, Length(LSQL)-1);

    LBuilder.Append('SELECT * FROM (')
      .AppendLine
      .Append('  SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS ORM_ROW_NUM FROM (')
      .AppendLine.Append('    ')
      .Append(LSQL)
      .Append(') AS ORM_TOTAL_1')
      .AppendLine
      .Append('  ) AS ORM_TOTAL_2')
      .AppendLine
      .AppendFormat(' WHERE (ORM_ROW_NUM>=%0:D) AND (ORM_ROW_NUM < %0:D+%1:D);', [AOffset, ALimit]);

    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function TMSSQLServerSQLGenerator.GetDriverName: string;
begin
  Result := 'MSSQL';
end;

{ TMSSQLConnectionAdapter }

function TMSSQLConnectionAdapter.GetDriverName: string;
begin
  Result := 'MSSQL';
end;

initialization
  TSQLGeneratorRegister.RegisterGenerator(TMSSQLServerSQLGenerator.Create());

{$ENDIF}

end.
