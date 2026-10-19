// Game State Database
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
  study: {
    terminal: { left: "81%", top: "36%" },
    briefcase: { left: "51%", top: "62%" }
  },
  pool: {
    recorder: { left: "9.5%", top: "39%" },
    glass: { left: "89%", top: "80%" }
  }
};

const KEYWORDS_DB = {
  champagne: "Broadhead Semiconductor",
  terminal: "Project Code: ARCHON",
  recorder: "Roger's Wiretap"
};

let currentRoom = "living";
let collectedKeywords = new Set();
let discoveredHotspots = new Set();
const TOTAL_DISCOVERIES = Object.values(ROOMS).reduce((total, room) => total + room.hotspots.length, 0);

// Room Switching Logic
function switchRoom(roomId) {
  if (!ROOMS[roomId]) return;
  currentRoom = roomId;

  // 1. Trigger haptic tick in iOS
  sendToNative("triggerHaptic", { style: "light" });

  // 2. Update UI active buttons
  document.querySelectorAll(".nav-btn").forEach(btn => btn.classList.remove("active"));
  document.getElementById(`nav-${roomId}`).classList.add("active");

  // 3. Render Room Data
  const room = ROOMS[roomId];
  const sceneStage = document.getElementById("scene-stage");
  if (sceneStage) sceneStage.className = `scene-stage room-${roomId}`;
  document.getElementById("room-tag").innerText = `${room.title} // ${room.subtitle}`;
  document.getElementById("scene-description").innerText = room.description;

  // 4. Render Hotspots
  const container = document.getElementById("hotspots-container");
  container.innerHTML = "";
  const roomPositions = HOTSPOT_POSITIONS[roomId] || {};
  
  room.hotspots.forEach(hs => {
    const btn = document.createElement("button");
    btn.className = "hotspot-btn";
    btn.dataset.itemId = hs.id;
    const position = roomPositions[hs.id] || { left: "50%", top: "50%" };
    btn.dataset.label = hs.label;
    btn.style.left = position.left;
    btn.style.top = position.top;
    btn.setAttribute("aria-label", hs.label);
    btn.setAttribute("title", hs.label);
    if (discoveredHotspots.has(hs.id)) btn.classList.add("is-seen");
    btn.onclick = () => inspectItem(hs.id, hs.haptic);
    container.appendChild(btn);
  });

  // 5. Console output
  logOutput(`> Entered ${room.title}.`);
}

// Inspect Object Action
function inspectItem(itemId, hapticStyle) {
  sendToNative("triggerHaptic", { style: hapticStyle });
  const firstDiscovery = !discoveredHotspots.has(itemId);
  discoveredHotspots.add(itemId);
  if (firstDiscovery) {
    updateDiscoveryCount();
    const activeDot = document.querySelector(`.hotspot-btn[data-item-id="${itemId}"]`);
    if (activeDot) activeDot.classList.add("is-seen");
  }

  // Check if item unlocks a keyword
  if (KEYWORDS_DB[itemId]) {
    unlockKeyword(KEYWORDS_DB[itemId]);
  }

  // Display sensory narrative log
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
  }
}

// Keyword Notebook Manager
function unlockKeyword(keyword) {
  if (collectedKeywords.has(keyword)) return;

  collectedKeywords.add(keyword);
  sendToNative("triggerHaptic", { style: "success" });

  // Update Keyword List UI
  const listEl = document.getElementById("keywords-list");
  if (collectedKeywords.size === 1) listEl.innerHTML = ""; // Clear empty hint

  const tag = document.createElement("span");
  tag.className = "keyword-tag";
  tag.innerText = keyword;
  listEl.appendChild(tag);
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

// Initialize default room on load
document.addEventListener("DOMContentLoaded", () => {
  updateDiscoveryCount();
  switchRoom("living");
});