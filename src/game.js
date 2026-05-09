// Dino Adventure — canvas game engine
// Handles rendering, physics, obstacles, scoring, difficulty.

const GROUND_Y_RATIO = 0.82;  // ground line as fraction of canvas height
const BASE_SPEED = 6.5;
const SPEED_GROWTH = 0.0015;  // px/frame added per score tick
const GRAVITY = 0.85;
const JUMP_VELOCITY = -16;
const DUCK_GRAVITY_BOOST = 1.6;

const DIFFICULTY = {
  easy:   { speedMul: 0.85, gapMul: 1.25, growth: 0.0010 },
  normal: { speedMul: 1.00, gapMul: 1.00, growth: 0.0015 },
  hard:   { speedMul: 1.15, gapMul: 0.85, growth: 0.0022 },
};

export class DinoGame {
  constructor(canvas, opts = {}) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.opts = opts;
    this.onGameOver = opts.onGameOver || (() => {});
    this.onScore = opts.onScore || (() => {});
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
    this.state = "idle";        // idle | running | over
    this.score = 0;
    this.distance = 0;
    this.speed = BASE_SPEED * this.difficulty.speedMul;
    this.spawnTimer = 0;
    this.nextSpawnIn = 60;
    this.obstacles = [];
    this.clouds = this._initClouds();
    this.parallax = { far: 0, mid: 0, near: 0 };
    this.frame = 0;

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

  pause() {
    if (this.state === "running") this.state = "paused";
  }

  resume() {
    if (this.state === "paused") {
      this.state = "running";
      this._loop();
    }
  }

