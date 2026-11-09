-- =====================================================================
--  GrainVolumeSettings.lua  (v1.1)
--  Fügt in Einstellungen -> Allgemein eine Auswahl "Schüttgut-Einheit"
--  (m³ / Bushel / Tonne / Liter) ein.
--
--  Vorgehen (auf echte FS25-Struktur gestützt, per Diagnose ermittelt):
--    Control  = MultiTextOption  id=multiMoneyUnit      (Anker + Vorlage)
--    Zeile    = Bitmap           id=multiMoneyUnitBox   (Label + Control)
--    Layout   = ScrollingLayout  id=generalSettingsLayout
--  Wir klonen die ZEILE des Money-Unit-Eintrags (eine echte
--  multiTextOption mit Pfeilen) in genau dessen Layout und biegen sie
--  auf unsere Einheit um. Keine geratenen Ebenen mehr.
--
--  Gespeichert wird über GrainVolumeHUD.saveSettings() in die lokale
--  modSettings-XML -> pro Spieler, auch im Multiplayer.
-- =====================================================================

GrainVolumeSettings = {}

-- Settings-Frame-Klasse(n), an deren onFrameOpen wir uns hängen.
local FRAME_CANDIDATES = {
    "InGameMenuSettingsFrame",
    "InGameMenuGeneralSettingsFrame",
    "InGameMenuGameSettingsFrame",
}

-- Anker-Control in den Allgemein-Einstellungen (stabile GIANTS-id,
-- multiTextOption mit Pfeilen -> ideale Klon-Vorlage).
local ANCHOR_ID = "multiMoneyUnit"

-- Hinter dieser Zeile wird unsere Option einsortiert (Ende der UNITS-Gruppe:
-- Area Unit). Fallback: hinter dem Vorlage-Anker (bleibt in UNITS).
local POSITION_AFTER_ID = "checkUseAcre"

-- ---------------------------------------------------------------------
-- Baum-Helfer
-- ---------------------------------------------------------------------

local function isOptionElement(el)
    return type(el) == "table"
        and type(el.setTexts) == "function"
        and type(el.setState) == "function"
        and type(el.getState) == "function"
end

-- Element per id finden.
local function findById(el, id)
    if type(el) ~= "table" then return nil end
    if rawget(el, "id") == id then return el end
    if type(el.elements) == "table" then
        for _, c in ipairs(el.elements) do
            local hit = findById(c, id)
            if hit ~= nil then return hit end
        end
    end
    return nil
end

-- Erstes Auswahl-Control im Teilbaum.
local function findOptionElement(el)
    if type(el) ~= "table" then return nil end
    if isOptionElement(el) then return el end
    if type(el.elements) == "table" then
        for _, c in ipairs(el.elements) do
            local hit = findOptionElement(c)
            if hit ~= nil then return hit end
        end
    end
    return nil
end

-- Erstes reines Text-Label (setText, aber kein Auswahl-Control).
local function findLabel(el, optionEl)
    if type(el) ~= "table" then return nil end
    if el ~= optionEl and type(el.setText) == "function" and not isOptionElement(el) then
        return el
    end
    if type(el.elements) == "table" then
        for _, c in ipairs(el.elements) do
            if c ~= optionEl then
                local hit = findLabel(c, optionEl)
                if hit ~= nil then return hit end
            end
        end
    end
    return nil
end

-- Geklonte ids neutralisieren (keine Kollision mit Menü-Feldern).
local function stripIds(el)
    if type(el) ~= "table" then return end
    el.id = nil
    if type(el.elements) == "table" then
        for _, c in ipairs(el.elements) do stripIds(c) end
    end
end

