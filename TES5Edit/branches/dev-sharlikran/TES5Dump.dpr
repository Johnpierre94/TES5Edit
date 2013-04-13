{*******************************************************************************

     The contents of this file are subject to the Mozilla Public License
     Version 1.1 (the "License"); you may not use this file except in
     compliance with the License. You may obtain a copy of the License at
     http://www.mozilla.org/MPL/

     Software distributed under the License is distributed on an "AS IS"
     basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
     License for the specific language governing rights and limitations
     under the License.

*******************************************************************************}

// JCL_DEBUG_EXPERT_INSERTJDBG ON
// JCL_DEBUG_EXPERT_GENERATEJDBG ON
// JCL_DEBUG_EXPERT_DELETEMAPFILE ON

program TES5Dump;

{$I Compilers.inc}

{$APPTYPE CONSOLE}

uses
  Classes,
  SysUtils,
  Windows,
  System.Win.Registry,
  wbDefinitionsFNV in 'wbDefinitionsFNV.pas',
  wbDefinitionsFO3 in 'wbDefinitionsFO3.pas',
  wbDefinitionsTES3 in 'wbDefinitionsTES3.pas',
  wbDefinitionsTES4 in 'wbDefinitionsTES4.pas',
  wbDefinitionsTES5 in 'wbDefinitionsTES5.pas',
  wbDefinitionsTES5Saves in 'wbDefinitionsTES5Saves.pas',
  wbImplementation in 'wbImplementation.pas',
  wbInterface in 'wbInterface.pas',
  wbLocalization in 'wbLocalization.pas',
  wbBSA in 'wbBSA.pas',
  Zlibex in 'Zlibex.pas';

const
  IMAGE_FILE_LARGE_ADDRESS_AWARE = $0020;

{$SetPEFlags IMAGE_FILE_LARGE_ADDRESS_AWARE}

var
  StartTime    : TDateTime;
  DumpGroups   : TStringList;
  DumpChapters : TStringList;

procedure ReportProgress(const aStatus: string);
begin
  WriteLn(ErrOutput, FormatDateTime('<nn:ss.zzz>', Now - StartTime), ' ', aStatus);
end;

procedure WriteElement(aElement: IwbElement; aIndent: string = ''); forward;

procedure WriteContainer(aContainer: IwbContainer; aIndent: string = '');
var
  i            : Integer;
  GroupRecord  : IwbGroupRecord;
  ContainerRef : IwbContainerElementRef;
  SaveElement  : IwbSaveAddressable;
begin
  if (aContainer.ElementType = etGroupRecord) then
    if Supports(aContainer, IwbGroupRecord, GroupRecord) then
      if GroupRecord.GroupType = 0 then begin
        if Assigned(DumpGroups) and not DumpGroups.Find(String(TwbSignature(GroupRecord.GroupLabel)), i) then
          Exit;
        ReportProgress('Dumping: ' + GroupRecord.Name);
      end;
  if (wbGameMode in [gmTES5Saves]) and Assigned(DumpChapters) and Supports(aContainer, IwbSaveAddressable, SaveElement) then begin
    if not DumpChapters.Find(IntToStr(SaveElement.GetType), i) then
        Exit;
    ReportProgress('Dumping: ' + aContainer.Name);
  end;

  if aContainer.Skipped then begin
    if not wbReportMode then WriteLn(aIndent, '<contents skipped>');
  end else begin
    Supports(aContainer, IwbContainerElementRef, ContainerRef);
    for i := 0 to Pred(aContainer.ElementCount) do
      WriteElement(aContainer.Elements[i], aIndent);
  end;
end;

procedure WriteElement(aElement: IwbElement; aIndent: string = '');
var
  Container   : IwbContainer;
  Name        : string;
  Value       : string;

  i            : Integer;
  GroupRecord  : IwbGroupRecord;
