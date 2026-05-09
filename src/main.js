import { DinoGame, POWERUP_TYPES } from "./game.js";
import { SFX } from "./sfx.js";
import { MissionManager } from "./missions.js";

const POWERUP_DURATION = 6 * 60;
const POWERUP_INFO = {
  shield: { label: "SHIELD", glyph: "S" },
  magnet: { label: "MAGNET", glyph: "M" },
  slowmo: { label: "SLOW-MO", glyph: "T" },
};

const screens = document.querySelectorAll(".screen");
const showScreen = (name) => {
  screens.forEach(s => s.classList.toggle("is-active", s.dataset.screen === name));
};

// ===== Persistence =====
const STORAGE_KEY = "dino-adventure:settings";
const BEST_KEY = "dino-adventure:best";
const COIN_KEY = "dino-adventure:coins";
const MISSIONS_KEY = "dino-adventure:missions-completed";

const defaults = { sfx: true, music: true, difficulty: "normal" };
const settings = { ...defaults, ...loadJSON(STORAGE_KEY, {}) };
let bestScore = Number(localStorage.getItem(BEST_KEY) || 0);
let totalCoins = Number(localStorage.getItem(COIN_KEY) || 0);
let lifetimeMissions = Number(localStorage.getItem(MISSIONS_KEY) || 0);

function loadJSON(key, fallback) {
  try { return JSON.parse(localStorage.getItem(key) || "null") || fallback; }
  catch { return fallback; }
}
function saveSettings() { localStorage.setItem(STORAGE_KEY, JSON.stringify(settings)); }
function saveBest(v) {
  bestScore = Math.max(bestScore, v);
  localStorage.setItem(BEST_KEY, String(bestScore));
}
function addCoins(n) {
  totalCoins += n;
  localStorage.setItem(COIN_KEY, String(totalCoins));
}

// ===== SFX =====
const sfx = new SFX();
sfx.setEnabled(settings.sfx);
sfx.setMusicEnabled(settings.music);

// ===== DOM refs =====
const canvas = document.getElementById("gameCanvas");
const scoreEl = document.getElementById("scoreValue");
const bestEl = document.getElementById("bestValue");
const finalScoreEl = document.getElementById("finalScore");
const finalBestEl = document.getElementById("finalBest");
const finalCoinsEl = document.getElementById("finalCoins");
const finalComboEl = document.getElementById("finalCombo");
const finalClearedEl = document.getElementById("finalCleared");
const finalMissionsEl = document.getElementById("finalMissions");
const pauseOverlay = document.getElementById("pauseOverlay");
const gameOverOverlay = document.getElementById("gameOverOverlay");
const pauseBtn = document.getElementById("pauseBtn");
const controlsHint = document.getElementById("controlsHint");
const coinRunEl = document.getElementById("coinRun");
const coinTotalEl = document.getElementById("coinTotal");
const missionsListEl = document.getElementById("missionsList");
const powerupRowEl = document.getElementById("powerupRow");
const toastStack = document.getElementById("toastStack");

bestEl.textContent = bestScore;
coinTotalEl.textContent = totalCoins;

// ===== Mission manager =====
let missionsThisRun = 0;
const missions = new MissionManager({
  onChange: (list) => renderMissions(list),
  onComplete: (m) => {
    missionsThisRun++;
    lifetimeMissions++;
    localStorage.setItem(MISSIONS_KEY, String(lifetimeMissions));
    addCoins(m.reward);
    coinTotalEl.textContent = totalCoins;
    sfx.play("milestone");
    showToast({
      kind: "mission",
      html: `<strong>Mission complete</strong> ${m.label} <em>+${m.reward}¢</em>`,
    });
  },
});

function renderMissions(list) {
  missionsListEl.innerHTML = list.map(m => `
    <div class="mission ${m.completed ? "mission--done" : ""}">
      <span class="mission__label">${m.label}</span>
      <span class="mission__reward">+${m.reward}¢</span>
      <span class="mission__bar"><span class="mission__fill" style="width:${Math.round(m.ratio * 100)}%"></span></span>
    </div>
  `).join("");
}

