<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@page import="java.sql.*"%>
<%@page import="java.util.*"%>
<%!
    static String h(String s) {
        if (s == null) return "";
        return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }
%>
<%
    if (session.getAttribute("usuarioValido") == null) { response.sendRedirect("login.jsp"); return; }
    String nombreUsuario = (String) session.getAttribute("nombre");
    String rolActual = (String) session.getAttribute("rol");
    if (nombreUsuario == null) nombreUsuario = "Jugador";

    String dbUrl = "jdbc:mysql://192.168.15.135:3306/transmetro_db";
    String dbUser = "admin";
    String dbPass = "admin123";

    if ("POST".equalsIgnoreCase(request.getMethod()) && "guardar_score".equals(request.getParameter("accion"))) {
        try {
            int score = Integer.parseInt(request.getParameter("score"));
            if (score > 0) {
                Class.forName("com.mysql.cj.jdbc.Driver");
                try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                     PreparedStatement ps = con.prepareStatement("INSERT INTO ranking_juego (nombre_usuario, puntaje) VALUES (?, ?)")) {
                    ps.setString(1, nombreUsuario);
                    ps.setInt(2, score);
                    ps.executeUpdate();
                }
            }
        } catch (Exception e) {}
        return;
    }

    int miMejorPuntaje = 0;