begin
  if Assigned(DumpGroups) and (aElement.ElementType = etGroupRecord) then
    if Supports(aElement, IwbGroupRecord, GroupRecord) then
      if GroupRecord.GroupType = 0 then
        if not DumpGroups.Find(String(TwbSignature(GroupRecord.GroupLabel)), i) then
          Exit;

  Name := aElement.DisplayName;
  Value := aElement.Value;

  if (Name <> '') and not wbReportMode then
    Write(aIndent, Name);
  if (Name <> '') or (Value <> '') then
    aIndent := aIndent + '  ';
  if (Value <> '') and (Pos('Hidden: ', Name)<>1) then begin
    if not wbReportMode then
      WriteLn(': ', Value);
  end else begin
    if not wbReportMode then
      WriteLn;
  end;

  if Supports(aElement, IwbContainer, Container) and (Pos('Hidden: ', Name)<>1) then
    WriteContainer(Container, aIndent);
end;

{==============================================================================}
function CheckForErrors(const aIndent: Integer; const aElement: IwbElement): Boolean;
var
  Error                       : string;
  Container                   : IwbContainerElementRef;
  i                           : Integer;
begin
  Error := aElement.Check;
  Result := Error <> '';
  if Result then
    WriteLn(StringOfChar(' ', aIndent * 2) + aElement.Name, ' -> ', Error);

  if Supports(aElement, IwbContainerElementRef, Container) then
    for i := Pred(Container.ElementCount) downto 0 do
      Result := CheckForErrors(aIndent + 1, Container.Elements[i]) or Result;

  if Result and (Error = '') then
    WriteLn(StringOfChar(' ', aIndent * 2), 'Above errors were found in: ', aElement.Name);
end;
{==============================================================================}


{==============================================================================}
function wbFindCmdLineSwitch(const aSwitch: string): Boolean;
begin
  Result := FindCmdLineSwitch(aSwitch, ['-', '/'], True);
end;
{------------------------------------------------------------------------------}
function wbFindCmdLineParam(const aSwitch     : string;
                            const aChars      : TSysCharSet;
                                  aIgnoreCase : Boolean;
                              out aValue      : string)
                                              : Boolean; overload;
var
  i : Integer;
  s : string;
begin
  Result := False;
  aValue := '';
  for i := 1 to ParamCount do begin
    s := ParamStr(i);
    if (aChars = []) or (s[1] in aChars) then
      if aIgnoreCase then begin
        if AnsiCompareText(Copy(s, 2, Length(aSwitch)), aSwitch) = 0 then begin
          if (length(s)>(length(aSwitch)+2)) and (s[Length(aSwitch) + 2] = ':') then begin
            aValue := Copy(s, Length(aSwitch) + 3, MaxInt);
            Result := True;
          end;
          Exit;
        end;
      end else
        if AnsiCompareStr(Copy(s, 2, Length(aSwitch)), aSwitch) = 0 then begin
          if s[Length(aSwitch) + 2] = ':' then begin
            aValue := Copy(s, Length(aSwitch) + 3, MaxInt);
            Result := True;
          end;
          Exit;
        end;
  end;
end;
{------------------------------------------------------------------------------}
function wbFindCmdLineParam(const aSwitch : string;
                              out aValue  : string)
                                          : Boolean; overload;
begin
  Result := wbFindCmdLineParam(aSwitch, ['-', '/'], True, aValue);
end;
{==============================================================================}

function CheckAppPath: string;
const
  //gmFNV, gmFO3, gmTES3, gmTES4, gmTES5
  ExeName : array[TwbGameMode] of string =
    ('Fallout3.exe', 'FalloutNV.exe', 'Morrowind.exe', 'Oblivion.exe', 'TESV.exe', 'TESV.exe');
var
  s: string;
begin
  Result := '';
  s := ParamStr(0);
  s := ExtractFilePath(s);
  while Length(s) > 3 do begin
    if FileExists(s + ExeName[wbGameMode]) and DirectoryExists(s + 'Data') then begin
      Result := s;
      Exit;
    end;
    s := ExtractFilePath(ExcludeTrailingPathDelimiter(s));
  end;