// ===== Powerup row =====
function renderPowerups() {
  if (!game) { powerupRowEl.innerHTML = ""; return; }
  const html = POWERUP_TYPES
    .map((k) => {
      const remaining = game.activePowerups[k];
      if (!remaining) return "";
      const ratio = Math.max(0, remaining / POWERUP_DURATION);
      return `
        <span class="powerup-chip powerup-chip--${k}">
          ${POWERUP_INFO[k].glyph} ${POWERUP_INFO[k].label}
          <span class="powerup-chip__bar"><span class="powerup-chip__fill" style="width:${Math.round(ratio * 100)}%"></span></span>
        </span>
      `;
    })
    .join("");
  powerupRowEl.innerHTML = html;
}

// ===== Toasts =====
function showToast({ kind = "mission", html }) {
  const el = document.createElement("div");
  el.className = `toast toast--${kind}`;
  el.innerHTML = html;
  toastStack.appendChild(el);
  setTimeout(() => el.remove(), 2800);
}

// ===== Game instance =====
let game = null;

function ensureGame() {
  if (game) return game;
  game = new DinoGame(canvas, {
    sfx,
    onScore: (s) => { scoreEl.textContent = s; },
    onStats: (stats) => {
      missions.update({ ...stats, score: stats.score });
      coinRunEl.textContent = stats.coins;
      renderPowerups();
    },
    onEvent: (type, data) => {
      if (type === "powerup") {
        showToast({
          kind: "powerup",
          html: `<strong>${POWERUP_INFO[data.type].label}</strong> activated`,
        });
      } else if (type === "shield-break") {
        showToast({ kind: "powerup", html: `<strong>SHIELD</strong> absorbed a hit!` });
      } else if (type === "combo" && data.combo === 5) {
        showToast({ kind: "combo", html: `<strong>COMBO x5!</strong> bonus points` });
      } else if (type === "combo" && data.combo === 10) {
        showToast({ kind: "combo", html: `<strong>COMBO x10!</strong> on fire 🔥` });
      }
    },
    onGameOver: (stats) => {
      const finalScore = stats.score;
      saveBest(finalScore);
      addCoins(stats.coins);
      coinTotalEl.textContent = totalCoins;
      bestEl.textContent = bestScore;
      finalScoreEl.textContent = finalScore;
      finalBestEl.textContent = bestScore;
      finalCoinsEl.textContent = stats.coins;
      finalComboEl.textContent = "x" + stats.maxCombo;
      finalClearedEl.textContent = stats.cactiCleared + stats.rocksCleared + stats.pteroCleared;
      finalMissionsEl.textContent = missionsThisRun;
      sfx.stopMusic();
      gameOverOverlay.hidden = false;
    },
  });
  game.setDifficulty(settings.difficulty);
  return game;
}

function startGame() {
  const g = ensureGame();
  g.reset();
  g.setDifficulty(settings.difficulty);
  scoreEl.textContent = 0;
  bestEl.textContent = bestScore;
  coinRunEl.textContent = 0;
  missionsThisRun = 0;
  pauseOverlay.hidden = true;
  gameOverOverlay.hidden = true;
  toastStack.innerHTML = "";
  powerupRowEl.innerHTML = "";
  showScreen("game");
  setTimeout(() => g.start(), 50);
  hideHintLater();
  if (settings.music) sfx.startMusic();
}

function hideHintLater() {
  controlsHint.style.opacity = 1;
  clearTimeout(hideHintLater._t);
  hideHintLater._t = setTimeout(() => {
    controlsHint.style.transition = "opacity 600ms ease";
    controlsHint.style.opacity = 0;
  }, 3500);
}

function pauseGame() {
  if (!game || game.state !== "running") return;
  game.pause();
  pauseOverlay.hidden = false;
}
function resumeGame() {
  if (!game || game.state !== "paused") return;
  pauseOverlay.hidden = true;
  game.resume();
}
function goHome() {
  if (game) game.stop();
  sfx.stopMusic();
  pauseOverlay.hidden = true;
  gameOverOverlay.hidden = true;
  showScreen("title");
}

// ===== Click routing =====
document.addEventListener("click", (e) => {
  const t = e.target.closest("[data-action]");
  if (!t) return;
  const action = t.dataset.action;
  sfx.play("click");
  switch (action) {
    case "play": startGame(); break;
    case "how-to-play": showScreen("how-to-play"); break;
    case "settings": showScreen("settings"); break;
    case "home": goHome(); break;
    case "resume": resumeGame(); break;
    case "retry": startGame(); break;
    case "reroll-missions": missions.reroll(); break;
  }
});