%>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Transmetro Rush &amp; Fly — Zona Arcade</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: 'Inter', -apple-system, sans-serif;
            background-color: #f8fafc;
            margin: 0;
            padding-top: 72px;
            color: #0f172a;
        }
        .header {
            background: rgba(255, 255, 255, 0.9);
            backdrop-filter: blur(12px);
            padding: 0 24px;
            position: fixed;
            top: 0;
            width: 100%;
            z-index: 1000;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid #e2e8f0;
            height: 64px;
        }
        .header h1 { margin: 0; font-size: 16px; text-align: center; flex-grow: 1; font-weight: 800; color: #0f172a; }
        .menu-btn { background: none; border: none; color: #475569; font-size: 22px; cursor: pointer; width: 38px; height: 38px; border-radius: 10px; }
        .overlay { display: none; position: fixed; width: 100%; height: 100%; top: 0; left: 0; background: rgba(15, 23, 42, 0.35); z-index: 999; }

        .main-container {
            max-width: 1200px;
            margin: 18px auto 50px auto;
            padding: 0 20px;
        }

        .top-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 12px;
            margin-bottom: 16px;
        }
        .btn-volver {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            color: #475569;
            background: #ffffff;
            border: 1px solid #e2e8f0;
            padding: 8px 14px;
            border-radius: 10px;
            text-decoration: none;
            font-size: 13px;
            font-weight: 600;
        }
        .btn-volver:hover { background: #f1f5f9; color: #0f172a; }

        /* Telemetría en Vivo */
        .telemetry-row {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
            gap: 12px;
            margin-bottom: 18px;
        }
        .tel-card {
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 12px;
            padding: 12px 16px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            box-shadow: 0 1px 2px rgba(15, 23, 42, 0.03);
        }
        .tel-label { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: #64748b; }
        .tel-val { font-size: 20px; font-weight: 800; color: #0f172a; margin-top: 2px; }

        /* Layout Juego + Ranking */
        .arcade-grid {
            display: grid;
            grid-template-columns: 1fr 340px;
            gap: 20px;
            align-items: start;
        }
        @media (max-width: 960px) {
            .arcade-grid { grid-template-columns: 1fr; }
        }

        .game-card {
            background: #ffffff;
            border-radius: 16px;
            padding: 18px;
            border: 1px solid #e2e8f0;
            box-shadow: 0 4px 20px -4px rgba(15, 23, 42, 0.06);
        }

        .canvas-wrap {
            position: relative;
            border-radius: 12px;
            overflow: hidden;
            border: 2px solid #0f172a;
            box-shadow: 0 10px 25px -5px rgba(15, 23, 42, 0.2);
            background: #0f172a;
        }
        canvas {
            display: block;
            width: 100%;
            height: 410px;
            cursor: pointer;
        }
        canvas:fullscreen { width: 100vw; height: 100vh; object-fit: contain; background: #0f172a; }
        canvas:-webkit-full-screen { width: 100vw; height: 100vh; object-fit: contain; background: #0f172a; }

        /* Controles inferiores */
        .controls-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 14px;
            padding-top: 14px;
            border-top: 1px solid #f1f5f9;
        }
        .control-btns { display: flex; gap: 8px; flex-wrap: wrap; }
        .btn-ctrl {
            background: #f8fafc;
            color: #334155;
            border: 1px solid #cbd5e1;
            padding: 9px 14px;
            border-radius: 9px;
            font-size: 13px;
            font-weight: 700;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 6px;
            transition: all 0.16s;
        }
        .btn-ctrl:hover { background: #f1f5f9; color: #0f172a; }
        .btn-ctrl-primary {
            background: #0d9488;
            color: #ffffff;
            border-color: #0f766e;
        }
        .btn-ctrl-primary:hover { background: #0f766e; color: #ffffff; }

        /* Guía de Ítems */
        .items-legend {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
            gap: 8px;
            margin-top: 14px;
        }
        .legend-pill {
            background: #f8fafc;
            border: 1px solid #e2e8f0;
            border-radius: 10px;
            padding: 8px 11px;
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 12px;
        }
        .legend-pill b { display: block; color: #0f172a; font-size: 12px; }
        .legend-pill span { color: #64748b; font-size: 11px; }

        /* Columna Derecha: Leaderboard */
        .leaderboard-card {
            background: #ffffff;
            border-radius: 16px;
            padding: 20px;
            border: 1px solid #e2e8f0;
            box-shadow: 0 4px 20px -4px rgba(15, 23, 42, 0.06);
        }
        .lb-header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding-bottom: 12px;
            margin-bottom: 12px;
            border-bottom: 1px solid #f1f5f9;
        }
        .lb-header h2 {
            margin: 0;
            font-size: 15px;
            font-weight: 800;
            color: #0f172a;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .lb-badge {
            font-size: 11px;
            font-weight: 700;
            background: #f0fdfa;
            color: #0f766e;
            border: 1px solid #99f6e4;
            padding: 3px 8px;
            border-radius: 999px;
        }

        .rank-list { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 6px; }
        .rank-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 9px 12px;
            border-radius: 10px;
            background: #f8fafc;
            border: 1px solid #f1f5f9;
            font-size: 13px;
            font-weight: 600;
            color: #334155;
        }
        .rank-item.me {
            background: #f0fdfa;
            border-color: #99f6e4;
            color: #0f766e;
            font-weight: 800;
        }
        .rank-1 { background: #fffbeb; border-color: #fde68a; color: #92400e; font-weight: 800; }
        .rank-2 { background: #f8fafc; border-color: #cbd5e1; color: #1e293b; font-weight: 700; }
        .rank-3 { background: #fff7ed; border-color: #fed7aa; color: #9a3412; font-weight: 700; }
        .rank-score {
            font-variant-numeric: tabular-nums;
            font-weight: 800;
            color: #0f172a;
            background: #ffffff;
            padding: 3px 8px;
            border-radius: 6px;
            border: 1px solid #e2e8f0;
            font-size: 12px;
        }
    </style>
    <link rel="stylesheet" href="css/transmetro.css">
</head>
<body>
    <jsp:include page="menu_izquierdo.jsp" />
    <jsp:include page="menu_derecho.jsp" />
    <div id="overlay" class="overlay" onclick="closeAllMenus()"></div>

    <div class="header">
        <button class="menu-btn" onclick="toggleMenu('left')">☰</button>
        <h1>🎮 Transmetro Rush &amp; Fly</h1>
        <% if ("admin".equals(rolActual)) { %>
            <button class="menu-btn" onclick="toggleMenu('right')">⚙️</button>
        <% } else { %>
            <div style="width: 38px;"></div>
        <% } %>
    </div>

    <%
        List<String[]> topJugadores = new ArrayList<>();
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPass);
                 Statement st = con.createStatement()) {
                try (ResultSet rs = st.executeQuery(
                        "SELECT nombre_usuario, MAX(puntaje) AS max_score FROM ranking_juego GROUP BY nombre_usuario ORDER BY max_score DESC LIMIT 10")) {
                    while (rs.next()) {
                        String u = rs.getString("nombre_usuario");
                        int pts = rs.getInt("max_score");
                        topJugadores.add(new String[]{u, String.valueOf(pts)});
                        if (nombreUsuario.equalsIgnoreCase(u) && pts > miMejorPuntaje) {
                            miMejorPuntaje = pts;
                        }
                    }
                }
            }
        } catch (Exception e) {}
    %>

    <div class="main-container">
        <div class="top-bar">
            <a href="index.jsp" class="btn-volver">← Volver al Dashboard</a>
            <div style="font-size:12.5px; color:#64748b; font-weight:500;">
                Piloto en cabina: <b style="color:#0f172a;"><%= h(nombreUsuario) %></b>
            </div>
        </div>

        <!-- TELEMETRÍA EN TIEMPO REAL -->
        <div class="telemetry-row">
            <div class="tel-card">
                <div>
                    <div class="tel-label">Vidas de Unidad</div>
                    <div class="tel-val" id="uiLives">❤️❤️❤️</div>
                </div>
                <span style="font-size:22px;">🛡️</span>
            </div>
            <div class="tel-card">
                <div>
                    <div class="tel-label">Puntaje Actual</div>
                    <div class="tel-val" id="uiScore">0 pts</div>
                </div>
                <span style="font-size:22px;">🏅</span>
            </div>
            <div class="tel-card">
                <div>
                    <div class="tel-label">Tu Récord Personal</div>
                    <div class="tel-val" id="uiBest" data-best="<%= miMejorPuntaje %>"><%= miMejorPuntaje %> pts</div>
                </div>
                <span style="font-size:22px;">⭐</span>
            </div>
            <div class="tel-card">
                <div>
                    <div class="tel-label">Velocidad / Modo</div>
                    <div class="tel-val" id="uiMode" style="font-size:16px; color:#0d9488;">🟢 Carril Normal</div>
                </div>
                <span style="font-size:22px;" id="uiSpeed">60 km/h</span>
            </div>
        </div>

        <div class="arcade-grid">
            <!-- SECCIÓN DE JUEGO -->
            <div class="game-card">
                <div class="canvas-wrap">
                    <canvas id="gameCanvas" width="820" height="410"></canvas>
                </div>

                <div class="controls-bar">
                    <div class="control-btns">
                        <button type="button" class="btn-ctrl btn-ctrl-primary" onclick="jump()">⬆️ Saltar / Volar (Espacio)</button>
                        <button type="button" class="btn-ctrl" id="btnPause" onclick="togglePause()">⏸️ Pausar (P)</button>
                        <button type="button" class="btn-ctrl" id="btnSound" onclick="toggleSound()">🔊 Sonido: ON</button>
                    </div>
                    <button type="button" id="btnFullscreen" class="btn-ctrl">🔲 Pantalla Completa</button>
                </div>

                <!-- GUÍA DE ÍTEMS Y OBSTÁCULOS -->
                <div class="items-legend">
                    <div class="legend-pill">
                        <span style="font-size:20px;">🪽</span>
                        <div><b>Alas Transmetro</b><span>Modo vuelo por 8s</span></div>
                    </div>
                    <div class="legend-pill">
                        <span style="font-size:20px;">🥤</span>
                        <div><b>Bebida Turbo</b><span>Destruye obstáculos (+50)</span></div>
                    </div>
                    <div class="legend-pill">
                        <span style="font-size:20px;">❤️</span>
                        <div><b>Kit de Taller</b><span>Recupera +1 vida</span></div>
                    </div>
                    <div class="legend-pill">
                        <span style="font-size:20px;">🟤</span>
                        <div><b>Bache con Lodo</b><span>Ralentiza el carril</span></div>
                    </div>
                    <div class="legend-pill">
                        <span style="font-size:20px;">🚧</span>
                        <div><b>Vallas y Aves</b><span>Esquívalos saltando</span></div>
                    </div>
                </div>
            </div>

            <!-- SECCIÓN DE LEADERBOARD -->
            <div class="leaderboard-card">
                <div class="lb-header">
                    <h2><span>🏆</span><span>Top 10 Mundial</span></h2>
                    <span class="lb-badge">En Vivo</span>
                </div>
                <ul class="rank-list" id="listaRanking">
                    <%
                        int pos = 1;
                        for (String[] fila : topJugadores) {
                            String usr = fila[0];
                            String pts = fila[1];
                            String clase = (pos == 1) ? "rank-1" : (pos == 2) ? "rank-2" : (pos == 3) ? "rank-3" : "";
                            if (nombreUsuario.equalsIgnoreCase(usr)) clase += " me";
                            String medalla = (pos == 1) ? "🥇" : (pos == 2) ? "🥈" : (pos == 3) ? "🥉" : "#" + pos;
                    %>
                        <li class="rank-item <%= clase %>">
                            <span><%= medalla %> &nbsp;<%= h(usr) %></span>
                            <span class="rank-score"><%= h(pts) %> pts</span>
                        </li>
                    <%
                            pos++;
                        }
                        if (topJugadores.isEmpty()) {
                            out.print("<li class='rank-item' style='justify-content:center; color:#94a3b8;'>Aún no hay récords. ¡Inicia la carrera!</li>");
                        }
                    %>
                </ul>
            </div>
        </div>
    </div>

    <script>
        function toggleMenu(side) {
            let left = document.getElementById("leftSidebar");
            let right = document.getElementById("rightSidebar");
            let over = document.getElementById("overlay");
            if (side === 'left') { left.style.width = "250px"; if (right) right.style.width = "0"; }
            else if (side === 'right') { if (right) right.style.width = "300px"; left.style.width = "0"; }
            over.style.display = "block";
        }
        function closeAllMenus() {
            document.getElementById("leftSidebar").style.width = "0";
            let right = document.getElementById("rightSidebar");
            if (right) right.style.width = "0";
            document.getElementById("overlay").style.display = "none";
        }

        const canvas = document.getElementById('gameCanvas');
        const ctx = canvas.getContext('2d');
        const btnFullscreen = document.getElementById('btnFullscreen');

        btnFullscreen.addEventListener('click', () => {
            if (!document.fullscreenElement) {
                if (canvas.requestFullscreen) canvas.requestFullscreen();
                else if (canvas.webkitRequestFullscreen) canvas.webkitRequestFullscreen();
            } else if (document.exitFullscreen) {
                document.exitFullscreen();
            }
        });

        // Sintetizador ligero de efectos de sonido (Web Audio API sin archivos externos)
        let soundEnabled = true;
        let audioCtx = null;
        function playTone(freq, type, duration, vol = 0.08) {
            if (!soundEnabled) return;
            try {
                if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                osc.type = type || 'sine';
                osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
                gain.gain.setValueAtTime(vol, audioCtx.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration);
                osc.connect(gain);
                gain.connect(audioCtx.destination);
                osc.start();
                osc.stop(audioCtx.currentTime + duration);
            } catch (e) {}
        }
        function toggleSound() {
            soundEnabled = !soundEnabled;
            document.getElementById('btnSound').textContent = soundEnabled ? '🔊 Sonido: ON' : '🔇 Sonido: OFF';
        }

        const W = canvas.width;
        const H = canvas.height;
        const FLOOR_Y = 345;

        let gameRunning = false;
        let gamePaused = false;
        let gameOver = false;
        let score = 0;
        let bestScore = parseInt(document.getElementById('uiBest').getAttribute('data-best') || '0', 10);
        let frameCount = 0;
        let bgOffset = 0;
        let cityOffset = 0;
        let stationOffset = 520;
        let lives = 3;
        let gameSpeed = 5.2;

        const bus = {
            x: 65,
            y: 305,
            width: 52,
            height: 40,
            velocityY: 0,
            gravity: 0.52,
            jumpPower: -13.2,
            isJumping: false,
            isFlying: false,
            flyTimer: 0,
            isTurbo: false,
            turboTimer: 0,
            isMud: false,
            mudTimer: 0
        };

        let obstacles = [];
        let powerups = [];
        let particles = [];
        let floatingTexts = [];
        const clouds = [
            { x: 110, y: 55, s: 0.35, w: 68 },
            { x: 360, y: 82, s: 0.25, w: 54 },
            { x: 640, y: 48, s: 0.42, w: 76 }
        ];
        const buildings = [
            { x: 0, w: 75, h: 110 }, { x: 80, w: 60, h: 145 }, { x: 145, w: 90, h: 95 },
            { x: 240, w: 65, h: 160 }, { x: 310, w: 85, h: 120 }, { x: 400, w: 70, h: 140 },
            { x: 475, w: 95, h: 100 }, { x: 575, w: 65, h: 155 }, { x: 645, w: 80, h: 115 },
            { x: 730, w: 95, h: 135 }
        ];

        function addParticles(x, y, color, count) {
            for (let i = 0; i < count; i++) {
                particles.push({
                    x: x,
                    y: y,
                    vx: (Math.random() - 0.5) * 5 - 1.5,
                    vy: (Math.random() - 0.5) * 5,
                    r: Math.random() * 4 + 2,
                    alpha: 1,
                    color: color
                });
            }
        }

        function addFloatingText(text, x, y, color) {
            floatingTexts.push({ text, x, y, color: color || '#fbbf24', alpha: 1, dy: -1.4 });
        }

        function updateTelemetryUI() {
            document.getElementById('uiLives').textContent = '❤️'.repeat(Math.max(0, lives)) + '🖤'.repeat(Math.max(0, 3 - lives));
            document.getElementById('uiScore').textContent = score + ' pts';
            if (score > bestScore) {
                bestScore = score;
                document.getElementById('uiBest').textContent = bestScore + ' pts';
            }
            const curSpd = bus.isTurbo ? gameSpeed + 6 : (bus.isMud ? gameSpeed * 0.45 : gameSpeed);
            document.getElementById('uiSpeed').textContent = Math.round(curSpd * 11) + ' km/h';

            const modeEl = document.getElementById('uiMode');
            if (bus.isTurbo) {
                modeEl.textContent = '🔥 Turbo Invencible (' + Math.ceil(bus.turboTimer / 60) + 's)';
                modeEl.style.color = '#e11d48';
            } else if (bus.isFlying) {
                modeEl.textContent = '🪽 Modo Vuelo (' + Math.ceil(bus.flyTimer / 60) + 's)';
                modeEl.style.color = '#7c3aed';
            } else if (bus.isMud) {
                modeEl.textContent = '🟤 Atascado en Lodo';
                modeEl.style.color = '#b45309';
            } else {
                modeEl.textContent = '🟢 Carril Exclusivo';
                modeEl.style.color = '#0d9488';
            }
        }

        function resetGame() {
            bus.y = 305;
            bus.velocityY = 0;
            bus.isJumping = false;
            bus.isFlying = false;
            bus.flyTimer = 0;
            bus.isTurbo = false;
            bus.turboTimer = 0;
            bus.isMud = false;
            bus.mudTimer = 0;
            obstacles = [];
            powerups = [];
            particles = [];
            floatingTexts = [];
            score = 0;
            lives = 3;
            gameSpeed = 5.2;
            frameCount = 0;
            bgOffset = 0;
            gameOver = false;
            gamePaused = false;
            gameRunning = true;
            document.getElementById('btnPause').textContent = '⏸️ Pausar (P)';
            updateTelemetryUI();
            playTone(440, 'triangle', 0.12);
            gameLoop();
        }

        function togglePause() {
            if (!gameRunning && !gamePaused) return;
            if (gameOver) return;
            gamePaused = !gamePaused;
            document.getElementById('btnPause').textContent = gamePaused ? '▶️ Reanudar (P)' : '⏸️ Pausar (P)';
            if (!gamePaused) {
                gameLoop();
            } else {
                draw();
            }
        }

        function jump() {
            if (!gameRunning && !gameOver) { resetGame(); return; }
            if (gameOver) { resetGame(); return; }
            if (gamePaused) { togglePause(); return; }

            if (bus.isFlying) {
                bus.velocityY = -7.8;
                addParticles(bus.x + 10, bus.y + 25, '#a78bfa', 5);
                playTone(580, 'sine', 0.09);
            } else if (!bus.isJumping) {
                bus.velocityY = bus.jumpPower;
                bus.isJumping = true;
                addParticles(bus.x + 15, FLOOR_Y, '#94a3b8', 6);
                playTone(360, 'triangle', 0.11);
            }
        }

        document.addEventListener('keydown', function(e) {
            if (e.code === 'Space' || e.code === 'ArrowUp') {
                e.preventDefault();
                jump();
            } else if (e.code === 'KeyP') {
                e.preventDefault();
                togglePause();
            }
        });
        canvas.addEventListener('mousedown', jump);
        canvas.addEventListener('touchstart', function(e) { e.preventDefault(); jump(); }, { passive: false });

        function update() {
            let currentGravity = bus.isFlying ? 0.38 : bus.gravity;
            bus.velocityY += currentGravity;
            bus.y += bus.velocityY;

            if (bus.y < 8) { bus.y = 8; bus.velocityY = 0; }
            if (bus.y > 305) { bus.y = 305; bus.velocityY = 0; bus.isJumping = false; }

            if (bus.isFlying) { bus.flyTimer--; if (bus.flyTimer <= 0) bus.isFlying = false; }
            if (bus.isTurbo) {
                bus.turboTimer--;
                if (frameCount % 2 === 0) addParticles(bus.x - 5, bus.y + 28, '#f97316', 2);
                if (bus.turboTimer <= 0) bus.isTurbo = false;
            }
            if (bus.isMud) { bus.mudTimer--; if (bus.mudTimer <= 0) bus.isMud = false; }

            let currentSpeed = bus.isTurbo ? gameSpeed + 6 : (bus.isMud ? gameSpeed * 0.42 : gameSpeed);

            bgOffset = (bgOffset + currentSpeed) % 60;
            cityOffset = (cityOffset + currentSpeed * 0.25) % W;
            stationOffset -= currentSpeed * 0.65;
            if (stationOffset < -180) stationOffset = W + 240;

            clouds.forEach(c => {
                c.x -= c.s + currentSpeed * 0.08;
                if (c.x + c.w < 0) c.x = W + 40;
            });

            let spawnRate = Math.max(44, 78 - Math.floor(gameSpeed * 3));
            if (frameCount % spawnRate === 0) {
                let rand = Math.random();
                if (rand < 0.20) {
                    obstacles.push({ type: 'mud', x: W + 20, y: 328, width: 48, height: 18 });
                } else if (rand < 0.46) {
                    let randomY = Math.random() * 185 + 45;
                    obstacles.push({ type: 'bird', x: W + 20, y: randomY, width: 34, height: 34 });
                } else if (rand < 0.72) {
                    obstacles.push({ type: 'double_cone', x: W + 20, y: 315, width: 58, height: 30 });
                } else {
                    obstacles.push({ type: 'cone', x: W + 20, y: 315, width: 30, height: 30 });
                }
            }

            if (frameCount > 0 && frameCount % 320 === 0) {
                let rand = Math.random();
                if (rand < 0.35 && !bus.isTurbo) {
                    powerups.push({ type: 'drink', x: W + 20, y: Math.random() * 140 + 100, width: 34, height: 34 });
                } else if (rand < 0.70 && !bus.isFlying) {
                    powerups.push({ type: 'wings', x: W + 20, y: Math.random() * 140 + 100, width: 34, height: 34 });
                } else if (lives < 3) {
                    powerups.push({ type: 'heart', x: W + 20, y: Math.random() * 140 + 100, width: 34, height: 34 });
                }
            }

            let hitX = bus.x + 6;
            let hitY = bus.y + 6;
            let hitW = bus.width - 12;
            let hitH = bus.height - 10;

            for (let i = 0; i < obstacles.length; i++) {
                let obs = obstacles[i];
                let speedBoost = (obs.type === 'bird') ? 1.4 : 0;
                obs.x -= (currentSpeed + speedBoost);

                if (hitX < obs.x + obs.width - 5 && hitX + hitW > obs.x + 5 &&
                    hitY < obs.y + obs.height - 5 && hitY + hitH > obs.y + 5) {

                    if (obs.type === 'mud') {
                        bus.isMud = true;
                        bus.mudTimer = 175;
                        addParticles(bus.x + 20, FLOOR_Y, '#78350f', 12);
                        addFloatingText('¡LODO! Carril Lento', bus.x, bus.y - 10, '#d97706');
                        playTone(150, 'sawtooth', 0.16);
                        obstacles.splice(i, 1);
                        i--;
                    } else if (bus.isTurbo) {
                        score += 50;
                        addParticles(obs.x, obs.y + 15, '#fbbf24', 14);
                        addFloatingText('+50 ¡DESTRUIDO!', obs.x - 20, obs.y, '#fbbf24');
                        playTone(520, 'square', 0.1);
                        obstacles.splice(i, 1);
                        i--;
                    } else {
                        lives--;
                        addParticles(bus.x + 20, bus.y + 20, '#ef4444', 16);
                        addFloatingText('-1 VIDA', bus.x, bus.y - 12, '#ef4444');
                        playTone(180, 'sawtooth', 0.22);
                        obstacles.splice(i, 1);
                        i--;
                        if (lives <= 0) {
                            endGame();
                            return;
                        }
                    }
                }
            }

            for (let i = 0; i < powerups.length; i++) {
                let p = powerups[i];
                p.x -= currentSpeed;
                if (hitX < p.x + p.width && hitX + hitW > p.x && hitY < p.y + p.height && hitY + hitH > p.y) {
                    if (p.type === 'wings') {
                        bus.isFlying = true;
                        bus.flyTimer = 480;
                        addParticles(bus.x + 20, bus.y + 20, '#a78bfa', 15);
                        addFloatingText('🪽 ¡MODO VUELO!', bus.x, bus.y - 15, '#c4b5fd');
                        playTone(660, 'sine', 0.18);
                    } else if (p.type === 'drink') {
                        bus.isTurbo = true;
                        bus.turboTimer = 380;
                        addParticles(bus.x + 20, bus.y + 20, '#f97316', 18);
                        addFloatingText('🔥 ¡TURBO INVENCIBLE!', bus.x, bus.y - 15, '#fde047');
                        playTone(740, 'triangle', 0.2);
                    } else if (p.type === 'heart') {
                        if (lives < 3) lives++;
                        addParticles(bus.x + 20, bus.y + 20, '#10b981', 14);
                        addFloatingText('❤️ +1 VIDA', bus.x, bus.y - 15, '#34d399');
                        playTone(820, 'sine', 0.18);
                    }
                    powerups.splice(i, 1);
                    i--;
                }
            }

            obstacles = obstacles.filter(obs => obs.x + obs.width > -20);
            powerups = powerups.filter(p => p.x + p.width > -20);

            particles.forEach(pt => {
                pt.x += pt.vx;
                pt.y += pt.vy;
                pt.alpha -= 0.03;
            });
            particles = particles.filter(pt => pt.alpha > 0);

            floatingTexts.forEach(ft => {
                ft.y += ft.dy;
                ft.alpha -= 0.022;
            });
            floatingTexts = floatingTexts.filter(ft => ft.alpha > 0);

            score += bus.isTurbo ? 2 : 1;
            if (score % 500 === 0) gameSpeed += 0.45;
            frameCount++;

            if (frameCount % 4 === 0) updateTelemetryUI();
        }

        function drawEmoji(emoji, x, y, size) {
            ctx.font = size + 'px "Segoe UI Emoji", "Apple Color Emoji", Arial';
            ctx.fillText(emoji, x, y);
        }

        function drawBackground() {
            // Cielo degradado minimalista
            const skyGrad = ctx.createLinearGradient(0, 0, 0, FLOOR_Y);
            if (bus.isTurbo) {
                skyGrad.addColorStop(0, '#450a0a');
                skyGrad.addColorStop(1, '#991b1b');
            } else if (bus.isFlying) {
                skyGrad.addColorStop(0, '#1e1b4b');
                skyGrad.addColorStop(1, '#4338ca');
            } else {
                skyGrad.addColorStop(0, '#0f172a');
                skyGrad.addColorStop(0.55, '#1e293b');
                skyGrad.addColorStop(1, '#334155');
            }
            ctx.fillStyle = skyGrad;
            ctx.fillRect(0, 0, W, FLOOR_Y);

            // Nubes suaves
            ctx.fillStyle = 'rgba(255, 255, 255, 0.08)';
            clouds.forEach(c => {
                ctx.beginPath();
                if (ctx.roundRect) ctx.roundRect(c.x, c.y, c.w, 18, 9);
                else ctx.rect(c.x, c.y, c.w, 18);
                ctx.fill();
            });

            // Silueta urbana en paralaje
            ctx.fillStyle = 'rgba(15, 23, 42, 0.55)';
            buildings.forEach(b => {
                let bx = (b.x - cityOffset + W) % W;
                ctx.fillRect(bx, FLOOR_Y - b.h, b.w, b.h);
            });

            // Estación Transmetro de fondo
            ctx.fillStyle = 'rgba(13, 148, 136, 0.28)';
            ctx.fillRect(stationOffset, FLOOR_Y - 58, 135, 58);
            ctx.fillStyle = '#14b8a6';
            ctx.fillRect(stationOffset - 6, FLOOR_Y - 64, 147, 7);
            ctx.fillStyle = '#e2e8f0';
            ctx.font = '700 10px Inter, sans-serif';
            ctx.fillText('🚏 ESTACIÓN TRANSMETRO', stationOffset + 6, FLOOR_Y - 40);

            // Carril exclusivo BRT
            ctx.fillStyle = '#0f172a';
            ctx.fillRect(0, FLOOR_Y, W, H - FLOOR_Y);

            // Franja verde esmeralda del carril exclusivo
            ctx.fillStyle = '#0d9488';
            ctx.fillRect(0, FLOOR_Y, W, 5);

            // Líneas discontinuas del carril
            ctx.fillStyle = '#fbbf24';
            for (let i = 0; i < 18; i++) {
                let lineX = (i * 60) - bgOffset;
                ctx.fillRect(lineX, FLOOR_Y + 26, 32, 4);
            }
        }

        function draw() {
            drawBackground();

            // Powerups
            for (let i = 0; i < powerups.length; i++) {
                const p = powerups[i];
                ctx.save();
                ctx.beginPath();
                ctx.arc(p.x + 17, p.y + 15, 20, 0, Math.PI * 2);
                ctx.fillStyle = 'rgba(255, 255, 255, 0.12)';
                ctx.fill();
                ctx.restore();

                if (p.type === 'wings') drawEmoji('🪽', p.x, p.y + 26, 32);
                if (p.type === 'drink') drawEmoji('🥤', p.x, p.y + 26, 32);
                if (p.type === 'heart') drawEmoji('❤️', p.x, p.y + 26, 32);
            }

            // Partículas
            particles.forEach(pt => {
                ctx.save();
                ctx.globalAlpha = Math.max(0, pt.alpha);
                ctx.fillStyle = pt.color;
                ctx.beginPath();
                ctx.arc(pt.x, pt.y, pt.r, 0, Math.PI * 2);
                ctx.fill();
                ctx.restore();
            });

            // Unidad Transmetro
            if (bus.isFlying && !bus.isTurbo) {
                drawEmoji('🪽', bus.x - 16, bus.y + 20, 26);
            }
            if (bus.isTurbo) {
                drawEmoji('🔥', bus.x - 28, bus.y + 34, 30);
            }
            drawEmoji('🚍', bus.x, bus.y + 35, 45);

            // Obstáculos
            for (let i = 0; i < obstacles.length; i++) {
                const obs = obstacles[i];
                if (obs.type === 'bird') {
                    drawEmoji('🦅', obs.x, obs.y + 26, 33);
                } else if (obs.type === 'double_cone') {
                    drawEmoji('🚧🚧', obs.x, obs.y + 25, 28);
                } else if (obs.type === 'mud') {
                    ctx.fillStyle = '#78350f';
                    ctx.beginPath();
                    ctx.ellipse(obs.x + 22, obs.y + 12, 25, 8, 0, 0, Math.PI * 2);
                    ctx.fill();
                    ctx.strokeStyle = '#92400e';
                    ctx.lineWidth = 2;
                    ctx.stroke();
                } else {
                    drawEmoji('🚧', obs.x, obs.y + 25, 29);
                }
            }

            // Textos flotantes
            floatingTexts.forEach(ft => {
                ctx.save();
                ctx.globalAlpha = Math.max(0, ft.alpha);
                ctx.fillStyle = ft.color;
                ctx.font = '800 16px Inter, sans-serif';
                ctx.fillText(ft.text, ft.x, ft.y);
                ctx.restore();
            });

            // HUD interno minimalista en el canvas
            ctx.fillStyle = 'rgba(15, 23, 42, 0.65)';
            ctx.beginPath();
            if (ctx.roundRect) ctx.roundRect(14, 12, 165, 34, 8);
            else ctx.rect(14, 12, 165, 34);
            ctx.fill();
            ctx.fillStyle = '#ffffff';
            ctx.font = '700 14px Inter, sans-serif';
            ctx.fillText('Puntos: ' + score, 26, 34);

            // Overlay Inicio
            if (!gameRunning && !gameOver) {
                ctx.fillStyle = 'rgba(15, 23, 42, 0.78)';
                ctx.fillRect(0, 0, W, H);

                ctx.fillStyle = '#14b8a6';
                ctx.font = '900 30px Inter, sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText('🚍 TRANSMETRO RUSH & FLY', W / 2, H / 2 - 22);

                ctx.fillStyle = '#e2e8f0';
                ctx.font = '600 16px Inter, sans-serif';
                ctx.fillText('Presiona ESPACIO o haz clic aquí para iniciar tu recorrido', W / 2, H / 2 + 16);
                ctx.textAlign = 'left';
            }

            // Overlay Pausa
            if (gamePaused && !gameOver) {
                ctx.fillStyle = 'rgba(15, 23, 42, 0.72)';
                ctx.fillRect(0, 0, W, H);
                ctx.fillStyle = '#ffffff';
                ctx.font = '900 32px Inter, sans-serif';
                ctx.textAlign = 'center';
                ctx.fillText('⏸️ JUEGO EN PAUSA', W / 2, H / 2 - 6);
                ctx.font = '500 15px Inter, sans-serif';
                ctx.fillStyle = '#94a3b8';
                ctx.fillText('Presiona P o haz clic en el carril para continuar', W / 2, H / 2 + 24);
                ctx.textAlign = 'left';
            }
        }

        function endGame() {
            gameRunning = false;
            gameOver = true;
            updateTelemetryUI();
            draw();

            ctx.fillStyle = 'rgba(15, 23, 42, 0.85)';
            ctx.fillRect(0, 0, W, H);

            ctx.textAlign = 'center';
            ctx.fillStyle = '#f43f5e';
            ctx.font = '900 36px Inter, sans-serif';
            ctx.fillText('¡RECORRIDO FINALIZADO!', W / 2, H / 2 - 30);

            ctx.fillStyle = '#ffffff';
            ctx.font = '700 20px Inter, sans-serif';
            ctx.fillText('Puntaje obtenido: ' + score + ' pts', W / 2, H / 2 + 6);

            ctx.fillStyle = '#94a3b8';
            ctx.font = '600 14px Inter, sans-serif';
            ctx.fillText('Puntaje registrado en el ranking. Presiona ESPACIO o toca para jugar de nuevo.', W / 2, H / 2 + 38);
            ctx.textAlign = 'left';

            fetch('juego.jsp', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: 'accion=guardar_score&score=' + score
            });
        }

        function gameLoop() {
            if (!gameRunning || gamePaused) return;
            update();
            if (!gameOver) {
                draw();
                requestAnimationFrame(gameLoop);
            }
        }

        draw();
    </script>
</body>
</html>
