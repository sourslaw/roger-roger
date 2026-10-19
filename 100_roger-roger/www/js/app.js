const ROOMS = {
  living: {
    title: "Living Room",
    subtitle: "Seasoned Hearth",
    description: "Trace clues around the hearth, side table, and lounge chair.",
    hotspots: [
      { id: "champagne", label: "Inspect Champagne Flute", haptic: "light" },
      { id: "cards", label: "Examine Business Cards", haptic: "medium" }
    ]
  },
  pool: {
    title: "Poolside Patio",
    subtitle: "Open Air Sanctuary",
    description: "Investigate the recorder and footprints before they disappear.",
    hotspots: [
      { id: "recorder", label: "Examine Cassette Recorder", haptic: "light" },
      { id: "glass", label: "Inspect Poolside Footprints", haptic: "light" }
    ]
  },
  study: {
    title: "The Study",
    subtitle: "Vault of Ancestral Knowledge",
    description: "Search the desk area and secured briefcase for hidden directives.",
    hotspots: [
      { id: "terminal", label: "Access CRT Terminal", haptic: "heavy" },
      { id: "briefcase", label: "Inspect Locked Briefcase", haptic: "medium" }
    ]
  }
};

const HOTSPOT_POSITIONS = {
  living: {
    champagne: { left: "47%", top: "27%" },
    cards: { left: "79%", top: "58%" }
  },
  pool: {
    recorder: { left: "9.5%", top: "39%" },
    glass: { left: "89%", top: "80%" }
  },
  study: {
    terminal: { left: "81%", top: "36%" },
    briefcase: { left: "51%", top: "62%" }
  }
};

const HOTSPOT_LOCKS = {
  cards: {
    requires: ["champagne"],
    hint: "Inspect the champagne flute first."
  },
  terminal: {
    requires: ["recorder"],
    hint: "Find the poolside recorder first."
  },
  briefcase: {
    requires: ["terminal"],
    hint: "Access the CRT terminal first."
  },
  glass: {
    requires: ["cards"],
    hint: "Study the business cards first."
  }
};

const KEYWORDS_DB = {
  champagne: "Broadhead Semiconductor",
  terminal: "Project Code: ARCHON",
  recorder: "Roger's Wiretap"
};

const AMBIENT_TRACKS = {
  living: "audio/living-ambience.mp3",
  pool: "audio/pool-ambience.mp3",
  study: "audio/study-ambience.mp3"
};
const USE_FILE_AMBIENCE = false;
const USE_FILE_SFX = false;
const AMBIENT_CROSSFADE_MS = 900;

const HOTSPOT_SFX_TRACKS = {
  champagne: "audio/sfx/champagne.mp3",
  cards: "audio/sfx/cards.mp3",
  recorder: "audio/sfx/recorder.mp3",
  glass: "audio/sfx/glass.mp3",
  terminal: "audio/sfx/terminal.mp3",
  briefcase: "audio/sfx/briefcase.mp3",
  locked: "audio/sfx/locked.mp3"
};

const ROOM_FREQUENCIES = {
  living: 143,
  pool: 178,
  study: 121
};

let currentRoom = "living";
let collectedKeywords = new Set();
let discoveredHotspots = new Set();
let audioEnabled = false;
let activeAmbientHowl = null;
let ambientContext = null;
let ambientNodes = [];

const TOTAL_DISCOVERIES = Object.values(ROOMS).reduce((total, room) => total + room.hotspots.length, 0);

function switchRoom(roomId) {
  if (!ROOMS[roomId]) return;
  currentRoom = roomId;
  sendToNative("triggerHaptic", { style: "light" });
  document.querySelectorAll(".nav-btn").forEach(btn => btn.classList.remove("active"));
  document.getElementById(`nav-${roomId}`).classList.add("active");

  const room = ROOMS[roomId];
  const sceneStage = document.getElementById("scene-stage");
  if (sceneStage) sceneStage.className = `scene-stage room-${roomId}`;
  document.getElementById("room-tag").innerText = `${room.title} // ${room.subtitle}`;
  document.getElementById("scene-description").innerText = room.description;
  renderHotspots(roomId);
  animateRoomEnter();
  playAmbientForRoom(roomId);
  logOutput(`> Entered ${room.title}.`);
}

