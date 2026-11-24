# Delta Suite — Blox Fruits

Script modular compacto en Luau para **Blox Fruits** (`First / Second / Third Sea`), enfocado en **Silent Aim multi-canal con predicción 3D (`X, Y, Z`)** para habilidades y armas + **Player ESP**.

## Ejecución rápida (Loadstring)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/jakrjone123/DeltaSuite-BloxFruits/main/BloxFruitsSilent.luau"))()
```

O usando el cargador con manejo de errores (`loader.luau`):

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/jakrjone123/DeltaSuite-BloxFruits/main/loader.luau"))()
```

## Características incluidas

- **UI táctica compacta (`468 x 362`)**
  - Ventana lateral izquierda (`x = 22px`) para no bloquear el centro de la pantalla ni los clics, tema Obsidian translúcido arrastrable con 2 pestañas (**`Silent`** y **`ESP`**), barra de estado con FPS, ping y objetivo fijado, tecla de menú configurable (`RightControl`) y descarga limpia (`Unload Script`).
- **Silent Aim 3D (`X, Y, Z`) multi-canal activo por defecto (`v4.5`)**
  - **Activo al instante sin tecla (`Mode = Always`, `Silent Key = None`, `Use FOV = false`):** engancha automáticamente a jugadores enemigos visibles o en rango cercano (`<= 260m`) sin requerir tecla ni restringir habilidades con un círculo pequeño (el círculo FOV sigue disponible en el menú).
  - **Modo `Focus 1 Enemy` (`Focus Target` + `Focus Key = G`):** permite fijar un solo enemigo para que todo el Silent Aim se centre exclusivamente en esa persona (incluso fuera del FOV o detrás de la cámara dentro de `MaxDistance`), con selector cíclico en el menú (`Auto` / nombre de jugador, clic derecho vuelve a `Auto`), tecla rápida configurable (`G`) para fijar/soltar al objetivo actual y resaltado `★ [FOCUS]` en ESP y pie de barra.
  - **Protección automática para NPCs, Frutas, Interacciones y Ataques (`Safe NPC / Fruit`):** solo activa Silent Aim cuando tienes equipada un arma/habilidad de combate real (excluyendo manos vacías, accesorios `Wear`, cañas `JobTool` y frutas físicas sin comer), cede el control automáticamente ante diálogos abiertos (`Main.Dialogue`), NPCs cercanos, enemigos PvE, frutas en el suelo, `ClickDetector`, `ProximityPrompt` o clics en el menú, no altera `WrapMouse` ni `Tool.RemoteFunction`, preserva el método de red `OP_NAMECALL` intacto (para no romper `Dodge`/Dash, `Soru`, `Geppo` ni `Tool.RemoteEvent`), conserva `ctx:aim` en `MovesetUtil.Aim.fromMouse` y virtualiza `ReplicatedStorage.Mouse` mediante `__newindex`. `Auto Face on Skill` es opcional (desactivado por defecto) y solo aplica a `Z / X / C / V`.
  - **Predicción cinemática 3D calibrada (`X, Y, Z`):** factor RTT (`0.60x` de `Data Ping`), velocidades calibradas por arma (`Hitscan = 2600`, `Gun = 1900`, `Melee/Sword = 900`, `Guitar = 340`, `Skill Speed = 620`, `BaseLead = 15ms`), reseteo de aceleración al detenerse o cambiar brusco de dirección (sin sobre-adelanto al frenar), compensación de caída segura en estado `Flying`, clamps en velocidad/aceleración/lead y redirección ampliada para `Tool.RemoteEvent`.
  - **Filtros PvP reales de Blox Fruits:** `Team / Ally Check` (`AllianceUtil.getIfAllied` + `Marines`), `Ignore SafeZone` (`InSafeZone`), `Sticky Lock`, `Focus 1 Enemy`, `FOV Circle` opcional, `HitPart` enfocado al pecho por defecto (`Chest` -> `UpperTorso`/`Torso` -> `RootPart`, con opciones `RootPart` y `Closest Body`, sin apuntar a la cabeza) y `Priority` (`Crosshair`, `Closest`, `Lowest HP`).
- **Player ESP (pool `Drawing` perezoso)**
  - `Box Style` (`Corner` / `2D` / `Off`), `Chams Highlights`, `Health Bar`, `Health Text`, `Name & Level`, `Distance`, `Bounty / Safe / Ken` (`[SAFE]` y cargas `[KEN x/y]`), `Fruit / Tool`, `Offscreen Arrows`, `Tracers`, `Skeleton` compatible con **R6 y R15** bajo demanda y alcance configurable hasta `20000`.