pauseBtn.addEventListener("click", () => {
  if (game && game.state === "paused") resumeGame();
  else pauseGame();
});

// ===== Title icon toggles =====
const toggleSfxBtn = document.getElementById("toggleSfx");
const toggleMusicBtn = document.getElementById("toggleMusic");
function syncTitleIcons() {
  toggleSfxBtn.classList.toggle("is-off", !settings.sfx);
  toggleMusicBtn.classList.toggle("is-off", !settings.music);
}
toggleSfxBtn.addEventListener("click", () => {
  settings.sfx = !settings.sfx;
  sfx.setEnabled(settings.sfx);
  saveSettings();
  syncSettingsForm();
  syncTitleIcons();
});
toggleMusicBtn.addEventListener("click", () => {
  settings.music = !settings.music;
  sfx.setMusicEnabled(settings.music);
  saveSettings();
  syncSettingsForm();
  syncTitleIcons();
});
syncTitleIcons();

// ===== Settings form =====
const setSfx = document.getElementById("setSfx");
const setMusic = document.getElementById("setMusic");
const setDifficulty = document.getElementById("setDifficulty");
const resetBest = document.getElementById("resetBest");

function syncSettingsForm() {
  setSfx.checked = settings.sfx;
  setMusic.checked = settings.music;
  setDifficulty.value = settings.difficulty;
}
syncSettingsForm();

setSfx.addEventListener("change", () => {
  settings.sfx = setSfx.checked;
  sfx.setEnabled(settings.sfx);
  saveSettings();
  syncTitleIcons();
});
setMusic.addEventListener("change", () => {
  settings.music = setMusic.checked;
  sfx.setMusicEnabled(settings.music);
  saveSettings();
  syncTitleIcons();
});
setDifficulty.addEventListener("change", () => {
  settings.difficulty = setDifficulty.value;
  if (game) game.setDifficulty(settings.difficulty);
  saveSettings();
});
resetBest.addEventListener("click", () => {
  localStorage.removeItem(BEST_KEY);
  bestScore = 0;
  bestEl.textContent = 0;
  resetBest.textContent = "Reset!";
  setTimeout(() => (resetBest.textContent = "Reset Best Score"), 1200);
});

// ===== Keyboard controls =====
window.addEventListener("keydown", (e) => {
  if (e.repeat) return;
  if (e.code === "ArrowUp" || e.code === "Space" || e.code === "KeyW") {
    if (game && game.state === "running") { game.jump(); e.preventDefault(); }
  } else if (e.code === "ArrowDown" || e.code === "KeyS") {
    if (game && game.state === "running") { game.duck(true); e.preventDefault(); }
  } else if (e.code === "Escape" || e.code === "KeyP") {
    if (game) {
      if (game.state === "running") pauseGame();
      else if (game.state === "paused") resumeGame();
    }
  } else if (e.code === "Enter") {
    if (gameOverOverlay && !gameOverOverlay.hidden) startGame();
  } else if (e.code === "KeyR") {
    if (game && game.state === "running") missions.reroll();
  }
});
window.addEventListener("keyup", (e) => {
  if (e.code === "ArrowDown" || e.code === "KeyS") {
    if (game) game.duck(false);
  }
});

// ===== Mouse / touch on canvas =====
let mouseDown = false;
canvas.addEventListener("mousedown", () => {
  if (!game || game.state !== "running") return;
  mouseDown = true;
  game.jump();
});
canvas.addEventListener("mouseup", () => {
  mouseDown = false;
  if (game) game.duck(false);
});
canvas.addEventListener("mouseleave", () => {
  if (game) game.duck(false);
});
let holdTimer = null;
canvas.addEventListener("mousedown", () => {
  clearTimeout(holdTimer);
  holdTimer = setTimeout(() => {
    if (mouseDown && game) game.duck(true);
  }, 220);
});
canvas.addEventListener("touchstart", (e) => {
  if (!game || game.state !== "running") return;
  if (e.touches.length === 1) {
    const y = e.touches[0].clientY;
    if (y > window.innerHeight * 0.6) game.duck(true);
    else game.jump();
  }
  e.preventDefault();
}, { passive: false });
canvas.addEventListener("touchend", () => {
  if (game) game.duck(false);
});

// Initial render
renderMissions(missions.list());
showScreen("title");
