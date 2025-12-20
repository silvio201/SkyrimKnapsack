unit ExportHelgenKeep01_ActorsAndContents;

var
  slActors: TStringList;
  slContents: TStringList;
  seenBase: TStringList;

{ ================= INIT ================= }

function Initialize: integer;
begin
  slActors := TStringList.Create;
  slContents := TStringList.Create;
  seenBase := TStringList.Create;

  seenBase.Sorted := true;
  seenBase.Duplicates := dupIgnore;

  slActors.Add(
    'actor_refr_id,actor_base_form_id,actor_editor_id,is_persistent'
  );

  slContents.Add(
    'actor_base_form_id,actor_editor_id,item_form_id,item_editor_id,source_type,count'
  );
end;

{ ================= FILTER ================= }

function IsExcludedActor(base: IInterface): boolean;
var
  edid: string;
begin
  Result := false;
  edid := GetElementEditValues(base, 'EDID');
  if edid = '' then exit;

  // Banditen (Encounter / späterer Spawn)
  if Pos('LvlBandit', edid) = 1 then begin
    Result := true;
    exit;
  end;

  // Tiere (Encounter / späterer Spawn)
  if Pos('LvlAnimal', edid) = 1 then begin
    Result := true;
    exit;
  end;
end;

{ ================= EXPORT INVENTORY ================= }

procedure ExportActorContents(base: IInterface);
var
  items, entry, itemRef: IInterface;
  i, count: integer;
  baseFormID, baseEditorID: string;
  itemFormID, itemEditorID, sourceType: string;
begin
  baseFormID := IntToHex(FixedFormID(base), 8);
  baseEditorID := GetElementEditValues(base, 'EDID');

  items := ElementByPath(base, 'Items');
  if not Assigned(items) then
    exit;

  for i := 0 to ElementCount(items) - 1 do begin
    entry := ElementByIndex(items, i);
    itemRef := LinksTo(ElementByPath(entry, 'Item'));
    if not Assigned(itemRef) then
      continue;

    count := GetElementNativeValues(entry, 'Count');
    itemFormID := IntToHex(FixedFormID(itemRef), 8);
    itemEditorID := GetElementEditValues(itemRef, 'EDID');

    if Signature(itemRef) = 'LVLI' then
      sourceType := 'LVLI'
    else
      sourceType := 'FIXED';

    slContents.Add(Format('%s,%s,%s,%s,%s,%d', [
      baseFormID,
      baseEditorID,
      itemFormID,
      itemEditorID,
      sourceType,
      count
    ]));
  end;
end;

{ ================= PROCESS ================= }

function Process(e: IInterface): integer;
var
  cell, base: IInterface;
  refrID, baseFormID, baseEditorID: string;
  isPersistent: string;
begin
  if Signature(e) <> 'ACHR' then
    exit;

  cell := LinksTo(ElementByPath(e, 'Cell'));
  if not Assigned(cell) then
    exit;

  if GetElementEditValues(cell, 'EDID') <> 'HelgenKeep01' then
    exit;

  base := LinksTo(ElementByPath(e, 'NAME - Base'));
  if not Assigned(base) then
    exit;

  // --- Ausschluss unerwünschter Actors ---
  if IsExcludedActor(base) then
    exit;

  refrID := IntToHex(FixedFormID(e), 8);
  baseFormID := IntToHex(FixedFormID(base), 8);
  baseEditorID := GetElementEditValues(base, 'EDID');

  if GetElementNativeValues(e, 'Record Header\Record Flags\Persistent') = 1 then
    isPersistent := 'true'
  else
    isPersistent := 'false';

  // ---------- actors.csv ----------
  slActors.Add(Format('%s,%s,%s,%s', [
    refrID,
    baseFormID,
    baseEditorID,
    isPersistent
  ]));

  // ---------- actor_contents.csv (once per base) ----------
  if seenBase.IndexOf(baseFormID) = -1 then begin
    seenBase.Add(baseFormID);
    ExportActorContents(base);
  end;
end;

{ ================= FINALIZE ================= }

function Finalize: integer;
begin
  slActors.SaveToFile(ProgramPath + 'actors.csv');
  slContents.SaveToFile(ProgramPath + 'actor_contents.csv');

  slActors.Free;
  slContents.Free;
  seenBase.Free;

  AddMessage('Export finished: actors.csv (LvlBandit* & LvlAnimal* ausgeschlossen)');
end;

end.