function renderHotspots(roomId) {
  const room = ROOMS[roomId];
  const container = document.getElementById("hotspots-container");
  const roomPositions = HOTSPOT_POSITIONS[roomId] || {};
  container.innerHTML = "";

  room.hotspots.forEach(hs => {
    const btn = document.createElement("button");
    const position = roomPositions[hs.id] || { left: "50%", top: "50%" };
    const isLocked = hotspotIsLocked(hs.id);
    const lockHint = getLockHint(hs.id);
    btn.className = "hotspot-btn";
    btn.dataset.itemId = hs.id;
    btn.dataset.label = hs.label;
    btn.style.left = position.left;
    btn.style.top = position.top;
    btn.setAttribute("aria-label", hs.label);
    btn.setAttribute("title", isLocked ? lockHint : hs.label);
    if (isLocked) btn.classList.add("is-locked");
    if (discoveredHotspots.has(hs.id)) btn.classList.add("is-seen");
    btn.onclick = () => {
      beginAudioSession();
      if (hotspotIsLocked(hs.id)) {
        onLockedHotspot(lockHint);
        return;
      }
      inspectItem(hs.id, hs.haptic, btn);
    };
    container.appendChild(btn);
  });
}

function inspectItem(itemId, hapticStyle, hotspotButton) {
  sendToNative("triggerHaptic", { style: hapticStyle });
  animateHotspotInspect(hotspotButton);
  playHotspotSfx(itemId);

  const firstDiscovery = !discoveredHotspots.has(itemId);
  discoveredHotspots.add(itemId);
  if (firstDiscovery) {
    updateDiscoveryCount();
    hotspotButton.classList.add("is-seen");
    refreshLocksForCurrentRoom();
  }

  if (KEYWORDS_DB[itemId]) unlockKeyword(KEYWORDS_DB[itemId]);

  switch (itemId) {
    case "champagne":
      logOutput("> Memory Echo: 'Uncle Roger was insisting that microchip design is just high-stakes winemaking...'");
      break;
    case "cards":
      logOutput("> Found a card for 'Broadhead Semiconductor Systems'. A phone number is scribbled on the back.");
      break;
    case "terminal":
      logOutput("> MEMO #084: 'Project ARCHON requires clearance level 3. Check poolside recordings.'");
      break;
    case "briefcase":
      logOutput("> Locked tight. A 3-digit combination lock glints in the sunlight.");
      break;
    case "recorder":
      logOutput("> The tape inside is rewound to 00:00. Faint voices and ambient music play back.");
      break;
    case "glass":
      logOutput("> Wet footprints lead away from the glass door toward the study.");
      break;
    default:
      logOutput("> You inspect the scene carefully.");
  }
}

function hotspotIsLocked(itemId) {
  const lock = HOTSPOT_LOCKS[itemId];
  if (!lock) return false;
  return !lock.requires.every(requiredId => discoveredHotspots.has(requiredId));
}

function getLockHint(itemId) {
  const lock = HOTSPOT_LOCKS[itemId];
  return lock ? `Locked: ${lock.hint}` : "";
}

function onLockedHotspot(lockHint) {
  sendToNative("triggerHaptic", { style: "warning" });
  playHotspotSfx("locked");
  logOutput(`> ${lockHint}`);
}

function refreshLocksForCurrentRoom() {
  const room = ROOMS[currentRoom];
  if (!room) return;
  room.hotspots.forEach(hs => {
    const btn = document.querySelector(`.hotspot-btn[data-item-id="${hs.id}"]`);
    if (!btn) return;
    const isLocked = hotspotIsLocked(hs.id);
    if (isLocked) {
      btn.classList.add("is-locked");
      btn.setAttribute("title", getLockHint(hs.id));
    } else {
      btn.classList.remove("is-locked");
      btn.setAttribute("title", hs.label);
    }
  });
}

function unlockKeyword(keyword) {
  if (collectedKeywords.has(keyword)) return;
  collectedKeywords.add(keyword);
  sendToNative("triggerHaptic", { style: "success" });
  const listEl = document.getElementById("keywords-list");
  if (collectedKeywords.size === 1) listEl.innerHTML = "";
  const tag = document.createElement("span");
  tag.className = "keyword-tag";
  tag.innerText = keyword;
  listEl.appendChild(tag);
}

function animateRoomEnter() {
  if (!window.gsap) return;
  const scene = document.getElementById("scene-stage");
  const markers = document.querySelectorAll(".hotspot-btn");
  window.gsap.fromTo(scene, { autoAlpha: 0.6, y: 8 }, { autoAlpha: 1, y: 0, duration: 0.38, ease: "power2.out" });
  window.gsap.fromTo(markers, { scale: 0.65, autoAlpha: 0.4 }, { scale: 1, autoAlpha: 1, duration: 0.32, ease: "back.out(1.8)", stagger: 0.05 });
}

