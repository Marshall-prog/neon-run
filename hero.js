// ---------- неоновый герой ----------
// Тёмный силуэт с контровым светом — тот же язык, что у препятствий: почти
// чёрное тело и горячий контур. Никаких наклеенных пиксельных спрайтов: тело
// собирается из капсул и решается скелетом (бедро+голень через IK, плечо+предплечье),
// поэтому колено сгибается, а не вращается целиком, как палка.
//
// Файл общий для игры и для лаборатории вариантов (tools/hero_lab.html),
// чтобы не держать две копии рисования.
(function () {
  const BODY = "#070b14";        // тело: почти чёрный, с синевой
  const RIM = "#f2feff";         // контровой свет: самый яркий элемент кадра
  const RW = 2.2;                // его толщина, мировые px

  let g = null;                  // контекст текущего вызова
  let A = "#ffffff";             // акцент (визор, ядро, шарф, обувь)

  // ---- примитивы ----
  function glow(on, col, blur) {
    g.shadowColor = on ? col : "rgba(0,0,0,0)";
    g.shadowBlur = on ? blur : 0;
  }
  // капсула с контровым светом: сначала контур, потом тело поверх
  function bone(x1, y1, x2, y2, w, fill) {
    g.lineCap = "round";
    g.strokeStyle = RIM; g.lineWidth = w + RW * 2;
    g.beginPath(); g.moveTo(x1, y1); g.lineTo(x2, y2); g.stroke();
    g.strokeStyle = fill || BODY; g.lineWidth = w;
    g.beginPath(); g.moveTo(x1, y1); g.lineTo(x2, y2); g.stroke();
  }
  // залитая фигура с контровым светом по краю
  function shape(path, fill) {
    g.lineJoin = "round";
    g.strokeStyle = RIM; g.lineWidth = RW * 2;
    g.stroke(path);
    g.fillStyle = fill || BODY;
    g.fill(path);
  }
  function dot(x, y, r, col) {
    g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2);
    g.fillStyle = col; g.fill();
  }

  // ---- нога: бедро + голень, колено выгибается вперёд ----
  function leg(hx, hy, ang, len, lift, w) {
    const fx = hx + Math.sin(ang) * len;
    const fy = hy + Math.cos(ang) * len;
    const L1 = len * 0.52, L2 = len * 0.5;
    const dx = fx - hx, dy = fy - hy;
    const d = Math.min(Math.hypot(dx, dy), L1 + L2 - 0.01) || 0.01;
    const a = (d * d + L1 * L1 - L2 * L2) / (2 * d);
    const h = Math.sqrt(Math.max(0, L1 * L1 - a * a));
    const ux = dx / d, uy = dy / d;
    const kx = hx + ux * a + uy * h;      // колено вперёд
    const ky = hy + uy * a - ux * h;
    bone(hx, hy, kx, ky, w);
    bone(kx, ky, fx, fy, w * 0.92);
    return { fx, fy, kx, ky, ang };
  }
  // стопа: клин в цвете акцента, ставится почти плашмя
  function foot(f, w, kind) {
    g.save();
    g.translate(f.fx, f.fy);
    g.rotate(Math.max(-0.5, Math.min(0.5, -f.ang * 0.6)));
    glow(true, A, 10);
    g.fillStyle = A;
    if (kind === "plate") {                     // дроид: плоская пластина
      g.fillRect(-w * 0.35, -2, w * 0.9, 4);
    } else if (kind === "tabi") {               // ниндзя: мягкая лапа
      g.beginPath(); g.ellipse(1, 0, w * 0.45, 3.4, 0, 0, Math.PI * 2); g.fill();
    } else if (kind === "boot") {               // гонщик: тяжёлый ботинок
      g.fillRect(-w * 0.4, -3, w * 1.0, 6);
    } else {                                    // бегун: кроссовок
      g.beginPath();
      g.moveTo(-w * 0.45, -2.5);
      g.lineTo(w * 0.5, -1);
      g.lineTo(w * 0.55, 2.5);
      g.lineTo(-w * 0.45, 2.5);
      g.closePath(); g.fill();
    }
    glow(false);
    g.restore();
  }

  // ---- рука: плечо + предплечье с изгибом в локте ----
  function arm(sx, sy, ang, len, w, bend) {
    const ex = sx + Math.sin(ang) * len * 0.55;
    const ey = sy + Math.cos(ang) * len * 0.55;
    const a2 = ang + (bend === undefined ? 0.9 : bend);
    const hx = ex + Math.sin(a2) * len * 0.45;
    const hy = ey + Math.cos(a2) * len * 0.45;
    bone(sx, sy, ex, ey, w);
    bone(ex, ey, hx, hy, w * 0.88);
    return { hx, hy };
  }
  function hand(x, y, r) {
    glow(true, A, 12);
    dot(x, y, r, A);
    glow(false);
  }

  // ---- торс ----
  function torso(w, h, hipY, kind) {
    const hw = w * 0.5, sw = w * 0.62, top = hipY - h;
    const p = new Path2D();
    p.moveTo(-hw * 0.92, hipY + 2);
    p.quadraticCurveTo(-hw * 1.06, hipY - h * 0.35, -sw, top + h * 0.16);
    p.quadraticCurveTo(-sw * 0.72, top - h * 0.06, 0, top - h * 0.04);
    p.quadraticCurveTo(sw * 0.72, top - h * 0.06, sw, top + h * 0.16);
    p.quadraticCurveTo(hw * 1.06, hipY - h * 0.35, hw * 0.92, hipY + 2);
    p.closePath();
    shape(p);

    if (kind === "hoodie") {              // капюшон-валик на плечах
      const c = new Path2D();
      c.ellipse(0, top + h * 0.06, sw * 0.78, h * 0.16, 0, Math.PI, Math.PI * 2);
      shape(c, "#0d1424");
    } else if (kind === "armor") {        // дроид: сегменты брони
      g.strokeStyle = A; g.lineWidth = 1.6;
      glow(true, A, 12);
      for (let i = 1; i <= 2; i++) {
        const yy = hipY - h * (0.28 + i * 0.26);
        g.beginPath(); g.moveTo(-hw * 0.75, yy); g.lineTo(hw * 0.75, yy); g.stroke();
      }
      glow(false);
    } else if (kind === "kimono") {       // ниндзя: запах и пояс
      g.strokeStyle = A; g.lineWidth = 2;
      glow(true, A, 10);
      g.beginPath(); g.moveTo(-hw * 0.6, top + h * 0.3); g.lineTo(hw * 0.5, hipY - h * 0.05); g.stroke();
      g.beginPath(); g.moveTo(-hw, hipY - h * 0.28); g.lineTo(hw, hipY - h * 0.28); g.stroke();
      glow(false);
    } else if (kind === "jacket") {       // гонщик: молния и воротник
      g.strokeStyle = A; g.lineWidth = 2;
      glow(true, A, 10);
      g.beginPath(); g.moveTo(0, top); g.lineTo(0, hipY - h * 0.12); g.stroke();
      glow(false);
    }
    return { top, sw, hw };
  }

  // ---- голова: у каждого варианта своя ----
  function head(kind, cx, cy, r, t) {
    g.save();
    g.translate(cx, cy);

    if (kind === "hood") {                       // бегун в капюшоне
      const p = new Path2D();
      p.moveTo(-r * 0.95, r * 0.5);
      p.quadraticCurveTo(-r * 1.15, -r * 1.15, r * 0.1, -r * 1.1);
      p.quadraticCurveTo(r * 1.15, -r * 1.0, r * 0.95, r * 0.35);
      p.quadraticCurveTo(r * 0.55, r * 0.72, 0, r * 0.72);
      p.quadraticCurveTo(-r * 0.6, r * 0.7, -r * 0.95, r * 0.5);
      p.closePath();
      shape(p);
      glow(true, A, 14);                         // визор
      g.fillStyle = A;
      const w = new Path2D();
      w.moveTo(r * 0.05, -r * 0.3);
      w.lineTo(r * 1.02, -r * 0.16);
      w.lineTo(r * 0.98, r * 0.2);
      w.lineTo(r * 0.05, r * 0.12);
      w.closePath(); g.fill(w);
      glow(false);
    } else if (kind === "visor") {               // дроид: голова-коробка с полосой
      const p = new Path2D();
      p.moveTo(-r * 0.9, -r * 0.75);
      p.quadraticCurveTo(0, -r * 1.05, r * 0.9, -r * 0.75);
      p.quadraticCurveTo(r * 1.05, 0, r * 0.78, r * 0.62);
      p.quadraticCurveTo(0, r * 0.95, -r * 0.78, r * 0.62);
      p.quadraticCurveTo(-r * 1.05, 0, -r * 0.9, -r * 0.75);
      p.closePath();
      shape(p);
      glow(true, A, 16);
      g.fillStyle = A;
      g.fillRect(-r * 0.72, -r * 0.28, r * 1.66, r * 0.42);
      glow(false);
      g.strokeStyle = RIM; g.lineWidth = 1.8;    // антенна
      g.beginPath(); g.moveTo(-r * 0.35, -r * 0.95);
      g.lineTo(-r * 0.7, -r * 1.55 + Math.sin(t * 6) * 1.4); g.stroke();
    } else if (kind === "wrap") {                // ниндзя: обмотка и щель глаз
      const p = new Path2D();
      p.arc(0, 0, r, 0, Math.PI * 2);
      shape(p);
      glow(true, A, 12);
      g.fillStyle = A;
      g.fillRect(-r * 0.1, -r * 0.22, r * 1.05, r * 0.3);
      glow(false);
      g.strokeStyle = RIM; g.lineWidth = 1.2;    // полоса обмотки
      g.beginPath(); g.moveTo(-r * 0.8, -r * 0.62); g.quadraticCurveTo(0, -r * 1.15, r * 0.72, -r * 0.5); g.stroke();
    } else {                                     // гонщик: шлем с зеркалом
      const p = new Path2D();
      p.moveTo(-r * 0.92, r * 0.62);
      p.quadraticCurveTo(-r * 1.18, -r * 0.55, -r * 0.2, -r * 1.05);
      p.quadraticCurveTo(r * 0.95, -r * 1.15, r * 1.0, -r * 0.1);
      p.quadraticCurveTo(r * 1.02, r * 0.72, 0, r * 0.78);
      p.closePath();
      shape(p);
      glow(true, A, 16);
      g.fillStyle = A;
      const v = new Path2D();
      v.moveTo(r * 0.02, -r * 0.42);
      v.lineTo(r * 1.0, -r * 0.3);
      v.lineTo(r * 0.94, r * 0.3);
      v.lineTo(r * 0.02, r * 0.16);
      v.closePath(); g.fill(v);
      glow(false);
      g.strokeStyle = RIM; g.lineWidth = 1.6;    // гребень
      g.beginPath(); g.moveTo(-r * 0.2, -r * 1.02); g.quadraticCurveTo(r * 0.1, -r * 1.32, r * 0.55, -r * 1.05); g.stroke();
    }
    g.restore();
  }

  // ---- шарф: лента назад, колышется по времени и скорости ----
  function scarf(nx, ny, t, speed, col) {
    const k = Math.min(1.4, 0.6 + speed * 0.5);
    const wob = Math.sin(t * 9.5) * 2.4 * k;
    const wob2 = Math.sin(t * 7.2 + 1.3) * 3.2 * k;
    g.save();
    g.lineCap = "round";
    glow(true, col, 14);
    g.strokeStyle = col;
    g.lineWidth = 5.2;
    g.beginPath(); g.moveTo(nx - 2, ny);
    g.bezierCurveTo(nx - 12, ny - 3 + wob, nx - 22, ny + 4 + wob2, nx - 33 - 3 * k, ny + 1 + wob2 * 0.6);
    g.stroke();
    g.lineWidth = 2.2;
    g.strokeStyle = "rgba(255,255,255,0.75)";
    g.stroke();
    glow(false);
    g.restore();
  }

  // ---- сборка ----
  // P: hipY, legH, legW, bodyW, bodyH, armH, armW, headR,
  //    legA, legB, legLiftA, legLiftB, armA, armB, crouch, t, speed
  function draw(ctx, styleName, P) {
    const st = STYLES[styleName] || STYLES.hoodie;
    g = ctx;
    // цвет акцента можно переопределить (в игре это неон уровня и настроение)
    A = P.accent || st.accent;
    const glowCol = P.glowCol || st.glowCol;
    const scarfCol = P.scarfCol || st.scarfCol;

    const hipY = P.hipY;
    const shoY = hipY - P.bodyH * 0.94;
    const neckY = shoY - P.bodyH * 0.06;
    const headCY = neckY - P.headR * 1.02;

    g.save();
    glow(true, glowCol, 16);

    // дальняя рука и дальняя нога — позади корпуса
    g.globalAlpha = 0.86;
    const backArm = arm(-1.5, shoY + 2, P.armB, P.armH, P.armW * 0.9, 0.75);
    hand(backArm.hx, backArm.hy, P.armW * 0.44);
    const bk = P.legLiftB || 0, fk = P.legLiftA || 0;
    const backLeg = leg(-1.5, hipY, P.legB, P.legH * (1 - bk * 0.4), bk, P.legW * 0.95);
    foot(backLeg, P.legW + 4, st.boot);
    g.globalAlpha = 1;

    // корпус
    const tr = torso(P.bodyW, P.bodyH, hipY, st.torso);
    // ближняя нога
    const frontLeg = leg(1.8, hipY, P.legA, P.legH * (1 - fk * 0.4), fk, P.legW);
    foot(frontLeg, P.legW + 4.5, st.boot);
    // ближняя рука
    const frontArm = arm(1.8, shoY + 2, P.armA, P.armH, P.armW, 0.8);
    hand(frontArm.hx, frontArm.hy, P.armW * 0.46);
    // ядро/пояс
    if (st.core === "chest") {
      glow(true, A, 18);
      dot(0, shoY + P.bodyH * 0.32, P.bodyW * 0.14, A);
      glow(false);
    }
    // шарф
    if (st.scarf) scarf(-2, shoY - P.bodyH * 0.02, P.t || 0, P.speed === undefined ? 1 : P.speed, scarfCol);
    // голова
    head(st.head, 0, headCY, P.headR, P.t || 0);
    // спина: клинок у ниндзя
    if (st.blade) {
      g.strokeStyle = RIM; g.lineWidth = 2.4;
      glow(true, A, 12);
      g.beginPath(); g.moveTo(-P.bodyW * 0.5, shoY + 3); g.lineTo(-P.bodyW * 0.95, hipY - 4); g.stroke();
      glow(false);
    }
    g.restore();
    return { headCY, hipY, fx: frontLeg.fx };
  }

  const STYLES = {
    hoodie: { head: "hood",   torso: "hoodie", boot: "shoe",  accent: "#5ef2ff", scarf: 1, scarfCol: "#ff2d95", glowCol: "rgba(94,242,255,0.55)", core: "none" },
    droid:  { head: "visor",  torso: "armor",  boot: "plate", accent: "#ffd24a", scarf: 0, gift: 0, glowCol: "rgba(255,210,74,0.5)", core: "chest" },
    ninja:  { head: "wrap",   torso: "kimono", boot: "tabi",  accent: "#ff4d6d", scarf: 1, scarfCol: "#ff4d6d", glowCol: "rgba(255,77,109,0.5)", core: "none", blade: 1 },
    racer:  { head: "helmet", torso: "jacket", boot: "boot",  accent: "#b06bff", scarf: 0, glowCol: "rgba(176,107,255,0.5)", core: "none" },
  };

  window.NeonHero = { draw: draw, styles: Object.keys(STYLES), STYLES: STYLES, RIM: RIM, BODY: BODY };
})();