end;

procedure DoInitPath;
const
  sBethRegKey             = '\SOFTWARE\Bethesda Softworks\';
  sBethRegKey64           = '\SOFTWARE\Wow6432Node\Bethesda Softworks\';
var
  ProgramPath  : String;
  DataPath     : String;
begin
  ProgramPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));

  if not wbFindCmdLineParam('D', DataPath) then begin
    DataPath := CheckAppPath;

    if DataPath = '' then with TRegistry.Create do try
      RootKey := HKEY_LOCAL_MACHINE;

      if not OpenKeyReadOnly(sBethRegKey + wbGameName + '\') then
        if not OpenKeyReadOnly(sBethRegKey64 + wbGameName + '\') then begin
          ReportProgress('Fatal: Could not open registry key: ' + sBethRegKey + wbGameName + '\');
          if wbGameMode = gmTES5 then
            ReportProgress('This can happen after Steam updates, run game''s launcher to restore registry settings');
          wbDontSave := True;
          Exit;
        end;

      DataPath := ReadString('Installed Path');

      if DataPath = '' then begin
        ReportProgress('Fatal: Could not determine '+wbGameName+' installation path, no "Installed Path" registry key');
        if wbGameMode = gmTES5 then
          ReportProgress('This can happen after Steam updates, run game''s launcher to restore registry settings');
        wbDontSave := True;
      end;
    finally
      Free;
    end;
    if DataPath <>'' then
      DataPath := IncludeTrailingPathDelimiter(DataPath) + 'Data\';
  end else
    DataPath := IncludeTrailingPathDelimiter(DataPath);

  wbDataPath := DataPath;
end;

var
  NeedsSyntaxInfo : Boolean;
  s, s2           : string;
  i               : integer;
  _File           : IwbFile;
  Masters         : TStringList;
  F               : TSearchRec;
begin
  {$IF CompilerVersion >= 24}
  FormatSettings.DecimalSeparator := '.';
  {$ELSE}
  SysUtils.DecimalSeparator := '.';
  {$IFEND}
  wbProgressCallback := ReportProgress;
  wbAllowInternalEdit := False;
  wbMoreInfoForUnknown := False;
  StartTime := Now;

  try
    if wbFindCmdLineSwitch('FNV') or SameText(Copy(ExtractFileName(ParamStr(0)), 1, 3), 'FNV') then begin
      wbGameMode := gmFNV;
      wbAppName := 'FNV';
      wbGameName := 'FalloutNV';
      wbLoadBSAs := wbFindCmdLineSwitch('bsa') or wbFindCmdLineSwitch('allbsa');
      DefineFNV;
    end else if wbFindCmdLineSwitch('FO3') or SameText(Copy(ExtractFileName(ParamStr(0)), 1, 3), 'FO3') then begin
      wbGameMode := gmFO3;
      wbAppName := 'FO3';
      wbGameName := 'Fallout3';
      wbLoadBSAs := wbFindCmdLineSwitch('bsa') or wbFindCmdLineSwitch('allbsa');
      DefineFO3;
    end else if wbFindCmdLineSwitch('TES3') or SameText(Copy(ExtractFileName(ParamStr(0)), 1, 4), 'TES3') then begin
      WriteLn(ErrOutput, 'TES3 - Morrowind is not supported yet.');
      Exit;
      wbGameMode := gmTES3;
      wbAppName := 'TES3';
      wbGameName := 'Morrowind';
      wbLoadBSAs := false;
      DefineTES3;
    end else if wbFindCmdLineSwitch('TES4') or SameText(Copy(ExtractFileName(ParamStr(0)), 1, 4), 'TES4') then begin
      wbGameMode := gmTES4;
      wbAppName := 'TES4';
      wbGameName := 'Oblivion';
      wbLoadBSAs := wbFindCmdLineSwitch('bsa') or wbFindCmdLineSwitch('allbsa');
      DefineTES4;
    end else if wbFindCmdLineSwitch('TES5Saves') or SameText(Copy(ExtractFileName(ParamStr(0)), 1, 9), 'TES5Saves') then begin
      wbGameMode := gmTES5Saves;
      wbAppName := 'TES5Saves';
      wbGameName := 'Skyrim Saves';
      wbLoadBSAs := false;
      DefineTES5saves;
    end else if wbFindCmdLineSwitch('TES5') or SameText(Copy(ExtractFileName(ParamStr(0)), 1, 4), 'TES5') then begin
      wbGameMode := gmTES5;
      wbAppName := 'TES5';
      wbGameName := 'Skyrim';
      wbLoadBSAs := true;
      DefineTES5;
    end else begin
      WriteLn(ErrOutput, 'Application name must start with FNV, FO3, TES4, TES5, TES5Saves to');
      WriteLn(ErrOutput, 'select mode.');
      Exit;
    end;

    DoInitPath;

    if not wbFindCmdLineSwitch('q') and not wbReportMode then begin
      WriteLn(ErrOutput, wbAppName, 'Dump ', VersionString);
      WriteLn(ErrOutput);

      WriteLn(ErrOutput, 'This Program is subject to the Mozilla Public License');
      WriteLn(ErrOutput, 'Version 1.1 (the "License"); you may not use this program except in');
      WriteLn(ErrOutput, 'compliance with the License. You may obtain a copy of the License at');
      WriteLn(ErrOutput, 'http://www.mozilla.org/MPL/');
      WriteLn(ErrOutput);
      WriteLn(ErrOutput, 'Software distributed under the License is distributed on an "AS IS"');
      WriteLn(ErrOutput, 'basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the');
      WriteLn(ErrOutput, 'License for the specific language governing rights and limitations');
      WriteLn(ErrOutput, 'under the License.');
      WriteLn(ErrOutput);
    end;

    if wbFindCmdLineParam('dg', s) then begin
      DumpGroups := TStringList.Create;
      DumpGroups.Sorted := True;
      DumpGroups.Duplicates := dupIgnore;
      DumpGroups.CommaText := s;
      DumpGroups.Sort;
    end;

    if wbFindCmdLineParam('dc', s) then begin
      DumpChapters := TStringList.Create;
      DumpChapters.Sorted := True;
      DumpChapters.Duplicates := dupIgnore;
      DumpChapters.CommaText := s;
      DumpChapters.Sort;
    end;

    wbLoadAllBSAs := wbFindCmdLineSwitch('allbsa');

    if wbFindCmdLineSwitch('more') then
      wbMoreInfoForUnknown:= True
    else
      wbMoreInfoForUnknown:= False;

    if wbFindCmdLineParam('xr', s) then
      RecordToSkip.CommaText := s;

    if wbFindCmdLineParam('xg', s) then
      GroupToSkip.CommaText := s
    else if wbFindCmdLineSwitch('xbloat') then begin
      GroupToSkip.Add('LAND');
      GroupToSkip.Add('REGN');
      GroupToSkip.Add('PGRD');
      GroupToSkip.Add('SCEN');
      GroupToSkip.Add('PACK');
      GroupToSkip.Add('PERK');
      GroupToSkip.Add('NAVI');
      GroupToSkip.Add('CELL');
      GroupToSkip.Add('WRLD');
    end;

    if wbFindCmdLineParam('xc', s) then
      ChaptersToSkip.CommaText := s
    else if wbFindCmdLineSwitch('xcbloat') then begin
      ChaptersToSkip.Add('Papyrus Struct');
    end;

    if wbFindCmdLineParam('l', s) and ((wbGameMode = gmTES5) or (wbGameMode = gmTES5Saves)) then
      wbLanguage := s
    else
      wbLanguage := 'English';

    if wbFindCmdLineParam('bts', s) then
      BytesToSkip := StrToInt64Def(s, BytesToSkip);
    if wbFindCmdLineParam('btd', s) then
      BytesToDump := StrToInt64Def(s, BytesToDump);

    s := ParamStr(ParamCount);

    NeedsSyntaxInfo := False;
    if (ParamCount >= 1) and not FileExists(s) then begin
      if s[1] in ['-', '/'] then
        WriteLn(ErrOutput, 'No inputfile was specified. Please check the command line parameters.')
      else
        WriteLn(ErrOutput, 'Can''t find the file "',s,'". Please check the command line parameters.');
      WriteLn;
      NeedsSyntaxInfo := True;
    end;

    if NeedsSyntaxInfo or (ParamCount < 1) or wbFindCmdLineSwitch('?') or wbFindCmdLineSwitch('help') then begin
      WriteLn(ErrOutput, 'Syntax:  '+wbAppName+'Dump [options] inputfile');
      WriteLn(ErrOutput, '  or     '+wbAppName+'Saves [options] inputfile');
      WriteLn(ErrOutput);
      WriteLn(ErrOutput, wbAppName + 'Dump will load the specified esp/esm files and all it''s masters and will dump the decoded contents of the specified file to stdout. Masters are searched for in the same directory as the specified file.');
      WriteLn(ErrOutput);
      WriteLn(ErrOutput, 'You can use the normal redirect mechanism to send the output to a file.');
      WriteLn(ErrOutput, 'e.g. "'+wbAppName+'Dump '+wbGameName+'.esm > '+wbGameName+'.txt"');
      WriteLn(ErrOutput);
      WriteLn(ErrOutput, 'Currently supported options:');
      WriteLn(ErrOutput, '-? / -help   ', 'This help screen');
      WriteLn(ErrOutput, '-q           ', 'Suppress version message');
      WriteLn(ErrOutput, '-xr:list     ', 'Excludes the contents of specified records from being');
      WriteLn(ErrOutput, '             ', '  decompressed and processed.');
      WriteLn(ErrOutput, '-xg:list     ', 'Excludes complete top level groups from being processed');
      WriteLn(ErrOutput, '-xbloat      ', 'The following value applies:');
      WriteLn(ErrOutput, '             ', '  -xg:LAND, REGN, PGRD, SCEN, PACK, PERK, NAVI, CELL, WRLD');
      WriteLn(ErrOutput, '-dg:list     ', 'If specified, only dump the listed top level groups');
      WriteLn(ErrOutput, '-check       ', 'Performs "Check for Errors" instead of dumping content');
      WriteLn(ErrOutput, '-more        ', 'Displays aditional information on Unknowns');
      WriteLn(ErrOutput, '-l:language  ', 'Specifies language for localization files (TES5 only)');
      WriteLn(ErrOutput, '             ', '  Default language is English');
      WriteLn(ErrOutput, '-bsa         ', 'Loads default associated BSAs');
      WriteLn(ErrOutput, '             ', ' (plugin.bsa and plugin - interface.bsa)');
      WriteLn(ErrOutput, '-allbsa      ', 'Loads all associated BSAs (plugin*.bsa)');
      WriteLn(ErrOutput, '             ', '   useful if strings are in a non-standard BSA');
      WriteLn(ErrOutput, '-d:datapath  ', 'Path to the game plugins directory');
      WriteLn(ErrOutput, '             ', '');
      WriteLn(ErrOutput, 'Saves mode ONLY', ' not for general use');
      WriteLn(ErrOutput, '-bts         ', 'BytesToSkip  = number of undecoded bytes to skip, default = 0');
      WriteLn(ErrOutput, '-btd         ', 'BytesToDump  = number of undecoded bytes to dump as unknown, default = all');
      WriteLn(ErrOutput, '             ', '');
      WriteLn(ErrOutput, 'Example: full dump of Skyrim.esm excluding "bloated" records');
      WriteLn(ErrOutput, 'TES5Dump.exe -xr:NAVI,NAVM,WRLD,CELL,LAND,REFR,ACHR Skyrim.esm');
      WriteLn(ErrOutput, '             ', '');
      Exit;
    end;

    if not Assigned(wbContainerHandler) then
      wbContainerHandler := wbCreateContainerHandler;

    StartTime := Now;
    ReportProgress('['+s+'] Application name : '+wbAppName+' - '+wbGamename);
    if Assigned(Dumpgroups) then
      ReportProgress('['+s+']   Dumping groups : '+DumpGroups.CommaText);
    if Assigned(GroupToSkip) and (GroupToSkip.Count>0) then
      ReportProgress('['+s+']   Excluding groups : '+GroupToSkip.CommaText);
    if Assigned(ChaptersToSkip) and (ChaptersToSkip.Count>0) then
      ReportProgress('['+s+']   Excluding chapters : '+ChaptersToSkip.CommaText);
    if Assigned(RecordToSkip) and (RecordToSkip.Count>0) then
      ReportProgress('['+s+']   Excluding records : '+RecordToSkip.CommaText);

    if BytesToSkip>0 then
      ReportProgress('['+s+']   BytesToSkip : '+IntToStr(BytesToSkip));
    if BytesToDump<$FFFFFFFF then
      ReportProgress('['+s+']   BytesToDump : '+IntToStr(BytesToDump));

    if wbLoadBSAs then begin
      Masters := TStringList.Create;
      wbMastersForFile(s, Masters);
      Masters.Add(ExtractFileName(s));

      for i := 0 to Masters.Count - 1 do begin
        if wbLoadAllBSAs then begin
          if (ExtractFileExt(Masters[i]) = '.esp') or (wbGameMode in [gmFO3, gmFNV, gmTES5]) then begin
            s2 := ChangeFileExt(Masters[i], '');
            if FindFirst(wbDataPath + s2 + '*.bsa', faAnyFile, F) = 0 then try
              repeat
                ReportProgress('[' + F.Name + '] Loading Resources.');
                wbContainerHandler.AddBSA(wbDataPath + F.Name);
              until FindNext(F) <> 0;
            finally
              SysUtils.FindClose(F);
            end;
          end;
        end else begin
          if (ExtractFileExt(Masters[i]) = '.esp') or (wbGameMode in [gmFO3, gmFNV, gmTES5]) then begin
            s2 := ChangeFileExt(Masters[i], '');
            if FindFirst(wbDataPath + s2 + '.bsa', faAnyFile, F) = 0 then try
              repeat
                ReportProgress('[' + F.Name + '] Loading Resources.');
                wbContainerHandler.AddBSA(wbDataPath + F.Name);
              until FindNext(F) <> 0;
            finally
              SysUtils.FindClose(F);
            end;
            if FindFirst(wbDataPath + s2 + ' - Interface.bsa', faAnyFile, F) = 0 then try
              repeat
                ReportProgress('[' + F.Name + '] Loading Resources.');
                wbContainerHandler.AddBSA(wbDataPath + F.Name);
              until FindNext(F) <> 0;
            finally
              SysUtils.FindClose(F);
            end;
          end;
        end;
      end;
      FreeAndNil(Masters);
      ReportProgress('[' + wbDataPath + '] Setting Resource Path.');
      wbContainerHandler.AddFolder(wbDataPath);
    end;

    if Pos('SAVES', UpperCase(wbAppName))>0 then
      _File := wbSaveFile(s)
    else
      _File := wbFile(s);

    ReportProgress('Finished loading record. Starting Dump.');

    if wbFindCmdLineSwitch('check') and not wbReportMode then
      CheckForErrors(0, _File)
    else
      WriteContainer(_File);

    if wbReportMode then
      ReportDefs;

    ReportProgress('All Done.');
  except
    on e: Exception do
      ReportProgress('Unexpected Error: <'+e.ClassName+': '+e.Message+'>');
  end;
  if wbReportMode or (DebugHook <> 0) then
    ReadLn;
end.