function animateHotspotInspect(hotspotButton) {
  if (!window.gsap) return;
  const scene = document.getElementById("scene-stage");
  const x = hotspotButton.style.left || "50%";
  const y = hotspotButton.style.top || "50%";
  scene.style.transformOrigin = `${x} ${y}`;
  window.gsap.timeline()
    .to(hotspotButton, { scale: 1.24, duration: 0.12, ease: "power2.out" })
    .to(hotspotButton, { scale: 1, duration: 0.2, ease: "power2.inOut" }, "-=0.04")
    .to(scene, { scale: 1.03, duration: 0.16, ease: "power2.out" }, 0)
    .to(scene, { scale: 1, duration: 0.26, ease: "power2.inOut" }, 0.16);
}

function beginAudioSession() {
  if (audioEnabled) return;
  audioEnabled = true;
  playAmbientForRoom(currentRoom);
}

function playAmbientForRoom(roomId) {
  if (!audioEnabled) return;
  if (window.Howl && USE_FILE_AMBIENCE) {
    crossfadeHowlAmbient(roomId);
    return;
  }
  crossfadeProceduralAmbient(roomId);
}

function stopAmbient() {
  stopHowlAmbient();
  stopProceduralLayers();
}

function crossfadeHowlAmbient(roomId) {
  const trackPath = AMBIENT_TRACKS[roomId];
  const nextAmbient = new window.Howl({
    src: [trackPath],
    loop: true,
    volume: 0,
    html5: true,
    onloaderror: () => {
      nextAmbient.unload();
      crossfadeProceduralAmbient(roomId);
    },
    onplayerror: () => {
      nextAmbient.unload();
      crossfadeProceduralAmbient(roomId);
    }
  });
  nextAmbient.once("play", () => {
    nextAmbient.fade(0, 0.2, AMBIENT_CROSSFADE_MS);
    if (activeAmbientHowl) {
      const outgoing = activeAmbientHowl;
      outgoing.fade(outgoing.volume(), 0, AMBIENT_CROSSFADE_MS);
      window.setTimeout(() => {
        outgoing.stop();
        outgoing.unload();
      }, AMBIENT_CROSSFADE_MS + 40);
    }
    stopProceduralLayers();
    activeAmbientHowl = nextAmbient;
  });
  nextAmbient.play();
}

function crossfadeProceduralAmbient(roomId) {
  stopHowlAmbient();
  const nextLayer = createProceduralLayer(roomId);
  if (!nextLayer) return;
  nextLayer.gain.gain.setValueAtTime(0, ambientContext.currentTime);
  nextLayer.gain.gain.linearRampToValueAtTime(0.02, ambientContext.currentTime + AMBIENT_CROSSFADE_MS / 1000);
  const outgoingLayers = ambientNodes.slice();
  outgoingLayers.forEach(layer => {
    layer.gain.gain.cancelScheduledValues(ambientContext.currentTime);
    layer.gain.gain.setValueAtTime(layer.gain.gain.value, ambientContext.currentTime);
    layer.gain.gain.linearRampToValueAtTime(0.0001, ambientContext.currentTime + AMBIENT_CROSSFADE_MS / 1000);
    window.setTimeout(() => stopProceduralLayer(layer), AMBIENT_CROSSFADE_MS + 50);
  });
  ambientNodes = [nextLayer];
}

function stopHowlAmbient() {
  if (!activeAmbientHowl) return;
  activeAmbientHowl.stop();
  activeAmbientHowl.unload();
  activeAmbientHowl = null;
}

function stopProceduralLayers() {
  ambientNodes.forEach(layer => stopProceduralLayer(layer));
  ambientNodes = [];
}

function stopProceduralLayer(layer) {
  if (layer.stopped) return;
  layer.oscillator.stop();
  layer.lfo.stop();
  layer.stopped = true;
}