local function indexOf(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then return i end
    end
    return nil
end

-- Verschiebt 'element' in der Kinderliste von 'layout' direkt hinter 'afterRow'.
local function moveAfter(layout, element, afterRow)
    local elems = layout.elements
    if type(elems) ~= "table" then return end
    local ei = indexOf(elems, element)
    if ei == nil then return end
    table.remove(elems, ei)
    local ai = (afterRow ~= nil) and indexOf(elems, afterRow) or nil
    if ai == nil then
        elems[#elems + 1] = element            -- Fallback: ans Ende
    else
        table.insert(elems, ai + 1, element)
    end
end

-- ---------------------------------------------------------------------
-- Auswahl-Texte + Callback
-- ---------------------------------------------------------------------

function GrainVolumeSettings.buildTexts()
    local texts = {}
    for i, unit in ipairs(GrainVolume.UNIT_ORDER) do
        texts[i] = GrainVolume.getUnitLabel(unit)
    end
    return texts
end

function GrainVolumeSettings.onUnitChanged(_, state)
    local unit = GrainVolume.UNIT_ORDER[state]
    if unit == nil then return end
    GrainVolume.setUnit(unit)
    if GrainVolumeHUD ~= nil and GrainVolumeHUD.saveSettings ~= nil then
        GrainVolumeHUD.saveSettings()
    end
end

-- ---------------------------------------------------------------------
-- Einhängen
-- ---------------------------------------------------------------------

function GrainVolumeSettings.inject(frame)
    if frame == nil then return end

    -- Schon eingehängt? Nur Stand spiegeln.
    if frame.gvUnitOption ~= nil then
        frame.gvUnitOption:setState(GrainVolume.getUnitIndex(), false)
        return
    end

    -- Anker + Vorlage: Money-Unit-Eintrag der Allgemein-Seite.
    local anchor = findById(frame, ANCHOR_ID)
    if anchor == nil or not isOptionElement(anchor) then
        -- Anker fehlt (andere FS-Version?) -> nichts anfassen.
        Logging.warning("GrainVolumeHUD: Anker '%s' nicht gefunden -- Menüoption nicht eingehängt (Menü bleibt intakt).", ANCHOR_ID)
        return
    end

    local row = anchor.parent              -- Bitmap-Box (Label + Control)
    if row == nil then return end
    local layout = row.parent              -- ScrollingLayout (generalSettingsLayout)
    if layout == nil then return end

    local clonedRow = row:clone(layout)
    if clonedRow == nil then return end
    stripIds(clonedRow)

    local optionEl = findOptionElement(clonedRow)
    if optionEl == nil then
        clonedRow:delete()
        return
    end
    local labelEl = findLabel(clonedRow, optionEl)

    -- WICHTIG: Callback ZUERST umbiegen, damit setState nie den
    -- geerbten Money-Unit-Callback auslösen kann.
    optionEl.target = GrainVolumeSettings
    optionEl.onClickCallback = GrainVolumeSettings.onUnitChanged
    optionEl.onClick = nil

    if labelEl ~= nil then
        labelEl:setText(GrainVolume.l10n("gv_bulkUnit", "Schüttgut-Einheit"))
    end
    optionEl:setTexts(GrainVolumeSettings.buildTexts())
    optionEl:setState(GrainVolume.getUnitIndex(), false)

    -- An die richtige Stelle schieben: ans Ende der UNITS-Gruppe (hinter
    -- "Area Unit"). Fallback auf den Vorlage-Anker, sonst bleibt sie am Ende.
    local posAnchor = findById(frame, POSITION_AFTER_ID) or anchor
    local afterRow = posAnchor and posAnchor.parent or nil
    moveAfter(layout, clonedRow, afterRow)

    frame.gvUnitOption = optionEl
    if type(layout.invalidateLayout) == "function" then
        layout:invalidateLayout()
    end
end

-- ---------------------------------------------------------------------
-- An die Settings-Seite hängen
-- ---------------------------------------------------------------------

function GrainVolumeSettings.install()
    for _, name in ipairs(FRAME_CANDIDATES) do
        local cls = _G[name]
        if cls ~= nil and type(cls.onFrameOpen) == "function" then
            cls.onFrameOpen = Utils.appendedFunction(cls.onFrameOpen, function(self)
                GrainVolumeSettings.inject(self)
            end)
        end
    end
end

-- install() wird aus GrainVolumeHUD:loadMap() aufgerufen (Timing-sicher).
