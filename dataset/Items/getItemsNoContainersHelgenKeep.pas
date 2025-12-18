unit ExportHelgenKeep01_Items;

var
  sl: TStringList;

function IsLootItemBase(base: IInterface): boolean;
var
  sig: string;
begin
  sig := Signature(base);
  Result :=
    (sig = 'WEAP') or
    (sig = 'ARMO') or
    (sig = 'AMMO') or
    (sig = 'MISC') or
    (sig = 'INGR') or
    (sig = 'ALCH') or
    (sig = 'BOOK');
end;

function Initialize: integer;
begin
  sl := TStringList.Create;
  sl.Add(
    'form_id,editor_id,refr_id,record_type,is_persistent,source_type'
  );
end;

function Process(e: IInterface): integer;
var
  cell, base: IInterface;
  editorID, recordType, baseFormID, refrFormID, isPersistent: string;
begin
  // Nur platzierte Referenzen
  if Signature(e) <> 'REFR' then
    exit;

  // Cell prüfen
  cell := LinksTo(ElementByPath(e, 'Cell'));
  if not Assigned(cell) then
    exit;

  if GetElementEditValues(cell, 'EDID') <> 'HelgenKeep01' then
    exit;

  // Base Object
  base := LinksTo(ElementByPath(e, 'NAME - Base'));
  if not Assigned(base) then
    exit;

  if not IsLootItemBase(base) then
    exit;

  // Base Object Daten (Item-Identität)
  editorID   := GetElementEditValues(base, 'EDID');
  recordType := Signature(base);
  baseFormID := IntToHex(FixedFormID(base), 8);

  // Referenz-Daten (Instanz)
  refrFormID := IntToHex(FixedFormID(e), 8);

  // Persistent?
  if GetElementNativeValues(e, 'Record Header\Record Flags\Persistent') = 1 then
    isPersistent := 'true'
  else
    isPersistent := 'false';

  sl.Add(Format('%s,%s,%s,%s,%s,PLACED', [
    baseFormID,
    editorID,
    refrFormID,
    recordType,
    isPersistent
  ]));
end;

function Finalize: integer;
begin
  sl.SaveToFile(ProgramPath + 'items_HelgenKeep01.csv');
  sl.Free;
  AddMessage('Item export finished: items_HelgenKeep01.csv');
end;

end.
