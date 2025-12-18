unit ExportHelgenKeep01_Items;

var
  slItems: TStringList;
  slBase: TStringList;
  baseSeen: TStringList;

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
  slItems := TStringList.Create;
  slBase  := TStringList.Create;
  baseSeen := TStringList.Create;

  baseSeen.Sorted := true;
  baseSeen.Duplicates := dupIgnore;

  // items.csv
  slItems.Add(
    'form_id,editor_id,refr_id,record_type,is_persistent,source_type'
  );

  // items_base.csv
  slBase.Add(
    'form_id,editor_id,weight,value'
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

  // Base Object Daten
  editorID   := GetElementEditValues(base, 'EDID');
  recordType := Signature(base);
  baseFormID := IntToHex(FixedFormID(base), 8);

  // Referenzdaten
  refrFormID := IntToHex(FixedFormID(e), 8);

  if GetElementNativeValues(e, 'Record Header\Record Flags\Persistent') = 1 then
    isPersistent := 'true'
  else
    isPersistent := 'false';

  // ---- items.csv (Instanzen) ----
  slItems.Add(Format('%s,%s,%s,%s,%s,PLACED', [
    baseFormID,
    editorID,
    refrFormID,
    recordType,
    isPersistent
  ]));

  // ---- items_base.csv (Typen, einmalig) ----
  if baseSeen.IndexOf(baseFormID) = -1 then begin
    baseSeen.Add(baseFormID);
    slBase.Add(Format('%s,%s,,', [
      baseFormID,
      editorID
    ]));
  end;
end;

function Finalize: integer;
begin
  slItems.SaveToFile(ProgramPath + 'items_HelgenKeep01.csv');
  slBase.SaveToFile(ProgramPath + 'items_base_HelgenKeep01.csv');

  slItems.Free;
  slBase.Free;
  baseSeen.Free;

  AddMessage('Item export finished: items_HelgenKeep01.csv');
  AddMessage('Base item export finished: items_base_HelgenKeep01.csv');
end;

end.
