extends Node2D

const PLAYER_SPEED := 245.0
const ENEMY_BASE_SPEED := 62.0
const ARENA := Rect2(24, 90, 492, 780)

var player := Vector2(270, 510)
var enemies: Array[Dictionary] = []
var orbs: Array[Dictionary] = []
var hp := 100.0
var xp := 0
var level := 1
var aura := 0
var wave := 1
var elapsed := 0.0
var spawn_clock := 0.0
var attack_clock := 0.0
var invuln := 0.0
var joystick_touch := -1
var joystick_origin := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var paused_for_upgrade := false
var upgrade_choices: Array[String] = []
var upgrades := {"Dano": 0, "Velocidade": 0, "Ímã de aura": 0}
var game_over := false

func _process(delta: float) -> void:
    if game_over or paused_for_upgrade:
        queue_redraw()
        return
    elapsed += delta
    spawn_clock += delta
    attack_clock += delta
    invuln = maxf(0.0, invuln - delta)

    var move := joystick_vector
    if move.length() < 0.1:
        move = Vector2(
            Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
            Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
        ).normalized()
    player += move * PLAYER_SPEED * (1.0 + upgrades["Velocidade"] * 0.08) * delta
    player.x = clampf(player.x, ARENA.position.x + 18, ARENA.end.x - 18)
    player.y = clampf(player.y, ARENA.position.y + 18, ARENA.end.y - 18)

    var spawn_interval := maxf(0.32, 1.35 - float(wave - 1) * 0.07)
    if spawn_clock >= spawn_interval:
        spawn_clock = 0.0
        _spawn_enemy()

    for i in range(enemies.size() - 1, -1, -1):
        var e: Dictionary = enemies[i]
        var dir: Vector2 = (player - e["pos"]).normalized()
        e["pos"] = e["pos"] + dir * float(e["speed"]) * delta
        e["hit_cd"] = maxf(0.0, float(e["hit_cd"]) - delta)
        if e["pos"].distance_to(player) < 30.0 and float(e["hit_cd"]) <= 0.0 and invuln <= 0.0:
            hp -= 10.0
            invuln = 0.65
            e["hit_cd"] = 0.8
            if hp <= 0.0:
                game_over = true
        enemies[i] = e

    for i in range(orbs.size() - 1, -1, -1):
        var orb: Dictionary = orbs[i]
        var magnet_range := 70.0 + upgrades["Ímã de aura"] * 35.0
        if player.distance_to(orb["pos"]) < magnet_range:
            orb["pos"] = orb["pos"].move_toward(player, (180.0 + upgrades["Ímã de aura"] * 60.0) * delta)
        if player.distance_to(orb["pos"]) < 23.0:
            xp += int(orb["value"])
            aura += int(orb["value"])
            orbs.remove_at(i)
            _check_level()
        else:
            orbs[i] = orb

    if attack_clock >= 0.72:
        attack_clock = 0.0
        _auto_attack()

    wave = int(elapsed / 25.0) + 1
    queue_redraw()

func _spawn_enemy() -> void:
    var side := randi() % 4
    var pos := Vector2.ZERO
    match side:
        0: pos = Vector2(randf_range(ARENA.position.x, ARENA.end.x), ARENA.position.y + 12)
        1: pos = Vector2(randf_range(ARENA.position.x, ARENA.end.x), ARENA.end.y - 12)
        2: pos = Vector2(ARENA.position.x + 12, randf_range(ARENA.position.y, ARENA.end.y))
        _: pos = Vector2(ARENA.end.x - 12, randf_range(ARENA.position.y, ARENA.end.y))
    enemies.append({"pos": pos, "hp": 1 + int(wave / 3), "speed": ENEMY_BASE_SPEED + wave * 3.0, "hit_cd": 0.0})

func _auto_attack() -> void:
    if enemies.is_empty():
        return
    var target_index := -1
    var best := 99999.0
    for i in range(enemies.size()):
        var d: float = player.distance_to(enemies[i]["pos"])
        if d < best:
            best = d
            target_index = i
    if target_index < 0:
        return
    var target: Vector2 = enemies[target_index]["pos"]
    enemies[target_index]["hp"] -= 1 + upgrades["Dano"]
    if enemies[target_index]["hp"] <= 0:
        orbs.append({"pos": target, "value": 1 + int(wave / 5)})
        enemies.remove_at(target_index)

func _check_level() -> void:
    var needed := level * 5
    if xp >= needed:
        xp -= needed
        level += 1
        paused_for_upgrade = true
        var pool := ["Dano", "Velocidade", "Ímã de aura"]
        pool.shuffle()
        upgrade_choices = pool.slice(0, 3)