function createProceduralLayer(roomId) {
  if (!ensureAudioContext()) return null;
  const oscillator = ambientContext.createOscillator();
  const lfo = ambientContext.createOscillator();
  const lfoGain = ambientContext.createGain();
  const gain = ambientContext.createGain();
  oscillator.type = "triangle";
  oscillator.frequency.value = ROOM_FREQUENCIES[roomId] || 136;
  lfo.type = "sine";
  lfo.frequency.value = 0.12;
  lfoGain.gain.value = 14;
  gain.gain.value = 0.02;
  lfo.connect(lfoGain);
  lfoGain.connect(oscillator.frequency);
  oscillator.connect(gain);
  gain.connect(ambientContext.destination);
  oscillator.start();
  lfo.start();
  return { oscillator, lfo, gain };
}

function ensureAudioContext() {
  if (!window.AudioContext && !window.webkitAudioContext) return false;
  if (!ambientContext) ambientContext = new (window.AudioContext || window.webkitAudioContext)();
  if (ambientContext.state === "suspended") ambientContext.resume();
  return true;
}

function playHotspotSfx(itemId) {
  if (!audioEnabled) return;
  if (window.Howl && USE_FILE_SFX && HOTSPOT_SFX_TRACKS[itemId]) {
    const oneShot = new window.Howl({
      src: [HOTSPOT_SFX_TRACKS[itemId]],
      volume: itemId === "locked" ? 0.2 : 0.28
    });
    oneShot.once("end", () => oneShot.unload());
    oneShot.play();
    return;
  }
  playProceduralSfx(itemId);
}

function playProceduralSfx(itemId) {
  if (!ensureAudioContext()) return;
  const now = ambientContext.currentTime;
  const oscillator = ambientContext.createOscillator();
  const gain = ambientContext.createGain();
  const filter = ambientContext.createBiquadFilter();
  const profile = getSfxProfile(itemId);
  oscillator.type = profile.wave;
  oscillator.frequency.setValueAtTime(profile.startHz, now);
  oscillator.frequency.exponentialRampToValueAtTime(profile.endHz, now + profile.duration);
  filter.type = "lowpass";
  filter.frequency.setValueAtTime(profile.filterHz, now);
  gain.gain.setValueAtTime(0.0001, now);
  gain.gain.exponentialRampToValueAtTime(profile.peak, now + profile.attack);
  gain.gain.exponentialRampToValueAtTime(0.0001, now + profile.duration);
  oscillator.connect(filter);
  filter.connect(gain);
  gain.connect(ambientContext.destination);
  oscillator.start(now);
  oscillator.stop(now + profile.duration + 0.02);
}

function getSfxProfile(itemId) {
  switch (itemId) {
    case "champagne":
      return { wave: "sine", startHz: 660, endHz: 980, filterHz: 2200, attack: 0.02, duration: 0.22, peak: 0.08 };
    case "cards":
      return { wave: "triangle", startHz: 430, endHz: 250, filterHz: 1400, attack: 0.01, duration: 0.18, peak: 0.06 };
    case "recorder":
      return { wave: "sawtooth", startHz: 300, endHz: 180, filterHz: 1200, attack: 0.02, duration: 0.26, peak: 0.07 };
    case "glass":
      return { wave: "sine", startHz: 1200, endHz: 860, filterHz: 2600, attack: 0.01, duration: 0.14, peak: 0.06 };
    case "terminal":
      return { wave: "square", startHz: 420, endHz: 520, filterHz: 1800, attack: 0.01, duration: 0.2, peak: 0.07 };
    case "briefcase":
      return { wave: "triangle", startHz: 220, endHz: 160, filterHz: 1000, attack: 0.02, duration: 0.24, peak: 0.08 };
    case "locked":
      return { wave: "square", startHz: 240, endHz: 170, filterHz: 900, attack: 0.005, duration: 0.16, peak: 0.06 };
    default:
      return { wave: "sine", startHz: 360, endHz: 300, filterHz: 1400, attack: 0.01, duration: 0.15, peak: 0.06 };
  }
}

function logOutput(msg) {
  const logPanel = document.getElementById("log-output");
  logPanel.innerHTML = `<p class="log-entry">${msg.replace(/^>\s*/, "")}</p>`;
}

function updateDiscoveryCount() {
  const countText = `${discoveredHotspots.size} / ${TOTAL_DISCOVERIES} Discoveries`;
  document.getElementById("keyword-count").innerText = countText;
  document.getElementById("notebook-pill").innerText = `Notebook: ${discoveredHotspots.size}/${TOTAL_DISCOVERIES}`;
}

document.addEventListener("DOMContentLoaded", () => {
  document.body.addEventListener("pointerdown", beginAudioSession, { once: true });
  updateDiscoveryCount();
  switchRoom("living");
});