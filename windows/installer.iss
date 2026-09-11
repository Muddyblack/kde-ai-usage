; Windows installer for the AI Usage tray app (Inno Setup 6).
;
; Built by windows/build-installer.ps1 from PyInstaller's "dist\AI Usage" folder
; (windows/ai-usage.spec) — on every push by .github/workflows/windows.yml, and
; attached to each release by release.yml.
;
; Per user: no admin rights, installed to %LOCALAPPDATA%\Programs\AI Usage.
; Settings and history live in %APPDATA% / %LOCALAPPDATA%\ai-usage-widget and
; survive updates and uninstalls alike.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Never change the AppId: it is how Windows knows a new version is the same app
; and updates it in place.
AppId={{DA55F997-6C64-4B6F-92EB-D3BEB6885B68}
AppName=AI Usage
AppVersion={#AppVersion}
AppVerName=AI Usage {#AppVersion}
AppPublisher=Muddyblack
AppPublisherURL=https://github.com/Muddyblack/kde-ai-usage
AppSupportURL=https://github.com/Muddyblack/kde-ai-usage/issues
DefaultDirName={autopf}\AI Usage
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..
OutputBaseFilename=AI-Usage-Setup-{#AppVersion}
SetupIconFile=..\dist\ai-usage.ico
UninstallDisplayIcon={app}\AI Usage.exe
UninstallDisplayName=AI Usage
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; The running app is stopped in [Code] instead of by the Restart Manager, which
; would ask the user about a tray app with no window to close.
CloseApplications=no

[Tasks]
Name: "autostart"; Description: "Start AI Usage when I sign in"
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\dist\AI Usage\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; An update replaces the whole bundle: files a new PyInstaller build no longer
; has must not linger next to the ones it does.
Type: filesandordirs; Name: "{app}\_internal"

[Icons]
Name: "{autoprograms}\AI Usage"; Filename: "{app}\AI Usage.exe"
Name: "{autodesktop}\AI Usage"; Filename: "{app}\AI Usage.exe"; Tasks: desktopicon

[Registry]
; The same value the app's own "Start with Windows" switch writes (app.py,
; set_autostart), so the two stay one setting.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "AI Usage"; ValueData: """{app}\AI Usage.exe"""; Tasks: autostart
; Removed on uninstall whichever of the two turned it on.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "AI Usage"; Flags: uninsdeletevalue

[Run]
Filename: "{app}\AI Usage.exe"; Description: "{cm:LaunchProgram,AI Usage}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM ""AI Usage.exe"""; Flags: runhidden; RunOnceId: "StopAIUsage"

[Code]
// Stop a running copy before its files are replaced.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM "AI Usage.exe"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := '';
end;
