-- DeltaSuite Loader for Blox Fruits (Silent Aim 3D X/Y/Z + Player ESP)
local RAW_URL = "https://raw.githubusercontent.com/jakrjone123/DeltaSuite-BloxFruits/main/BloxFruitsSilent.luau"

local ok, source = pcall(function()
    return game:HttpGet(RAW_URL)
end)

if not ok or type(source) ~= "string" or #source == 0 then
    warn("[DeltaSuite BF] No se pudo descargar el script: " .. tostring(source))
    return
end

local fn, err = loadstring(source)
if not fn then
    warn("[DeltaSuite BF] Error de compilación: " .. tostring(err))
    return
end

fn()
