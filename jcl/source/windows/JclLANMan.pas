{******************************************************************************}
{                                                                              }
{ Project JEDI Code Library (JCL)                                              }
{                                                                              }
{ The contents of this file are subject to the Mozilla Public License Version  }
{ 1.1 (the "License"); you may not use this file except in compliance with the }
{ License. You may obtain a copy of the License at http://www.mozilla.org/MPL/ }
{                                                                              }
{ Software distributed under the License is distributed on an "AS IS" basis,   }
{ WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for }
{ the specific language governing rights and limitations under the License.    }
{                                                                              }
{ The Original Code is JclLANMan.pas.                                          }
{                                                                              }
{ The Initial Developer of the Original Code is documented in the accompanying }
{ help file JCL.chm. Portions created by these individuals are Copyright (C)   }
{ of these individuals.                                                        }
{                                                                              }
{******************************************************************************}
{                                                                              }
{ This unit contains routines and classes to handle user and group management  }
{ tasks. As the name implies, it uses the LAN Manager API.                     }
{                                                                              }
{ Unit owner: Peter Friese                                                     }
{ Last modified: May 07, 2001                                                  }
{                                                                              }
{******************************************************************************}

unit JclLANMan;

{$I JCL.INC}

interface

uses
  Windows;

//------------------------------------------------------------------------------
// User Management
//------------------------------------------------------------------------------

type
  TNetUserFlag = (ufAccountDisable, ufHomedirRequired, ufLockout,
    ufPasswordNotRequired, ufPasswordCantChange, ufDontExpirePassword,
    ufMNSLogonAccount);
  TNetUserFlags = set of TNetUserFlag;
  TNetUserInfoFlag = (uifScript, uifTempDuplicateAccount, uifNormalAccount,
    uifInterdomainTrustAccount, uifWorkstationTrustAccount, uifServerTrustAccount);
  TNetUserInfoFlags = set of TNetUserInfoFlag;
  TNetUserPriv = (upUnknown, upGuest, upUser, upAdmin);
  TNetUserAuthFlag = (afOpPrint, afOpComm, afOpServer, afOpAccounts);
  TNetUserAuthFlags = set of TNetUserAuthFlag;
  TNetWellKnownRID = (wkrAdmins, wkrUsers, wkrGuests, wkrPowerUsers, wkrBackupOPs,
    wkrReplicator, wkrEveryone);

function CreateAccount(const Server, Username, Password, Description, Homedir, Script: string): Boolean;
function CreateLocalAccount(const Username, Password, Description, Homedir, Script: string): Boolean;
function DeleteAccount(const Servername, Username: string): Boolean;
function DeleteLocalAccount(Username: string): Boolean;
function CreateLocalGroup(const Server, Groupname, Description: string): Boolean;
function CreateGlobalGroup(const Server, Groupname, Description: string): Boolean;
function DeleteLocalGroup(const Server, Groupname: string): Boolean;
function AddAccountToLocalGroup(const Accountname, Groupname: string): Boolean;
function LookupGroupName(const Server: string; const RID: TNetWellKnownRID): string;

function GetFileOwner(FileName: string; var Domain, Username: string): Boolean;

implementation

uses
  SysUtils, LM, JclStrings, JclWin32;

//------------------------------------------------------------------------------
// User Management
//------------------------------------------------------------------------------

function CreateAccount(const Server, Username, Password, Description, Homedir, Script: string): boolean;
var
  wServer, wUsername, wPassword, wDescription, wHomedir, wScript: WideString;
  details: USER_INFO_1;
  err: NET_API_STATUS;
  parmErr: DWORD;
begin
  wServer := Server;
  wUsername := Username;
  wPassword := Password;
  wDescription := Description;
  wScript := Script;
  wHomedir := Homedir;

  FillChar (details, sizeof(details), 0);
  with details do
  begin
    usri1_name := PWideChar(wUsername);
    usri1_password := PWideChar(wPassword);
    usri1_comment := PWideChar(wDescription);
    usri1_priv := USER_PRIV_USER;
    usri1_flags := UF_SCRIPT;
    usri1_script_path := PWideChar(wScript);
    usri1_home_dir := PWideChar(wHomedir);
  end;

  err := NetUserAdd (PWideChar(wServer), 1, @details, @parmErr);
  Result := (err = NERR_SUCCESS);

  // callers should call RaiseLastWin32Error to get detailed error information
  // if err <> NERR_Success then
  //  raise ENTException.Create (err)
  //else
  //  Result := true;
end;

//------------------------------------------------------------------------------

function CreateLocalAccount(const Username, Password, Description, Homedir, Script: string): boolean;
begin
  Result := CreateAccount('', Username, Password, Description, Homedir, Script);
end;

//------------------------------------------------------------------------------

function DeleteAccount(const Servername, Username: string): Boolean;
var
  wServername, wUsername: WideString;
begin
  Result := false;
  wServername := Servername;
  wUsername := Username;
  if NetUserDel(PWideChar(wServername), PWideChar(wUsername)) = NERR_Success then
    Result := true
  else
    RaiseLastWin32Error;
end;

//------------------------------------------------------------------------------

function DeleteLocalAccount(Username: string): Boolean;
begin
  Result := DeleteAccount('', Username);
end;

//------------------------------------------------------------------------------

function CreateGlobalGroup(const Server, Groupname, Description: string): boolean;
var
  wServer, wGroupname, wDescription: WideString;
  details: GROUP_INFO_1;
  err: NET_API_STATUS;
  parmErr: DWORD;
begin
  wServer := Server;
  wGroupname := Groupname;
  wDescription := Description;

  FillChar (details, sizeof(details), 0);
  details.grpi1_name := PWideChar(wGroupName);
  details.grpi1_comment := PWideChar(wDescription);

  err := NetGroupAdd(PWideChar(wServer), 1, @details, @parmErr);
  Result := (err = NERR_SUCCESS);
end;

//------------------------------------------------------------------------------

function CreateLocalGroup(const Server, Groupname, Description: string): boolean;
var
  wServer, wGroupname, wDescription: WideString;
  details: LOCALGROUP_INFO_1;
  err: NET_API_STATUS;
  parmErr: DWORD;
begin
  wServer := Server;
  wGroupname := Groupname;
  wDescription := Description;

  FillChar (details, sizeof(details), 0);
  details.lgrpi1_name := PWideChar(wGroupName);
  details.lgrpi1_comment := PWideChar(wDescription);

  err := NetLocalGroupAdd(PWideChar(wServer), 1, @details, @parmErr);
  Result := (err = NERR_SUCCESS);
end;

//------------------------------------------------------------------------------

function DeleteLocalGroup(const Server, Groupname: string): Boolean;
var
  wServername, wUsername: WideString;
begin
  Result := false;
  wServername := Server;
  wUsername := Groupname;
  if NetLocalGroupDel(PWideChar(wServername), PWideChar(wUsername)) = NERR_Success then
    Result := true
  else
    RaiseLastWin32Error;
end;

//------------------------------------------------------------------------------

function DeleteGlobalGroup(const Server, Groupname: string): Boolean;
var
  wServername, wUsername: WideString;
begin
  Result := false;
  wServername := Server;
  wUsername := Groupname;
  if NetGroupDel(PWideChar(wServername), PWideChar(wUsername)) = NERR_Success then
    Result := true
  else
    RaiseLastWin32Error;
end;

//------------------------------------------------------------------------------

function AddAccountToLocalGroup(const Accountname, Groupname: string): boolean;
var
  err: NET_API_STATUS;
  wAccountname, wGroupname: WideString;
  details: LOCALGROUP_MEMBERS_INFO_3;
begin
  wGroupname := Groupname;
  wAccountname := AccountName;

  details.lgrmi3_domainandname := PWideChar(wAccountname);
  err := NetLocalGroupAddMembers(nil, PWideChar(wGroupname), 3, @details, 1);
  Result := (err = NERR_SUCCESS);
end;

//------------------------------------------------------------------------------

function RIDToDWORD(const RID: TNetWellKnownRID): DWORD;
begin
  case RID of
    wkrAdmins: Result := DOMAIN_ALIAS_RID_ADMINS;
    wkrUsers: Result := DOMAIN_ALIAS_RID_USERS;
    wkrGuests: Result := DOMAIN_ALIAS_RID_GUESTS;
    wkrPowerUsers: Result := DOMAIN_ALIAS_RID_POWER_USERS;
    wkrBackupOPs: Result := DOMAIN_ALIAS_RID_BACKUP_OPS;
    wkrReplicator: Result := DOMAIN_ALIAS_RID_REPLICATOR;
    wkrEveryone: Result := SECURITY_WORLD_RID;
  end;
end;

//------------------------------------------------------------------------------

function DWORDToRID(const RID: DWORD): TNetWellKnownRID;
begin
  case RID of
    DOMAIN_ALIAS_RID_ADMINS: Result := wkrAdmins;
    DOMAIN_ALIAS_RID_USERS: Result := wkrUsers;
    DOMAIN_ALIAS_RID_GUESTS: Result := wkrGuests;
    DOMAIN_ALIAS_RID_POWER_USERS: Result := wkrPowerUsers;
    DOMAIN_ALIAS_RID_BACKUP_OPS: Result := wkrBackupOPs;
    DOMAIN_ALIAS_RID_REPLICATOR: Result := wkrReplicator;
    SECURITY_WORLD_RID: Result := wkrEveryone;
  end;
end;

//------------------------------------------------------------------------------

function LookupGroupName(const Server: string; const RID: TNetWellKnownRID): string;
var
  sia: SID_IDENTIFIER_AUTHORITY;
  rd1, rd2: DWORD;
  ridCOunt: integer;
  sd: PSID;
  AccountNameLen, DomainNameLen: DWORD;
  SidNameUse: SID_NAME_USE;
begin
  Result := '';
  if RID = wkrEveryOne then
  begin
    sia := SECURITY_WORLD_SID_AUTHORITY;
    rd1 := RIDToDWORD(RID);
    ridCount := 1;
  end
  else
  begin
    sia := SECURITY_NT_AUTHORITY;
    rd1 := SECURITY_BUILTIN_DOMAIN_RID;
    rd2 := RIDToDWORD(RID);
    ridCount := 2;
  end;
  if AllocateAndInitializeSid(sia, ridCount, rd1, rd2, 0, 0, 0, 0, 0, 0, sd) then
  try
    AccountNameLen := 0;
    DomainNameLen := 0;
    if not LookupAccountSID(PChar(Server), sd, PChar(Result), AccountNameLen,
                            nil, DomainNameLen, SidNameUse)
    then
      SetLength(Result, AccountNamelen);

    if LookupAccountSID(PChar(Server), sd, PChar(Result), AccountNameLen,
                        nil, DomainNameLen, sidNameUse)
    then
      StrResetLength(Result)
    else
      RaiseLastWin32Error;
  finally
    FreeSID(sd);
  end;
end;

//------------------------------------------------------------------------------

(* incomplete. see MSDN Knowledegbase article ID Q157234 for full C source
function LookupAccountNameFromRID(const Server: string; const RID: TNetWellKnownRID): string;
var
  wServer: WideString;
  UserModalsInfo: Pointer;
  SubAuthorityCount: UCHAR;
  sd: PSID;
begin
  wServer := Server;
  if NetUserModalsGet(PWideChar(wServer), 2, UserModalsInfo) <> NERR_SUCCESS then
    RaiseLastWin32Error
  else
  begin
    SubAuthorityCount := GetSidSubAuthorityCount(PUserModalsInfo2(UserModalsInfo)^.usrmod2_domain_id)^;
  end;
end;
*)

//------------------------------------------------------------------------------

function GetFileOwner(FileName: string;
   var Domain, Username: string): Boolean;
var
   SecDescr: PSecurityDescriptor;
   SizeNeeded, SizeNeeded2: DWORD;
   OwnerSID: PSID;
   OwnerDefault: BOOL;
   OwnerName, DomainName: PChar;
   OwnerType: SID_NAME_USE;
begin
   GetFileOwner := False;
   GetMem(SecDescr,1024);
   GetMem(OwnerSID,SizeOf(PSID));
   GetMem(OwnerName,1024);
   GetMem(DomainName,1024);
   try
      if not GetFileSecurity(PChar(FileName), OWNER_SECURITY_INFORMATION,
                             SecDescr,1024,SizeNeeded) then
	      exit;
      if not GetSecurityDescriptorOwner(SecDescr, OwnerSID,OwnerDefault) then
        exit;
      SizeNeeded := 1024;
      SizeNeeded2 := 1024;
      if not LookupAccountSID(nil,OwnerSID,OwnerName, SizeNeeded,
                              DomainName,SizeNeeded2,OwnerType) then
	      exit;
      Domain := DomainName;
      Username := OwnerName;
   finally
      FreeMem(SecDescr);
      FreeMem(OwnerName);
      FreeMem(DomainName);
   end;
   GetFileOwner := True;
end;


end.


