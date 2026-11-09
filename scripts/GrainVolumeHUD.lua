-- =====================================================================
--  GrainVolumeHUD.lua  (v1.1)
--  Hook in FillLevelsDisplay.draw: rechnet bei Schüttgut-Einträgen den
--  fertigen fillLevelText in die gewählte Einheit um. Idempotent (immer
--  aus dem rohen fillLevel), Flüssigkeiten bleiben unberührt.
--
--  Einheit kommt aus modSettings/GrainVolumeHUD.xml (einmal beim Start
--  geladen). Gültige Werte: M3, BUSHEL, TON, LITER.
-- =====================================================================

GrainVolumeHUD = {}
GrainVolumeHUD.installed = false

-- ---------------------------------------------------------------------
-- Einstellungen laden (modSettings/GrainVolumeHUD.xml)
-- ---------------------------------------------------------------------

local SETTINGS_DIR  = getUserProfileAppPath() .. "modSettings/"
local SETTINGS_FILE = SETTINGS_DIR .. "GrainVolumeHUD.xml"

---Schreibt die aktuelle Einheit in die lokale modSettings-XML (pro Spieler).
function GrainVolumeHUD.saveSettings()
    createFolder(SETTINGS_DIR)
    local xml = createXMLFile("gvSettings", SETTINGS_FILE, "grainVolumeHUD")
    if xml == nil or xml == 0 then
        return
    end
    -- unit: M3 | BUSHEL | TON | LITER
    setXMLString(xml, "grainVolumeHUD.unit", GrainVolume.unit)
    saveXMLFile(xml)
    delete(xml)
end

local function loadSettings()
    if not fileExists(SETTINGS_FILE) then
        GrainVolumeHUD.saveSettings()
        GrainVolume.setUnit(GrainVolume.unit)
        return
    end

    local xml = loadXMLFile("gvSettings", SETTINGS_FILE)
    if xml == nil or xml == 0 then
        GrainVolume.setUnit("M3")
        return
    end
    local unit = getXMLString(xml, "grainVolumeHUD.unit")
    delete(xml)
    GrainVolume.setUnit(unit)
end

-- ---------------------------------------------------------------------
-- Hook
-- ---------------------------------------------------------------------

function GrainVolumeHUD.drawOverride(display, superFunc, ...)
    local data = display.fillLevelData
    if type(data) == "table" then
        for _, entry in pairs(data) do
            if type(entry) == "table"
               and entry.isValid
               and type(entry.fillLevel) == "number"
               and GrainVolume.isBulk(entry.fillType) then
                entry.fillLevelText = GrainVolume.formatBulkText(entry.fillType, entry.fillLevel, entry.capacity)
            end
        end
    end
    return superFunc(display, ...)
end

function GrainVolumeHUD.tryInstall()
    if GrainVolumeHUD.installed then return end
    if FillLevelsDisplay == nil or type(FillLevelsDisplay.draw) ~= "function" then
        return
    end
    FillLevelsDisplay.draw = Utils.overwrittenFunction(FillLevelsDisplay.draw, GrainVolumeHUD.drawOverride)
    GrainVolumeHUD.installed = true
end

-- ---------------------------------------------------------------------
-- ModEventListener
-- ---------------------------------------------------------------------

function GrainVolumeHUD:loadMap()
    loadSettings()
    GrainVolumeHUD.tryInstall()
    if GrainVolumeSettings ~= nil and GrainVolumeSettings.install ~= nil then
        GrainVolumeSettings.install()
    end
end

function GrainVolumeHUD:update(dt)
    GrainVolumeHUD.tryInstall()
end

addModEventListener(GrainVolumeHUD)