func _choose_upgrade(index: int) -> void:
    if index < 0 or index >= upgrade_choices.size():
        return
    var name: String = upgrade_choices[index]
    upgrades[name] += 1
    paused_for_upgrade = false

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(540, 960)), Color("#111323"))
    draw_rect(ARENA, Color("#202640"))
    for x in range(int(ARENA.position.x), int(ARENA.end.x), 32):
        draw_line(Vector2(x, ARENA.position.y), Vector2(x, ARENA.end.y), Color("#29314c"), 1)
    for y in range(int(ARENA.position.y), int(ARENA.end.y), 32):
        draw_line(Vector2(ARENA.position.x, y), Vector2(ARENA.end.x, y), Color("#29314c"), 1)
    draw_rect(ARENA, Color("#59658a"), false, 4)

    for orb in orbs:
        draw_rect(Rect2(orb["pos"] - Vector2(5, 5), Vector2(10, 10)), Color("#65f5d0"))
    for e in enemies:
        var p: Vector2 = e["pos"]
        draw_rect(Rect2(p - Vector2(13, 13), Vector2(26, 26)), Color("#ff5577"))
        draw_rect(Rect2(p - Vector2(7, 5), Vector2(4, 4)), Color.WHITE)
        draw_rect(Rect2(p + Vector2(3, -5), Vector2(4, 4)), Color.WHITE)
    draw_circle(player, 25, Color("#8b72ff", 0.18))
    draw_rect(Rect2(player - Vector2(13, 15), Vector2(26, 30)), Color("#8c7bff"))
    draw_rect(Rect2(player - Vector2(7, 7), Vector2(5, 5)), Color.WHITE)
    draw_rect(Rect2(player + Vector2(3, -7), Vector2(5, 5)), Color.WHITE)

    _draw_hud()
    _draw_joystick()
    if paused_for_upgrade:
        _draw_upgrade()
    if game_over:
        _draw_game_over()

func _draw_hud() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(24, 38), "AURA SURVIVORS", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("#f4eaff"))
    draw_string(ThemeDB.fallback_font, Vector2(24, 67), "ONDA %d   NIVEL %d   AURA %d" % [wave, level, aura], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#74f3d1"))
    draw_rect(Rect2(24, 76, 492, 8), Color("#343b59"))
    draw_rect(Rect2(24, 76, 492 * hp / 100.0, 8), Color("#ff5577"))
    draw_string(ThemeDB.fallback_font, Vector2(24, 895), "XP %d / %d" % [xp, level * 5], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#f4eaff"))
    draw_string(ThemeDB.fallback_font, Vector2(24, 922), "Arraste o dedo para mover | Ataque automatico", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#aab2d0"))

func _draw_joystick() -> void:
    var center := Vector2(92, 810)
    draw_circle(center, 54, Color("#ffffff", 0.08))
    draw_circle(center + joystick_vector * 27, 24, Color("#a99bff", 0.65))

func _draw_upgrade() -> void:
    draw_rect(Rect2(0, 0, 540, 960), Color("#080a16", 0.82))
    draw_string(ThemeDB.fallback_font, Vector2(70, 340), "SUBIU DE NIVEL!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("#ffe66d"))
    draw_string(ThemeDB.fallback_font, Vector2(70, 380), "Escolha um upgrade:", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
    for i in range(upgrade_choices.size()):
        var y := 425 + i * 105
        draw_rect(Rect2(48, y, 444, 78), Color("#34345e"))
        draw_rect(Rect2(48, y, 444, 78), Color("#9b8cff"), false, 3)
        draw_string(ThemeDB.fallback_font, Vector2(75, y + 48), "%d. %s" % [i + 1, upgrade_choices[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)

func _draw_game_over() -> void:
    draw_rect(Rect2(0, 0, 540, 960), Color("#080a16", 0.85))
    draw_string(ThemeDB.fallback_font, Vector2(125, 420), "FIM DE JOGO", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("#ff6688"))
    draw_string(ThemeDB.fallback_font, Vector2(125, 470), "Aura coletada: %d" % aura, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(125, 525), "Toque para reiniciar", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#ffe66d"))

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if game_over:
                _restart()
                return
            if paused_for_upgrade:
                var idx := int((event.position.y - 425.0) / 105.0)
                _choose_upgrade(idx)
                return
            if event.position.y > 690.0:
                joystick_touch = event.index
                joystick_origin = Vector2(92, 810)
                _update_joystick(event.position)
        elif event.index == joystick_touch:
            joystick_touch = -1
            joystick_vector = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == joystick_touch:
        _update_joystick(event.position)

func _update_joystick(pos: Vector2) -> void:
    joystick_vector = (pos - joystick_origin).limit_length(1.0)
    if joystick_vector.length() > 0.12:
        joystick_vector = joystick_vector.normalized() * minf(1.0, pos.distance_to(joystick_origin) / 55.0)

func _restart() -> void:
    player = Vector2(270, 510)
    enemies.clear()
    orbs.clear()
    hp = 100.0
    xp = 0
    level = 1
    aura = 0
    wave = 1
    elapsed = 0.0
    spawn_clock = 0.0
    attack_clock = 0.0
    upgrades = {"Dano": 0, "Velocidade": 0, "Ímã de aura": 0}
    game_over = false
