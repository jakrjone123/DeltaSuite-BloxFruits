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

- **UI táctica compacta (`472 x 396`)**
  - Ventana lateral izquierda (`x = 22px`) para no bloquear el centro de la pantalla ni los clics, tema Obsidian translúcido arrastrable con 2 pestañas (**`Silent`** y **`ESP`**), barra de estado con FPS, ping y objetivo fijado, tecla de menú configurable (`RightControl`) y descarga limpia (`Unload Script`).
- **Silent Aim 3D (`X, Y, Z`) multi-canal activo por defecto**
  - **Activo al instante sin tecla (`Mode = Always`, `Silent Key = None`, `Use FOV = false`):** funciona desde que cargas el script sin requerir tecla ni cubrir solo un círculo pequeño.
  - **Cobertura segura de habilidades y movimiento libre:** intercepta `ReplicatedStorage.Mouse`, `Global.updateMouseWrapper`, `WrapMouse`, `WrapMouse2`, `MovesetUtil.Aim.fromMouse`, `Util.GetMousePoint`, `CombatUtil.GetTargetPosition`, `LocalPlayer:GetMouse()`, `Tool.MousePos` y remotos de combate (`Tool.RemoteEvent`, `RemoteFunction`, `RE/ShootGunEvent`, `CommE` de ataque) sin bloquear dashes, movimiento `WASD`, saltos, cursor ni tecla `F`. `Auto Face on Skill` es opcional (desactivado por defecto) y solo aplica a habilidades `Z / X / C / V`.
  - **Predicción cinemática 3D (`X, Y, Z`):** velocidad híbrida (`AssemblyLinearVelocity` + delta posicional suavizada), aceleración EMA (`Accel / Dash Lead`), rechazo de picos de teletransporte/`Soru`, tiempo de vuelo iterativo según ping (`Data Ping`) + velocidad automática por arma (`WeaponData`) o `Skill Speed`, escalado independiente **`Predict X` / `Predict Y` / `Predict Z`**, compensación vertical de caída (`Gravity / Air Y`) con clamp al suelo y punto/línea visual de predicción (`Show Lead Dot`).
  - **Filtros PvP reales de Blox Fruits:** `Team / Ally Check` (`AllianceUtil.getIfAllied` + `Marines`), `Ignore SafeZone` (`InSafeZone`), `Sticky Lock`, `FOV Circle` opcional, `HitPart` enfocado al pecho por defecto (`Chest` -> `UpperTorso`/`Torso` -> `RootPart`, con opciones `RootPart` y `Closest Body`, sin apuntar a la cabeza) y `Priority` (`Crosshair`, `Closest`, `Lowest HP`).
- **Player ESP (pool `Drawing` perezoso)**
  - `Box Style` (`Corner` / `2D` / `Off`), `Chams Highlights`, `Health Bar`, `Health Text`, `Name & Level`, `Distance`, `Bounty / Safe / Ken` (`[SAFE]` y cargas `[KEN x/y]`), `Fruit / Tool`, `Offscreen Arrows`, `Tracers`, `Skeleton` compatible con **R6 y R15** bajo demanda y alcance configurable hasta `20000`.