  stop() {
    this.state = "over";
  }

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
      this.sfx?.play("jump");
    }
  }

  duck(active) {
    if (this.state !== "running") return;
    this.dino.ducking = !!active;
  }

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

    // Speed ramps over time (scaled by difficulty)
    this.speed += this.difficulty.growth;
    this.distance += this.speed;
    const newScore = Math.floor(this.distance / 5);
    if (newScore !== this.score) {
      if (newScore > 0 && newScore % 100 === 0) this.sfx?.play("milestone");
      this.score = newScore;
      this.onScore(this.score);
    }

    // Dino physics
    d.vy += GRAVITY * (d.ducking && !d.onGround ? DUCK_GRAVITY_BOOST : 1);
    d.y += d.vy;
    if (d.y >= this.groundY) {
      d.y = this.groundY;
      d.vy = 0;
      d.onGround = true;
    }
    d.runFrame = (d.runFrame + this.speed * 0.05) % 2;

    // Parallax
    this.parallax.far = (this.parallax.far + this.speed * 0.15) % w;
    this.parallax.mid = (this.parallax.mid + this.speed * 0.4) % w;
    this.parallax.near = (this.parallax.near + this.speed) % w;

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
      // gap shrinks slightly with speed
      const speedFactor = Math.max(0.6, 1 - (this.speed - BASE_SPEED) * 0.04);
      this.nextSpawnIn = Math.floor((minGap + Math.random() * (maxGap - minGap)) * speedFactor);
    }

    // Move + cull obstacles
    for (const o of this.obstacles) o.x -= this.speed;
    this.obstacles = this.obstacles.filter(o => o.x + o.w > -20);

    // Collisions
    const dinoBox = this._dinoBox();
    for (const o of this.obstacles) {
      if (this._intersect(dinoBox, o)) {
        this._gameOver();
        return;
      }
    }
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
        // flying obstacle at duck-able or jump-required height
        const heights = [this.groundY - 80, this.groundY - 50];
        const py = heights[Math.floor(Math.random() * heights.length)];
        obs = { type: t, x: w + 20, y: py, w: 50, h: 28, flap: 0 };
        break;
      }
    }
    this.obstacles.push(obs);
  }

  _gameOver() {
    if (this.state === "over") return;
    this.state = "over";
    this.sfx?.play("hit");
    // final draw frame
    this._draw(true);
    this.onGameOver(this.score);
  }

  // ===== Rendering =====
  _draw(dead = false) {
    const ctx = this.ctx;
    const w = this.canvas.width / this.dpr;
    const h = this.canvas.height / this.dpr;

    // Sky
    const sky = ctx.createLinearGradient(0, 0, 0, this.groundY);
    sky.addColorStop(0, "#7fb3d9");
    sky.addColorStop(0.6, "#b6d4e6");
    sky.addColorStop(1, "#dbe6e1");
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, w, this.groundY);

    // Sun
    ctx.fillStyle = "rgba(255, 245, 220, 0.9)";
    ctx.beginPath();
    ctx.arc(w * 0.78, h * 0.18, 28, 0, Math.PI * 2);
    ctx.fill();

    // Mountains (far)
    this._drawMountains(w, h, "#7a8896", -this.parallax.far * 0.3, 140, 0.6);
    this._drawMountains(w, h, "#5b6a78", -this.parallax.far * 0.6, 100, 0.85);

    // Trees (mid)
    this._drawTrees(w, h, -this.parallax.mid, "#39553a", 0);
    this._drawTrees(w, h, -this.parallax.mid * 1.2 + 60, "#2c4530", 12);

    // Clouds
    ctx.fillStyle = "rgba(255,255,255,0.85)";
    for (const c of this.clouds) this._drawCloud(c.x, c.y, c.s);

    // Ground
    this._drawGround(w, h);

    // Obstacles
    for (const o of this.obstacles) this._drawObstacle(o);

    // Dino
    this._drawDino(dead);
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

  _drawGround(w, h) {
    const ctx = this.ctx;
    // dirt
    const dirt = ctx.createLinearGradient(0, this.groundY, 0, h);
    dirt.addColorStop(0, "#5a4a36");
    dirt.addColorStop(1, "#2d2418");
    ctx.fillStyle = dirt;
    ctx.fillRect(0, this.groundY, w, h - this.groundY);
    // grass strip
    ctx.fillStyle = "#3e5a32";
    ctx.fillRect(0, this.groundY - 4, w, 6);
    // pebbles (parallax)
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    const off = -this.parallax.near;
    for (let i = 0; i < 40; i++) {
      const px = ((i * 73 + off) % (w + 60)) - 30;
      const py = this.groundY + 14 + ((i * 31) % 30);
      ctx.fillRect(px, py, 3, 2);
    }
  }

  _drawObstacle(o) {
    const ctx = this.ctx;
    if (o.type.startsWith("cactus")) {
      ctx.fillStyle = "#3f6b3a";
      ctx.fillRect(o.x + o.w / 2 - 5, o.y, 10, o.h);
      // arms
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
      o.flap = (o.flap + 0.2) % (Math.PI * 2);
      ctx.fillStyle = "#3a2f2a";
      const wingY = Math.sin(o.flap) * 6;
      // body
      ctx.fillRect(o.x + 14, o.y + 10, 26, 8);
      // head
      ctx.fillRect(o.x + 36, o.y + 6, 10, 8);
      ctx.fillRect(o.x + 44, o.y + 8, 4, 3);
      // wings
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

    // legs animation
    const step = Math.floor(d.runFrame);

    ctx.fillStyle = "#3d4a36";
    if (ducking) {
      // body (low + long)
      ctx.fillRect(x - 4, y - 28, 70, 24);
      // tail
      ctx.fillRect(x - 16, y - 22, 14, 8);
      // head
      ctx.fillRect(x + 56, y - 32, 22, 16);
      // eye
      ctx.fillStyle = dead ? "#000" : "#fff";
      ctx.fillRect(x + 70, y - 28, 3, 3);
      ctx.fillStyle = "#3d4a36";
      // legs (short, alternating)
      if (step === 0) {
        ctx.fillRect(x + 6, y - 4, 8, 4);
        ctx.fillRect(x + 36, y - 6, 8, 6);
      } else {
        ctx.fillRect(x + 10, y - 6, 8, 6);
        ctx.fillRect(x + 40, y - 4, 8, 4);
      }
    } else {
      // body
      ctx.fillRect(x + 4, y - 50, 44, 36);
      // tail
      ctx.fillRect(x - 10, y - 42, 18, 10);
      // head
      ctx.fillRect(x + 30, y - 64, 28, 22);
      // jaw
      ctx.fillRect(x + 50, y - 50, 10, 6);
      // eye
      ctx.fillStyle = dead ? "#000" : "#fff";
      ctx.fillRect(x + 48, y - 60, 4, 4);
      if (!dead) {
        ctx.fillStyle = "#000";
        ctx.fillRect(x + 49, y - 59, 2, 2);
      }
      ctx.fillStyle = "#2a3527";
      // arm
      ctx.fillRect(x + 22, y - 28, 8, 10);
      // legs
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
        // jumping legs tucked
        ctx.fillRect(x + 14, y - 18, 10, 10);
        ctx.fillRect(x + 28, y - 18, 10, 10);
      }
    }
  }
}
