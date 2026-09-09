; Wispie Windows installer (Inno Setup 6).
; Build first: flutter build windows --release
; Compile: iscc /DMyAppVersion=<version> windows\packaging\wispie.iss
#ifndef MyAppVersion
  #define MyAppVersion "1.3.3"
#endif

[Setup]
AppId={{268D1B56-28AC-416D-83CA-114929289DF4}
AppName=Wispie
AppVersion={#MyAppVersion}
AppPublisher=sillygru
DefaultDirName={autopf}\Wispie
DefaultGroupName=Wispie
OutputDir=..\..\build\windows-installer
OutputBaseFilename=Wispie-Setup-x64
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\wispie.exe

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Wispie"; Filename: "{app}\wispie.exe"
Name: "{autodesktop}\Wispie"; Filename: "{app}\wispie.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; Flags: unchecked

[Run]
Filename: "{app}\wispie.exe"; Description: "Launch Wispie"; Flags: nowait postinstall skipifsilent
