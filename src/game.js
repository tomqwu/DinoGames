// Dino Adventure — canvas game engine
// Physics, obstacles, coins, powerups, combo system, and day/night rendering.

const GROUND_Y_RATIO = 0.82;
const BASE_SPEED = 6.5;
const GRAVITY = 0.85;
const JUMP_VELOCITY = -16;
const DUCK_GRAVITY_BOOST = 1.6;
const COMBO_WINDOW_FRAMES = 120;          // ~2s at 60fps
const POWERUP_DURATION_FRAMES = 6 * 60;   // 6s
const COIN_VALUE = 5;                     // score per coin

const DIFFICULTY = {
  easy:   { speedMul: 0.85, gapMul: 1.25, growth: 0.0010 },
  normal: { speedMul: 1.00, gapMul: 1.00, growth: 0.0015 },
  hard:   { speedMul: 1.15, gapMul: 0.85, growth: 0.0022 },
};

export const POWERUP_TYPES = ["shield", "magnet", "slowmo"];

export class DinoGame {
  constructor(canvas, opts = {}) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.opts = opts;
    this.onGameOver = opts.onGameOver || (() => {});
    this.onScore = opts.onScore || (() => {});
    this.onStats = opts.onStats || (() => {});  // emits live run stats
    this.onEvent = opts.onEvent || (() => {});  // events: jump, slide-clear, coin, powerup, combo
    this.sfx = opts.sfx;

    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    this._resize = this._resize.bind(this);
    window.addEventListener("resize", this._resize);
    this._resize();

