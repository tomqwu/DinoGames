// Tiny WebAudio sound bank — no external assets.
export class SFX {
  constructor() {
    this.enabled = true;
    this.musicEnabled = true;
    this.ctx = null;
    this.music = null;
  }

  _ensureCtx() {
    if (!this.ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      this.ctx = new AC();
    }
    if (this.ctx.state === "suspended") this.ctx.resume();
    return this.ctx;
  }

  setEnabled(v) { this.enabled = !!v; }
  setMusicEnabled(v) {
    this.musicEnabled = !!v;
    if (!this.musicEnabled) this.stopMusic();
  }

  play(name) {
    if (!this.enabled) return;
    const ctx = this._ensureCtx();
    if (!ctx) return;
    const now = ctx.currentTime;
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.connect(g); g.connect(ctx.destination);

    switch (name) {
      case "jump":
        o.type = "square";
        o.frequency.setValueAtTime(620, now);
        o.frequency.exponentialRampToValueAtTime(880, now + 0.12);
        g.gain.setValueAtTime(0.18, now);
        g.gain.exponentialRampToValueAtTime(0.0001, now + 0.18);
        o.start(now); o.stop(now + 0.2);
        break;
      case "milestone":
        o.type = "triangle";
        o.frequency.setValueAtTime(660, now);
        o.frequency.setValueAtTime(990, now + 0.1);
        g.gain.setValueAtTime(0.15, now);
        g.gain.exponentialRampToValueAtTime(0.0001, now + 0.25);
        o.start(now); o.stop(now + 0.26);
        break;
      case "hit":
        o.type = "sawtooth";
        o.frequency.setValueAtTime(220, now);
        o.frequency.exponentialRampToValueAtTime(60, now + 0.4);
        g.gain.setValueAtTime(0.25, now);
        g.gain.exponentialRampToValueAtTime(0.0001, now + 0.45);
        o.start(now); o.stop(now + 0.46);
        break;
      case "click":
        o.type = "square";
        o.frequency.setValueAtTime(540, now);
        g.gain.setValueAtTime(0.1, now);
        g.gain.exponentialRampToValueAtTime(0.0001, now + 0.08);
        o.start(now); o.stop(now + 0.09);
        break;
      case "coin":
        o.type = "triangle";
        o.frequency.setValueAtTime(880, now);
        o.frequency.setValueAtTime(1320, now + 0.05);
        g.gain.setValueAtTime(0.12, now);
        g.gain.exponentialRampToValueAtTime(0.0001, now + 0.16);
        o.start(now); o.stop(now + 0.17);
        break;
      case "powerup":
        o.type = "sine";
        o.frequency.setValueAtTime(440, now);
        o.frequency.linearRampToValueAtTime(1200, now + 0.3);
        g.gain.setValueAtTime(0.18, now);
        g.gain.exponentialRampToValueAtTime(0.0001, now + 0.35);
        o.start(now); o.stop(now + 0.36);
        break;
      case "shield-break":
        o.type = "square";
        o.frequency.setValueAtTime(180, now);
        o.frequency.exponentialRampToValueAtTime(60, now + 0.25);
        g.gain.setValueAtTime(0.2, now);
        g.gain.exponentialRampToValueAtTime(0.0001, now + 0.3);
        o.start(now); o.stop(now + 0.31);
        break;
    }
  }

  startMusic() {
    if (!this.musicEnabled) return;
    const ctx = this._ensureCtx();
    if (!ctx || this.music) return;
    const gain = ctx.createGain();
    gain.gain.value = 0.04;
    gain.connect(ctx.destination);
    const o1 = ctx.createOscillator();
    o1.type = "triangle";
    o1.frequency.value = 110;
    o1.connect(gain);
    o1.start();
    this.music = { o1, gain };
  }

  stopMusic() {
    if (!this.music) return;
    try { this.music.o1.stop(); } catch {}
    this.music.gain.disconnect();
    this.music = null;
  }
}
