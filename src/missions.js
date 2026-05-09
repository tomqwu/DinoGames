// Mission system — daily-shuffled active missions tracked against per-run stats.
// Three slots; completing a mission auto-rolls a fresh template into the slot.

const MISSION_TEMPLATES = [
  { id: "score",     label: (n) => `Reach ${n} points`,           stat: "score",            targets: [300, 500, 1000, 2000], reward: 5 },
  { id: "coins",     label: (n) => `Collect ${n} coins`,          stat: "coins",            targets: [5, 10, 20],            reward: 8 },
  { id: "jumps",     label: (n) => `Jump ${n} times`,             stat: "jumps",            targets: [10, 20, 35],           reward: 5 },
  { id: "slides",    label: (n) => `Slide ${n} times`,            stat: "slides",           targets: [3, 8, 15],             reward: 5 },
  { id: "cacti",     label: (n) => `Clear ${n} cacti`,            stat: "cactiCleared",     targets: [10, 20, 40],           reward: 6 },
  { id: "pteros",    label: (n) => `Dodge ${n} pterodactyls`,     stat: "pteroCleared",     targets: [3, 6, 12],             reward: 8 },
  { id: "rocks",     label: (n) => `Hop over ${n} rocks`,         stat: "rocksCleared",     targets: [5, 12, 25],            reward: 6 },
  { id: "combo",     label: (n) => `Reach an x${n} combo`,        stat: "maxCombo",         targets: [3, 5, 8],              reward: 8 },
  { id: "powerups",  label: (n) => `Collect ${n} powerups`,       stat: "powerupsCollected",targets: [1, 2, 4],              reward: 10 },
  { id: "survive",   label: (n) => `Survive ${n} seconds`,        stat: "survivedFrames",   targets: [30, 60, 120],          reward: 6,
    transform: (frames) => Math.floor(frames / 60), targetTransform: (s) => s * 60 },
];

function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }

export class MissionManager {
  constructor(opts = {}) {
    this.opts = opts;
    this.onChange = opts.onChange || (() => {});
    this.onComplete = opts.onComplete || (() => {});
    this.active = [this._roll(), this._roll(), this._roll()];
    this._enforceUnique();
    this.onChange(this.list());
  }

  list() { return this.active.map(m => this._snapshot(m)); }

  reroll(idx) {
    if (idx == null) {
      this.active = [this._roll(), this._roll(), this._roll()];
      this._enforceUnique();
    } else {
      this.active[idx] = this._roll();
      this._enforceUnique();
    }
    this.onChange(this.list());
  }

  // Update all missions against the current stats snapshot.
  update(stats) {
    let changed = false;
    for (let i = 0; i < this.active.length; i++) {
      const m = this.active[i];
      if (m.completed) continue;
      const raw = stats[m.template.stat] || 0;
      const value = m.template.transform ? m.template.transform(raw) : raw;
      m.progress = value;
      if (value >= m.target) {
        m.completed = true;
        changed = true;
        this.onComplete(this._snapshot(m));
        // queue replacement on next tick
        this._replaceLater(i);
      }
    }
    if (changed) this.onChange(this.list());
    else this.onChange(this.list());
  }

  _replaceLater(i) {
    setTimeout(() => {
      this.active[i] = this._roll();
      this._enforceUnique();
      this.onChange(this.list());
    }, 1500);
  }

  _roll() {
    const tpl = pick(MISSION_TEMPLATES);
    const target = pick(tpl.targets);
    return { template: tpl, target, progress: 0, completed: false };
  }

  _enforceUnique() {
    const seen = new Set();
    for (let i = 0; i < this.active.length; i++) {
      const key = this.active[i].template.id + ":" + this.active[i].target;
      if (seen.has(key)) {
        this.active[i] = this._roll();
        i = -1; seen.clear(); continue;
      }
      seen.add(key);
    }
  }

  _snapshot(m) {
    return {
      id: m.template.id,
      label: m.template.label(m.target),
      reward: m.template.reward,
      target: m.target,
      progress: Math.min(m.progress, m.target),
      completed: m.completed,
      ratio: Math.min(1, (m.progress || 0) / m.target),
    };
  }
}
