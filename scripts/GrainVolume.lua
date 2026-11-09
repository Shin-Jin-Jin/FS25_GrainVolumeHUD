-- =====================================================================
--  GrainVolume.lua  (v1.1)
--  Kern-Logik: Schüttgut vs. Flüssigkeit, Einheiten-Umrechnung und
--  Formatierung. Wird vom HUD-Hook benutzt.
--
--  Einheiten:
--    M3     = Liter / 1000                     (fülltyp-unabhängig)
--    BUSHEL = Liter / 35.239                   (US-Bushel, rein volumetrisch)
--    TON    = Liter * massPerLiter / 1000      (Tonnen; material-abhängige Dichte)
--    LITER  = unverändert (Original)
-- =====================================================================

GrainVolume = {}

-- Feste Umrechnungsfaktoren (Liter -> Einheit)
GrainVolume.LITERS_PER_M3     = 1000.0
GrainVolume.LITERS_PER_BUSHEL = 35.239    -- US bushel (Winchester), rein volumetrisch

-- Gewählte Einheit (wird aus modSettings geladen). Fallback: m³.
GrainVolume.unit = "M3"
GrainVolume.VALID_UNITS = { M3 = true, BUSHEL = true, TON = true, LITER = true }

-- Bekannte Flüssigkeiten -> bleiben in Litern.
GrainVolume.LIQUID_FILLTYPE_NAMES = {
    "WATER", "MILK", "GOATMILK", "BUFFALOMILK",
    "DIESEL", "DEF", "ELECTRICCHARGE", "METHANE",
    "LIQUIDFERTILIZER", "HERBICIDE", "LIQUIDSEEDTREATMENT",
    "MANURE", "LIQUIDMANURE", "DIGESTATE", "MOLASSES",
    "WINE", "GRAPEJUICE", "JUICE",
    "OIL", "SUNFLOWER_OIL", "CANOLA_OIL", "OLIVE_OIL", "RICE_OIL",
    "CHOCOLATE", "HONEY", "CREAM",
}

local liquidLookup   -- [fillTypeIndex] = true, lazy aufgebaut

local function ensureLiquidLookup()
    if liquidLookup ~= nil then
        return liquidLookup
    end
    liquidLookup = {}
    if g_fillTypeManager == nil then
        return liquidLookup
    end
    for _, name in ipairs(GrainVolume.LIQUID_FILLTYPE_NAMES) do
        local index = g_fillTypeManager:getFillTypeIndexByName(name)
        if index ~= nil then
            liquidLookup[index] = true
        end
    end
    return liquidLookup
end

---True, wenn dieser Fülltyp als Schüttgut (umgerechnete Einheit) angezeigt wird.
function GrainVolume.isBulk(fillTypeIndex)
    if fillTypeIndex == nil then
        return false
    end
    if FillType ~= nil and fillTypeIndex == FillType.UNKNOWN then
        return false
    end
    return ensureLiquidLookup()[fillTypeIndex] ~= true
end

---Setzt die aktive Einheit (validiert, sonst M3).
function GrainVolume.setUnit(unit)
    if unit ~= nil then
        unit = tostring(unit):upper()
        if GrainVolume.VALID_UNITS[unit] then
            GrainVolume.unit = unit
            return
        end
    end
    GrainVolume.unit = "M3"
end

-- Dichte (kg pro Liter) eines Fülltyps aus FS holen, mit Fallback.
local function getMassPerLiter(fillTypeIndex)
    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
        local ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        if ft ~= nil and type(ft.massPerLiter) == "number" and ft.massPerLiter > 0 then
            return ft.massPerLiter
        end
    end
    -- FS-Standard, falls nichts hinterlegt ist (entspricht grob Getreide)
    return 0.0009
end

-- Lokalisierte Zahl mit passender Nachkommastelle.
local function formatNumber(value, decimals)
    if g_i18n ~= nil and g_i18n.formatNumber ~= nil then
        return g_i18n:formatNumber(value, decimals)
    end
    return string.format("%." .. decimals .. "f", value)
end

-- Nachkommastellen je nach Größenordnung (lesbar bei groß wie klein).
local function pickDecimals(value)
    if value >= 100 then return 0
    elseif value >= 10 then return 1
    else return 2 end
end

---Rechnet rohe Liter in die aktive Einheit um und gibt Wert + Einheitenkürzel.
-- @return string value, string unitLabel
function GrainVolume.convert(fillTypeIndex, liters)
    liters = liters or 0
    local unit = GrainVolume.unit

    if unit == "BUSHEL" then
        local v = liters / GrainVolume.LITERS_PER_BUSHEL
        return formatNumber(v, pickDecimals(v)), "bu"
    elseif unit == "TON" then
        local t = liters * getMassPerLiter(fillTypeIndex) / 1000.0  -- kg -> t
        return formatNumber(t, pickDecimals(t)), "t"
    elseif unit == "LITER" then
        -- Original-Litertext überlassen wir dem Spiel; hier nur als Zahl
        return formatNumber(liters, 0), "l"
    else -- M3
        local v = liters / GrainVolume.LITERS_PER_M3
        return formatNumber(v, pickDecimals(v)), "m³"
    end
end

---HUD-Text inkl. Prozent im Stil des Originals: z.B. "12,5 m³ (77%)".
function GrainVolume.formatBulkText(fillTypeIndex, liters, capacity)
    liters = liters or 0
    local valueStr, unitLabel = GrainVolume.convert(fillTypeIndex, liters)
    local pct = 0
    if capacity ~= nil and capacity > 0 then
        pct = math.floor(liters / capacity * 100)
    end
    return string.format("%s %s (%d%%)", valueStr, unitLabel, pct)
end

---Reihenfolge und Anzeige-Labels der wählbaren Einheiten (fürs Menü).
GrainVolume.UNIT_ORDER = { "M3", "BUSHEL", "TON", "LITER" }

-- l10n-Schlüssel je Einheit (Übersetzung in translations/translation_*.xml)
GrainVolume.UNIT_L10N = {
    M3     = "gv_unit_m3",
    BUSHEL = "gv_unit_bushel",
    TON    = "gv_unit_ton",
    LITER  = "gv_unit_liter",
}

-- Fallback-Texte, falls g_i18n den Schlüssel (noch) nicht kennt.
GrainVolume.UNIT_LABELS_FALLBACK = {
    M3     = "Kubikmeter (m\u{00B3})",
    BUSHEL = "Bushel (bu)",
    TON    = "Tonnen (t)",
    LITER  = "Liter (l)",
}

---Übersetzten Text zu einem l10n-Schlüssel holen, mit Fallback.
-- @param key string l10n-Name
-- @param fallback string Text, falls nicht vorhanden
function GrainVolume.l10n(key, fallback)
    if g_i18n ~= nil and g_i18n.hasText ~= nil and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end
    return fallback or key
end

---Anzeigename einer Einheit (lokalisiert).
function GrainVolume.getUnitLabel(unit)
    return GrainVolume.l10n(GrainVolume.UNIT_L10N[unit], GrainVolume.UNIT_LABELS_FALLBACK[unit] or unit)
end

---Index der aktuellen Einheit in UNIT_ORDER (1-basiert, Fallback 1).
function GrainVolume.getUnitIndex()
    for i, u in ipairs(GrainVolume.UNIT_ORDER) do
        if u == GrainVolume.unit then
            return i
        end
    end
    return 1
end
