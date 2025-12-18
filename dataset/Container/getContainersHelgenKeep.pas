unit ExportHelgenKeep01_Containers;

var
  slContainers: TStringList;
  slBase: TStringList;
  baseSeen: TStringList;

{ -------------------- Helpers -------------------- }

function HasLVLIStr(base: IInterface): string;
var
  items, entry, itemRef: IInterface;
  i: integer;
begin
  Result := 'false';
  items := ElementByPath(base, 'Items');
  if not Assigned(items) then
    exit;

  for i := 0 to ElementCount(items) - 1 do begin
    entry := ElementByIndex(items, i);
    itemRef := LinksTo(ElementByPath(entry, 'Item'));
    if Assigned(itemRef) then
      if Signature(itemRef) = 'LVLI' then begin
        Result := 'true';
        exit;
      end;
  end;
end;

function IsSkeletonRaceStr(npc: IInterface): string;
var
  race: IInterface;
  edid: string;
begin
  Result := 'false';
  race := LinksTo(ElementByPath(npc, 'RNAM - Race'));
  if Assigned(race) then begin
    edid := GetElementEditValues(race, 'EDID');
    if Pos('Skeleton', edid) > 0 then
      Result := 'true';
  end;
end;

{ -------------------- Init -------------------- }

function Initialize: integer;
begin
  slContainers := TStringList.Create;
  slBase := TStringList.Create;
  baseSeen := TStringList.Create;

  baseSeen.Sorted := true;
  baseSeen.Duplicates := dupIgnore;

  slContainers.Add(
    'form_id,editor_id,refr_id,container_type,is_persistent,source_type'
  );

  slBase.Add(
    'form_id,editor_id,container_type,has_lvli,harvest_item_form_id'
  );
end;

{ -------------------- Main -------------------- }

function Process(e: IInterface): integer;
var
  cell, base, harvestItem: IInterface;
  baseFormID, editorID, refrID: string;
  containerType, isPersistent, hasLvli, harvestFormID: string;
begin
  // Nur platzierte Objekte oder Actors
  if (Signature(e) <> 'REFR') and (Signature(e) <> 'ACHR') then
    exit;

  // Cell prüfen
  cell := LinksTo(ElementByPath(e, 'Cell'));
  if not Assigned(cell) then
    exit;

  if GetElementEditValues(cell, 'EDID') <> 'HelgenKeep01' then
    exit;

  // Base
  base := LinksTo(ElementByPath(e, 'NAME - Base'));
  if not Assigned(base) then
    exit;

  refrID := IntToHex(FixedFormID(e), 8);

  // Persistent Flag
  if GetElementNativeValues(e, 'Record Header\Record Flags\Persistent') = 1 then
    isPersistent := 'true'
  else
    isPersistent := 'false';

  hasLvli := 'false';
  harvestFormID := '';

  { ---------- CONTAINER ---------- }
  if Signature(base) = 'CONT' then begin
    containerType := 'CONT';
    editorID := GetElementEditValues(base, 'EDID');
    baseFormID := IntToHex(FixedFormID(base), 8);
    hasLvli := HasLVLIStr(base);
  end

  { ---------- FLORA ---------- }
  else if Signature(base) = 'FLOR' then begin
    containerType := 'FLOR';
    editorID := GetElementEditValues(base, 'EDID');
    baseFormID := IntToHex(FixedFormID(base), 8);

    harvestItem := LinksTo(ElementByPath(base, 'PFIG - Ingredient'));
    if Assigned(harvestItem) then
      harvestFormID := IntToHex(FixedFormID(harvestItem), 8);
  end

  { ---------- ACTORS ---------- }
  else if Signature(e) = 'ACHR' then begin

    // echte Leichen
    if GetElementNativeValues(e, 'Record Header\Record Flags\Starts Dead') = 1 then begin
      containerType := 'NPC';
      editorID := GetElementEditValues(base, 'EDID');
      baseFormID := IntToHex(FixedFormID(base), 8);
      hasLvli := HasLVLIStr(base);
    end

    // Skelette (immer lootbar)
    else if IsSkeletonRaceStr(base) = 'true' then begin
      containerType := 'ACTOR';
      editorID := GetElementEditValues(base, 'EDID');
      baseFormID := IntToHex(FixedFormID(base), 8);
      hasLvli := HasLVLIStr(base);
    end

    else
      exit;
  end
  else
    exit;

  { ---------- Write instance ---------- }
  slContainers.Add(Format('%s,%s,%s,%s,%s,PLACED', [
    baseFormID,
    editorID,
    refrID,
    containerType,
    isPersistent
  ]));

  { ---------- Write base ---------- }
  if baseSeen.IndexOf(baseFormID) = -1 then begin
    baseSeen.Add(baseFormID);
    slBase.Add(Format('%s,%s,%s,%s,%s', [
      baseFormID,
      editorID,
      containerType,
      hasLvli,
      harvestFormID
    ]));
  end;
end;

{ -------------------- Finalize -------------------- }

function Finalize: integer;
begin
  slContainers.SaveToFile(ProgramPath + 'containers_HelgenKeep01.csv');
  slBase.SaveToFile(ProgramPath + 'containers_base_HelgenKeep01.csv');

  slContainers.Free;
  slBase.Free;
  baseSeen.Free;

  AddMessage('Container export finished: containers_HelgenKeep01.csv');
  AddMessage('Base container export finished: containers_base_HelgenKeep01.csv');
end;

end.
