unit ExportHelgenKeepLootToCSV;

var
  sl: TStringList;

function IsTargetCell(const cellName: string): boolean;
begin
  Result := (cellName = 'HelgenKeep');
end;

function IsLootBase(e: IInterface): boolean;
var
  sig: string;
begin
  sig := Signature(e);
  Result :=
    (sig = 'WEAP') or
    (sig = 'ARMO') or
    (sig = 'AMMO') or
    (sig = 'MISC') or
    (sig = 'INGR') or
    (sig = 'ALCH') or
    (sig = 'BOOK') or
    (sig = 'CONT') or
    (sig = 'NPC_');
end;

function Initialize: integer;
begin
  sl := TStringList.Create;
  sl.Add(
    'Cell,RefFormID,RefEditorID,BaseEditorID,BaseType,ItemType,FixOrRNG'
  );
end;

function Process(e: IInterface): integer;
var
  cell, base, inv, entry, itemBase: IInterface;
  cellName, refEDID, baseEDID, baseType, itemType, fixrng: string;
  i: integer;
begin
  // Nur platzierte Referenzen
  if Signature(e) <> 'REFR' then
    exit;

  // Cell bestimmen
  cell := LinksTo(ElementByPath(e, 'Cell'));
  if not Assigned(cell) then
    exit;

  cellName := GetElementEditValues(cell, 'EDID');
  if not IsTargetCell(cellName) then
    exit;

  // Base Object
  base := LinksTo(ElementByPath(e, 'NAME - Base'));
  if not Assigned(base) then
    exit;

  baseType := Signature(base);
  if not IsLootBase(base) then
    exit;

  refEDID := GetElementEditValues(e, 'EDID');
  baseEDID := GetElementEditValues(base, 'EDID');

  // Container oder NPC ? Inventar analysieren
  if (baseType = 'CONT') or (baseType = 'NPC_') then begin
    inv := ElementByPath(base, 'Items');
    if Assigned(inv) then begin
      for i := 0 to ElementCount(inv) - 1 do begin
        entry := ElementByIndex(inv, i);
        itemBase := LinksTo(ElementByPath(entry, 'Item'));
        if not Assigned(itemBase) then
          continue;

        itemType := Signature(itemBase);
        if itemType = 'LVLI' then
          fixrng := 'RNG'
        else
          fixrng := 'FIX';

        sl.Add(Format('%s,%s,%s,%s,%s,%s,%s', [
          cellName,
          IntToHex(FixedFormID(e), 8),
          refEDID,
          baseEDID,
          baseType,
          itemType,
          fixrng
        ]));
      end;
    end;
  end
  else begin
    // Direkt platzierte Items (Waffen, Rüstung etc.)
    sl.Add(Format('%s,%s,%s,%s,%s,%s,FIX', [
      cellName,
      IntToHex(FixedFormID(e), 8),
      refEDID,
      baseEDID,
      baseType,
      baseType
    ]));
  end;
end;

function Finalize: integer;
begin
  sl.SaveToFile(ProgramPath + 'HelgenKeep_Loot_Export.csv');
  sl.Free;
  AddMessage('Export finished: HelgenKeep_Loot_Export.csv');
end;

end.