    this.reset();
  }

  setDifficulty(level) {
    this.difficulty = DIFFICULTY[level] || DIFFICULTY.normal;
  }

  reset() {
    this.difficulty = this.difficulty || DIFFICULTY.normal;
    this.state = "idle";
    this.score = 0;
    this.distance = 0;
    this.speed = BASE_SPEED * this.difficulty.speedMul;
    this.frame = 0;

    this.spawnTimer = 0;
    this.nextSpawnIn = 60;
    this.coinSpawnTimer = 0;
    this.nextCoinIn = 90 + Math.floor(Math.random() * 90);
    this.powerupSpawnTimer = 0;
    this.nextPowerupIn = 9 * 60 + Math.floor(Math.random() * 6 * 60);

    this.obstacles = [];
    this.coins = [];
    this.powerups = [];
    this.particles = [];
    this.toasts = [];

    this.clouds = this._initClouds();
    this.parallax = { far: 0, mid: 0, near: 0 };

    this.combo = 0;
    this.comboTimer = 0;
    this.activePowerups = { shield: 0, magnet: 0, slowmo: 0 };

    // Per-run stats — exposed via onStats / onGameOver
    this.stats = {
      score: 0,
      coins: 0,
      jumps: 0,
      slides: 0,
      cactiCleared: 0,
      pteroCleared: 0,
      rocksCleared: 0,
      powerupsCollected: 0,
      maxCombo: 0,
      survivedFrames: 0,
    };

    const w = this.canvas.width / this.dpr;
    const h = this.canvas.height / this.dpr;
    const groundY = h * GROUND_Y_RATIO;

    this.dino = {
      x: w * 0.12,
      y: groundY,
      w: 60,
      h: 64,
      vy: 0,
      onGround: true,
      ducking: false,
      runFrame: 0,
    };
    this.groundY = groundY;
  }

  start() {
    if (this.state !== "running") {
      this.state = "running";
      this._loop();
    }
  }
  pause() { if (this.state === "running") this.state = "paused"; }
  resume() {
    if (this.state === "paused") {
      this.state = "running";
      this._loop();
    }
  }
  stop() { this.state = "over"; }
  destroy() {
    window.removeEventListener("resize", this._resize);
    this.state = "destroyed";
  }

  jump() {
    if (this.state !== "running") return;
    if (this.dino.onGround) {
      this.dino.vy = JUMP_VELOCITY;
      this.dino.onGround = false;
      this.dino.ducking = false;
      this.stats.jumps++;
      this.sfx?.play("jump");
      this.onEvent("jump");
      this.onStats(this.stats);
    }
  }

  duck(active) {
    if (this.state !== "running") return;
    const prev = this.dino.ducking;
    this.dino.ducking = !!active;
    if (!prev && active && this.dino.onGround) {
      this.stats.slides++;
      this.onEvent("slide");
      this.onStats(this.stats);
    }
  }

  hasPowerup(name) { return (this.activePowerups[name] || 0) > 0; }

  _resize() {
    const cssW = this.canvas.clientWidth || window.innerWidth;
    const cssH = this.canvas.clientHeight || window.innerHeight;
    this.canvas.width = Math.floor(cssW * this.dpr);
    this.canvas.height = Math.floor(cssH * this.dpr);
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    if (this.dino) {
      const h = this.canvas.height / this.dpr;
      this.groundY = h * GROUND_Y_RATIO;
      if (this.dino.onGround) this.dino.y = this.groundY;
    }
  }

  _initClouds() {
    const w = this.canvas.width / this.dpr;
    const arr = [];
    for (let i = 0; i < 6; i++) {
      arr.push({
        x: Math.random() * w,
        y: 40 + Math.random() * 140,
        s: 0.4 + Math.random() * 0.6,
        speed: 0.3 + Math.random() * 0.5,
      });
    }
    return arr;
  }

  _loop() {
    if (this.state !== "running") return;
    this._update();
    this._draw();
    this.frame++;
    requestAnimationFrame(() => this._loop());
  }

  _update() {
    const w = this.canvas.width / this.dpr;
    const d = this.dino;

    // Speed ramps over time (scaled by difficulty) — slowed under slow-mo
    const slow = this.activePowerups.slowmo > 0 ? 0.55 : 1.0;
    this.speed += this.difficulty.growth;
    const effSpeed = this.speed * slow;

    this.distance += effSpeed;
    const newScore = Math.floor(this.distance / 5);
    if (newScore !== this.score) {
      if (newScore > 0 && newScore % 100 === 0) this.sfx?.play("milestone");
      this.score = newScore;
      this.stats.score = newScore;
      this.onScore(this.score, this.combo);
      this.onStats(this.stats);
    }

    this.stats.survivedFrames++;
    // Tick survive mission once per second
    if (this.stats.survivedFrames % 60 === 0) this.onStats(this.stats);

    // Combo timer
    if (this.combo > 0) {
      this.comboTimer--;
      if (this.comboTimer <= 0) this.combo = 0;
    }

    // Powerup timers
    for (const k of POWERUP_TYPES) {
      if (this.activePowerups[k] > 0) {
        this.activePowerups[k]--;
        if (this.activePowerups[k] === 0) this.onEvent("powerup-expired", { type: k });
      }
    }

    // Dino physics
    d.vy += GRAVITY * (d.ducking && !d.onGround ? DUCK_GRAVITY_BOOST : 1);
    d.y += d.vy;
    if (d.y >= this.groundY) {
      d.y = this.groundY;
      d.vy = 0;
      d.onGround = true;
    }
    d.runFrame = (d.runFrame + effSpeed * 0.05) % 2;

    // Parallax
    this.parallax.far = (this.parallax.far + effSpeed * 0.15) % w;
    this.parallax.mid = (this.parallax.mid + effSpeed * 0.4) % w;
    this.parallax.near = (this.parallax.near + effSpeed) % w;

    // Clouds
    for (const c of this.clouds) {
      c.x -= c.speed;
      if (c.x < -80) {
        c.x = w + 40;
        c.y = 40 + Math.random() * 140;
        c.s = 0.4 + Math.random() * 0.6;
      }
    }

    // Spawn obstacles
    this.spawnTimer++;
    if (this.spawnTimer >= this.nextSpawnIn) {
      this._spawnObstacle();
      this.spawnTimer = 0;
      const minGap = 50 / this.difficulty.gapMul;
      const maxGap = 110 / this.difficulty.gapMul;
      const speedFactor = Math.max(0.6, 1 - (this.speed - BASE_SPEED) * 0.04);
      this.nextSpawnIn = Math.floor((minGap + Math.random() * (maxGap - minGap)) * speedFactor);
    }

    // Spawn coins
    this.coinSpawnTimer++;
    if (this.coinSpawnTimer >= this.nextCoinIn) {
      this._spawnCoinArc();
      this.coinSpawnTimer = 0;
      this.nextCoinIn = 80 + Math.floor(Math.random() * 140);
    }

    // Spawn powerups
    this.powerupSpawnTimer++;
    if (this.powerupSpawnTimer >= this.nextPowerupIn) {
      this._spawnPowerup();
      this.powerupSpawnTimer = 0;
      this.nextPowerupIn = 10 * 60 + Math.floor(Math.random() * 8 * 60);
    }

    // Move + cull obstacles, track which scrolled past for combos
    for (const o of this.obstacles) {
      const wasAhead = o.x > d.x;
      o.x -= effSpeed;
      if (o.type === "ptero") o.flap = (o.flap + 0.2) % (Math.PI * 2);
      // count clears once obstacle scrolls past dino
      if (wasAhead && o.x + o.w < d.x && !o._counted) {
        o._counted = true;
        this._registerClear(o.type);
      }
    }
    this.obstacles = this.obstacles.filter(o => o.x + o.w > -20);

    // Move coins & magnet attraction
    const magnet = this.activePowerups.magnet > 0;
    for (const c of this.coins) {
      c.x -= effSpeed;
      c.spin += 0.18;
      if (magnet) {
        const dx = (d.x + 30) - c.x;
        const dy = (d.y - 30) - c.y;
        const dist = Math.hypot(dx, dy);
        if (dist < 240) {
          const pull = 4.5;
          c.x += (dx / dist) * pull;
          c.y += (dy / dist) * pull;
        }
      }
    }
    // Coin pickup
    const dinoBox = this._dinoBox();
    this.coins = this.coins.filter(c => {
      if (c.x < -30) return false;
      const r = 12;
      if (c.x > dinoBox.x - r && c.x < dinoBox.x + dinoBox.w + r &&
          c.y > dinoBox.y - r && c.y < dinoBox.y + dinoBox.h + r) {
        this.stats.coins++;
        this.distance += COIN_VALUE * 5; // coins also tick score
        this._spawnParticles(c.x, c.y, "#f7c948", 8);
        this.sfx?.play("coin");
        this.onEvent("coin");
        this.onStats(this.stats);
        return false;
      }
      return true;
    });

    // Move powerups & pickup
    this.powerups = this.powerups.filter(p => {
      p.x -= effSpeed;
      p.bob += 0.12;
      if (p.x < -40) return false;
      const pBox = { x: p.x - 16, y: p.y - 16, w: 32, h: 32 };
      if (this._intersect(dinoBox, pBox)) {
        this.activePowerups[p.type] = POWERUP_DURATION_FRAMES;
        this.stats.powerupsCollected++;
        this._spawnParticles(p.x, p.y, p.color, 14);
        this.sfx?.play("powerup");
        this.onEvent("powerup", { type: p.type });
        this.onStats(this.stats);
        return false;
      }
      return true;
    });

    // Particles
    for (const p of this.particles) {
      p.x += p.vx; p.y += p.vy;
      p.vy += 0.25;
      p.life--;
    }
    this.particles = this.particles.filter(p => p.life > 0);

    // Toasts
    for (const t of this.toasts) t.life--;
    this.toasts = this.toasts.filter(t => t.life > 0);

    // Collisions with obstacles
    for (const o of this.obstacles) {
      if (this._intersect(dinoBox, o)) {
        if (this.activePowerups.shield > 0) {
          // consume shield, destroy obstacle
          this.activePowerups.shield = 0;
          this._spawnParticles(o.x + o.w / 2, o.y + o.h / 2, "#6cc6ff", 18);
          this.sfx?.play("shield-break");
          this.onEvent("shield-break");
          this.obstacles = this.obstacles.filter(x => x !== o);
          continue;
        }
        this._gameOver();
        return;
      }
    }
  }

  _registerClear(type) {
    if (type.startsWith("cactus")) this.stats.cactiCleared++;
    else if (type === "rock") this.stats.rocksCleared++;
    else if (type === "ptero") this.stats.pteroCleared++;
    this.combo++;
    this.comboTimer = COMBO_WINDOW_FRAMES;
    if (this.combo > this.stats.maxCombo) this.stats.maxCombo = this.combo;
    if (this.combo >= 2) {
      this.distance += this.combo * 8; // combo bonus
      this.onEvent("combo", { combo: this.combo });
      if (this.combo === 5 || this.combo === 10 || this.combo === 20) {
        this.sfx?.play("milestone");
      }
    }
    this.onStats(this.stats);
  }

  _dinoBox() {
    const d = this.dino;
    if (d.ducking && d.onGround) {
      return { x: d.x + 6, y: d.y - 32, w: 70, h: 32 };
    }
    return { x: d.x + 8, y: d.y - d.h, w: d.w - 16, h: d.h };
  }

  _intersect(a, b) {
    return a.x < b.x + b.w && a.x + a.w > b.x &&
           a.y < b.y + b.h && a.y + a.h > b.y;
  }

  _spawnObstacle() {
    const types = ["cactus-s", "cactus-m", "cactus-l", "rock"];
    if (this.score > 200) types.push("ptero");
    const t = types[Math.floor(Math.random() * types.length)];
    const w = this.canvas.width / this.dpr;
    let obs;
    switch (t) {
      case "cactus-s": obs = { type: t, x: w + 20, y: this.groundY - 36, w: 22, h: 36 }; break;
      case "cactus-m": obs = { type: t, x: w + 20, y: this.groundY - 50, w: 28, h: 50 }; break;
      case "cactus-l": obs = { type: t, x: w + 20, y: this.groundY - 64, w: 36, h: 64 }; break;
      case "rock":     obs = { type: t, x: w + 20, y: this.groundY - 24, w: 44, h: 24 }; break;
      case "ptero": {
        const heights = [this.groundY - 80, this.groundY - 50];
        const py = heights[Math.floor(Math.random() * heights.length)];
        obs = { type: t, x: w + 20, y: py, w: 50, h: 28, flap: 0 };
        break;
      }
    }
    this.obstacles.push(obs);
  }

  _spawnCoinArc() {
    const w = this.canvas.width / this.dpr;
    const count = 3 + Math.floor(Math.random() * 4);
    const startX = w + 30;
    const apex = this.groundY - (90 + Math.random() * 80);
    const span = 28; // px between coins
    for (let i = 0; i < count; i++) {
      const t = i / (count - 1 || 1);
      const x = startX + i * span;
      // arc: y = lerp(ground - 30, apex, sin(t*pi))
      const y = this.groundY - 30 - (apex - (this.groundY - 30)) * (-Math.sin(t * Math.PI));
      this.coins.push({ x, y, spin: Math.random() * Math.PI * 2 });
    }
  }

  _spawnPowerup() {
    const w = this.canvas.width / this.dpr;
    const type = POWERUP_TYPES[Math.floor(Math.random() * POWERUP_TYPES.length)];
    const colorMap = { shield: "#6cc6ff", magnet: "#f7c948", slowmo: "#b18cff" };
    const y = this.groundY - (70 + Math.random() * 60);
    this.powerups.push({ type, x: w + 30, y, bob: 0, color: colorMap[type] });
  }

  _spawnParticles(x, y, color, n) {
    for (let i = 0; i < n; i++) {
      this.particles.push({
        x, y,
        vx: (Math.random() - 0.5) * 6,
        vy: (Math.random() - 1) * 5,
        life: 30 + Math.floor(Math.random() * 20),
        color,
      });
    }
  }

  _gameOver() {
    if (this.state === "over") return;
    this.state = "over";
    this.sfx?.play("hit");
    this._draw(true);
    this.onGameOver({ ...this.stats });
  }

  // ===== Rendering =====
  _draw(dead = false) {
    const ctx = this.ctx;
    const w = this.canvas.width / this.dpr;
    const h = this.canvas.height / this.dpr;

    // Day/night blend based on score
    const phase = (this.score % 1000) / 1000; // 0..1 within cycle
    const night = Math.max(0, Math.min(1, Math.abs(phase - 0.5) * 2 - 0.4)); // 0..1
    this._drawSky(w, h, night);

    // Sun / moon
    const celestX = w * 0.78, celestY = h * 0.18;
    if (night < 0.5) {
      ctx.fillStyle = "rgba(255, 245, 220, 0.9)";
      ctx.beginPath(); ctx.arc(celestX, celestY, 28, 0, Math.PI * 2); ctx.fill();
    } else {
      ctx.fillStyle = "rgba(230, 230, 240, 0.9)";
      ctx.beginPath(); ctx.arc(celestX, celestY, 24, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = "rgba(70,70,90,0.6)";
      ctx.beginPath(); ctx.arc(celestX - 6, celestY - 4, 6, 0, Math.PI * 2); ctx.fill();
      ctx.beginPath(); ctx.arc(celestX + 4, celestY + 6, 4, 0, Math.PI * 2); ctx.fill();
    }

    // Mountains (far)
    this._drawMountains(w, h, this._tint("#7a8896", "#3b4452", night), -this.parallax.far * 0.3, 140, 0.6);
    this._drawMountains(w, h, this._tint("#5b6a78", "#27313e", night), -this.parallax.far * 0.6, 100, 0.85);

    // Trees (mid)
    this._drawTrees(w, h, -this.parallax.mid, this._tint("#39553a", "#1b2c1d", night), 0);
    this._drawTrees(w, h, -this.parallax.mid * 1.2 + 60, this._tint("#2c4530", "#142016", night), 12);

    // Clouds
    ctx.fillStyle = night > 0.4 ? "rgba(180,180,210,0.5)" : "rgba(255,255,255,0.85)";
    for (const c of this.clouds) this._drawCloud(c.x, c.y, c.s);

    // Ground
    this._drawGround(w, h, night);

    // Coins (behind dino but in front of ground)
    for (const c of this.coins) this._drawCoin(c);

    // Powerups
    for (const p of this.powerups) this._drawPowerup(p);

    // Obstacles
    for (const o of this.obstacles) this._drawObstacle(o);

    // Dino
    this._drawDino(dead);

    // Slow-mo overlay tint
    if (this.activePowerups.slowmo > 0) {
      ctx.fillStyle = "rgba(177,140,255,0.10)";
      ctx.fillRect(0, 0, w, h);
    }

    // Particles
    for (const p of this.particles) {
      ctx.globalAlpha = Math.max(0, p.life / 50);
      ctx.fillStyle = p.color;
      ctx.fillRect(p.x, p.y, 3, 3);
    }
    ctx.globalAlpha = 1;

    // Combo indicator (centered above dino)
    if (this.combo >= 2) {
      ctx.save();
      ctx.font = "700 22px -apple-system, system-ui, sans-serif";
      ctx.textAlign = "center";
      ctx.fillStyle = "rgba(0,0,0,0.5)";
      ctx.fillText(`x${this.combo} COMBO`, this.dino.x + 30, this.dino.y - this.dino.h - 16 + 2);
      ctx.fillStyle = "#ffd35a";
      ctx.fillText(`x${this.combo} COMBO`, this.dino.x + 30, this.dino.y - this.dino.h - 16);
      ctx.restore();
    }
  }

  _tint(dayHex, nightHex, t) {
    const a = this._hexToRgb(dayHex);
    const b = this._hexToRgb(nightHex);
    const r = Math.round(a.r + (b.r - a.r) * t);
    const g = Math.round(a.g + (b.g - a.g) * t);
    const bl = Math.round(a.b + (b.b - a.b) * t);
    return `rgb(${r},${g},${bl})`;
  }
  _hexToRgb(hex) {
    const v = hex.replace("#", "");
    return {
      r: parseInt(v.substring(0, 2), 16),
      g: parseInt(v.substring(2, 4), 16),
      b: parseInt(v.substring(4, 6), 16),
    };
  }

  _drawSky(w, h, night) {
    const ctx = this.ctx;
    const sky = ctx.createLinearGradient(0, 0, 0, this.groundY);
    if (night < 0.5) {
      sky.addColorStop(0, "#7fb3d9");
      sky.addColorStop(0.6, "#b6d4e6");
      sky.addColorStop(1, "#dbe6e1");
    } else {
      sky.addColorStop(0, "#1b2347");
      sky.addColorStop(0.6, "#2a3360");
      sky.addColorStop(1, "#3a4170");
    }
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, w, this.groundY);
    if (night > 0.5) {
      // stars
      ctx.fillStyle = "rgba(255,255,255,0.85)";
      for (let i = 0; i < 40; i++) {
        const sx = (i * 137) % w;
        const sy = (i * 71) % (this.groundY * 0.6);
        ctx.fillRect(sx, sy, 1.5, 1.5);
      }
    }
  }

  _drawMountains(w, h, color, offset, peakH, alpha) {
    const ctx = this.ctx;
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.fillStyle = color;
    const yBase = this.groundY - 4;
    const seg = 220;
    ctx.beginPath();
    ctx.moveTo(0, yBase);
    let x = (offset % seg);
    if (x > 0) x -= seg;
    for (; x < w + seg; x += seg) {
      ctx.lineTo(x + seg * 0.25, yBase - peakH * 0.6);
      ctx.lineTo(x + seg * 0.5, yBase - peakH);
      ctx.lineTo(x + seg * 0.75, yBase - peakH * 0.5);
      ctx.lineTo(x + seg, yBase);
    }
    ctx.lineTo(w, yBase);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  _drawTrees(w, h, offset, color, yJitter) {
    const ctx = this.ctx;
    ctx.fillStyle = color;
    const yBase = this.groundY - 2;
    const seg = 90;
    let x = offset % seg;
    if (x > 0) x -= seg;
    for (; x < w + seg; x += seg) {
      const peak = 60 + ((Math.sin(x * 0.13) + 1) * 18) + yJitter;
      ctx.beginPath();
      ctx.moveTo(x, yBase);
      ctx.lineTo(x + seg * 0.5, yBase - peak);
      ctx.lineTo(x + seg, yBase);
      ctx.closePath();
      ctx.fill();
    }
  }

  _drawCloud(x, y, s) {
    const ctx = this.ctx;
    ctx.beginPath();
    ctx.arc(x, y, 14 * s, 0, Math.PI * 2);
    ctx.arc(x + 16 * s, y - 6 * s, 16 * s, 0, Math.PI * 2);
    ctx.arc(x + 32 * s, y, 14 * s, 0, Math.PI * 2);
    ctx.arc(x + 16 * s, y + 4 * s, 12 * s, 0, Math.PI * 2);
    ctx.fill();
  }

  _drawGround(w, h, night) {
    const ctx = this.ctx;
    const dirt = ctx.createLinearGradient(0, this.groundY, 0, h);
    if (night < 0.5) {
      dirt.addColorStop(0, "#5a4a36");
      dirt.addColorStop(1, "#2d2418");
    } else {
      dirt.addColorStop(0, "#2c2418");
      dirt.addColorStop(1, "#15110b");
    }
    ctx.fillStyle = dirt;
    ctx.fillRect(0, this.groundY, w, h - this.groundY);
    ctx.fillStyle = this._tint("#3e5a32", "#1b2818", night);
    ctx.fillRect(0, this.groundY - 4, w, 6);
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    const off = -this.parallax.near;
    for (let i = 0; i < 40; i++) {
      const px = ((i * 73 + off) % (w + 60)) - 30;
      const py = this.groundY + 14 + ((i * 31) % 30);
      ctx.fillRect(px, py, 3, 2);
    }
  }

  _drawCoin(c) {
    const ctx = this.ctx;
    const sx = Math.abs(Math.cos(c.spin)); // 0..1 — flip illusion
    const r = 9;
    ctx.save();
    ctx.translate(c.x, c.y);
    ctx.scale(sx + 0.3, 1);
    ctx.fillStyle = "#f7c948";
    ctx.beginPath(); ctx.arc(0, 0, r, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#caa030";
    ctx.beginPath(); ctx.arc(0, 0, r * 0.6, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#fff3c4";
    ctx.fillRect(-1, -r * 0.5, 2, r);
    ctx.restore();
  }

  _drawPowerup(p) {
    const ctx = this.ctx;
    const bob = Math.sin(p.bob) * 4;
    ctx.save();
    ctx.translate(p.x, p.y + bob);
    // glow
    const grd = ctx.createRadialGradient(0, 0, 0, 0, 0, 22);
    grd.addColorStop(0, p.color + "");
    grd.addColorStop(1, p.color + "00");
    ctx.fillStyle = grd;
    ctx.globalAlpha = 0.6;
    ctx.beginPath(); ctx.arc(0, 0, 22, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = 1;
    // body
    ctx.fillStyle = p.color;
    ctx.beginPath(); ctx.arc(0, 0, 12, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#101319";
    ctx.font = "700 14px -apple-system, system-ui, sans-serif";
    ctx.textAlign = "center"; ctx.textBaseline = "middle";
    const glyph = p.type === "shield" ? "S" : p.type === "magnet" ? "M" : "T";
    ctx.fillText(glyph, 0, 1);
    ctx.restore();
  }

  _drawObstacle(o) {
    const ctx = this.ctx;
    if (o.type.startsWith("cactus")) {
      ctx.fillStyle = "#3f6b3a";
      ctx.fillRect(o.x + o.w / 2 - 5, o.y, 10, o.h);
      ctx.fillRect(o.x, o.y + o.h * 0.35, 6, o.h * 0.4);
      ctx.fillRect(o.x + o.w - 6, o.y + o.h * 0.25, 6, o.h * 0.4);
      ctx.fillStyle = "#2c4d2a";
      ctx.fillRect(o.x + o.w / 2 - 5, o.y + 6, 4, o.h - 12);
    } else if (o.type === "rock") {
      ctx.fillStyle = "#6e6960";
      ctx.beginPath();
      ctx.ellipse(o.x + o.w / 2, o.y + o.h, o.w / 2, o.h, 0, Math.PI, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#54504a";
      ctx.beginPath();
      ctx.ellipse(o.x + o.w * 0.4, o.y + o.h, o.w * 0.25, o.h * 0.6, 0, Math.PI, Math.PI * 2);
      ctx.fill();
    } else if (o.type === "ptero") {
      ctx.fillStyle = "#3a2f2a";
      const wingY = Math.sin(o.flap) * 6;
      ctx.fillRect(o.x + 14, o.y + 10, 26, 8);
      ctx.fillRect(o.x + 36, o.y + 6, 10, 8);
      ctx.fillRect(o.x + 44, o.y + 8, 4, 3);
      ctx.beginPath();
      ctx.moveTo(o.x + 14, o.y + 14);
      ctx.lineTo(o.x, o.y - 4 + wingY);
      ctx.lineTo(o.x + 22, o.y + 12);
      ctx.closePath();
      ctx.fill();
    }
  }

  _drawDino(dead = false) {
    const ctx = this.ctx;
    const d = this.dino;
    const ducking = d.ducking && d.onGround;
    const x = d.x;
    const y = d.y;
    const step = Math.floor(d.runFrame);

    // Shield aura
    if (this.activePowerups.shield > 0) {
      ctx.save();
      ctx.strokeStyle = "rgba(108, 198, 255, 0.85)";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(x + 28, y - 30, 48, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = "rgba(108, 198, 255, 0.10)";
      ctx.fill();
      ctx.restore();
    }

    ctx.fillStyle = "#3d4a36";
    if (ducking) {
      ctx.fillRect(x - 4, y - 28, 70, 24);
      ctx.fillRect(x - 16, y - 22, 14, 8);
      ctx.fillRect(x + 56, y - 32, 22, 16);
      ctx.fillStyle = dead ? "#000" : "#fff";
      ctx.fillRect(x + 70, y - 28, 3, 3);
      ctx.fillStyle = "#3d4a36";
      if (step === 0) {
        ctx.fillRect(x + 6, y - 4, 8, 4);
        ctx.fillRect(x + 36, y - 6, 8, 6);
      } else {
        ctx.fillRect(x + 10, y - 6, 8, 6);
        ctx.fillRect(x + 40, y - 4, 8, 4);
      }
    } else {
      ctx.fillRect(x + 4, y - 50, 44, 36);
      ctx.fillRect(x - 10, y - 42, 18, 10);
      ctx.fillRect(x + 30, y - 64, 28, 22);
      ctx.fillRect(x + 50, y - 50, 10, 6);
      ctx.fillStyle = dead ? "#000" : "#fff";
      ctx.fillRect(x + 48, y - 60, 4, 4);
      if (!dead) {
        ctx.fillStyle = "#000";
        ctx.fillRect(x + 49, y - 59, 2, 2);
      }
      ctx.fillStyle = "#2a3527";
      ctx.fillRect(x + 22, y - 28, 8, 10);
      ctx.fillStyle = "#3d4a36";
      if (d.onGround) {
        if (step === 0) {
          ctx.fillRect(x + 10, y - 14, 10, 14);
          ctx.fillRect(x + 30, y - 8, 10, 8);
        } else {
          ctx.fillRect(x + 10, y - 8, 10, 8);
          ctx.fillRect(x + 30, y - 14, 10, 14);
        }
      } else {
        ctx.fillRect(x + 14, y - 18, 10, 10);
        ctx.fillRect(x + 28, y - 18, 10, 10);
      }
    }

    // Magnet aura
    if (this.activePowerups.magnet > 0) {
      ctx.save();
      ctx.strokeStyle = "rgba(247, 201, 72, 0.65)";
      ctx.lineWidth = 2;
      ctx.setLineDash([4, 6]);
      ctx.beginPath();
      ctx.arc(x + 28, y - 30, 80, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
    }
  }
}
