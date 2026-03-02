/* ============================================ */
/* Lover's Compass — App Logic                  */
/* ============================================ */

// ---- Constants ----
const UPDATE_INTERVAL = 3000;   // Send location every 3s
const POLL_INTERVAL = 2000;     // Poll partner location every 2s
const POKE_POLL_INTERVAL = 5000;// Poll pokes every 5s
const WAIT_POLL_INTERVAL = 3000;// Poll while waiting for partner

// ---- App State ----
const state = {
  deviceId: null,
  coupleId: null,
  role: null,
  isSharing: true,
  myLat: null,
  myLng: null,
  partnerLat: null,
  partnerLng: null,
  partnerStaleness: null,
  deviceHeading: null,
  currentRotation: 0,
  targetRotation: 0,
  currentHeading: 0,
  watchId: null,
  updateTimer: null,
  pollTimer: null,
  pokePollTimer: null,
  waitingTimer: null,
  pokeTimeout: null,
  isOnline: navigator.onLine,
  pokeQueue: [],
  networkRetryCount: 0,
  lastSrDirection: null,
  lastGPSUpdate: null,
  lastPartnerPoll: null,
  headingCheckTimer: null,
  debugVisible: false,
  staleCheckTimer: null,
};

// ---- DOM References ----
const $ = (id) => document.getElementById(id);

// ---- Initialize ----
function init() {
  state.deviceId = localStorage.getItem('device_id') || generateUUID();
  localStorage.setItem('device_id', state.deviceId);

  state.coupleId = localStorage.getItem('couple_id');
  state.role = localStorage.getItem('role');

  // Generate tick marks for compass
  generateTickMarks();

  if (localStorage.getItem('lc_demo_mode') === 'true') {
    startDemoMode();
  } else if (state.coupleId) {
    // Validate stored couple_id against backend before showing compass
    validateAndReconnect();
  } else {
    showScreen('pair');
    injectDemoButton();
  }

  // Register service worker
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js').catch(() => {});
  }

  // Network status listeners
  window.addEventListener('online', handleOnline);
  window.addEventListener('offline', handleOffline);
  updateNetworkUI();
  checkHttps();

  // Dismiss splash screen
  dismissSplash();
}

function dismissSplash() {
  var splash = $('splash-screen');
  if (!splash) return;
  setTimeout(function() {
    splash.classList.add('fade-out');
    setTimeout(function() { splash.remove(); }, 400);
  }, 600);
}

function showCompassLoading(show) {
  var loading = $('compass-loading');
  var main = $('compass-main');
  if (!loading || !main) return;
  if (show) {
    loading.classList.remove('hidden');
    main.style.display = 'none';
  } else {
    loading.classList.add('hidden');
    main.style.display = '';
  }
}

// ---- UUID Generation ----
function generateUUID() {
  if (crypto && crypto.randomUUID) return crypto.randomUUID();
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
    var r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

// ---- Screen Management ----
function showScreen(name) {
  ['screen-pair', 'screen-compass', 'screen-settings'].forEach((id) => {
    $(id).classList.add('hidden');
  });
  $('screen-' + name).classList.remove('hidden');

  // Reset pair sub-sections to avoid overlap when returning to pair screen
  if (name === 'pair') {
    $('join-section').classList.add('hidden');
    $('waiting-section').classList.add('hidden');
    $('pair-buttons').classList.remove('hidden');
    var demoBtn = $('btn-demo'); if (demoBtn) demoBtn.classList.remove('hidden');
    $('btn-create').disabled = false;
    $('btn-create').textContent = 'Create a new compass';
    $('join-code').value = '';
  }

  if (name === 'settings') {
    $('settings-code').textContent = state.coupleId || '';
  }
}

// ---- Pair Screen Logic ----
function showJoinSection() {
  var demoBtn = $("btn-demo"); if (demoBtn) demoBtn.classList.add("hidden");
  $('pair-buttons').classList.add('hidden');
  $('join-section').classList.remove('hidden');
  $('join-code').focus();
}

function showPairButtons() {
  var demoBtn = $("btn-demo"); if (demoBtn) demoBtn.classList.remove("hidden");
  $('join-section').classList.add('hidden');
  $('pair-buttons').classList.remove('hidden');
}

async function createCompass() {
  const btn = $('btn-create');
  btn.disabled = true;
  btn.textContent = 'Creating...';

  try {
    const result = await apiCall('POST', '/pair', {
      action: 'create',
      device_id: state.deviceId,
    });

    if (result.detail) {
      showToast(result.detail);
      btn.disabled = false;
      btn.textContent = 'Create a new compass';
      return;
    }

    state.coupleId = result.couple_id;
    state.role = 'creator';
    localStorage.setItem('couple_id', state.coupleId);
    localStorage.setItem('role', state.role);

    // Show waiting state
    $('pair-buttons').classList.add('hidden');
    var demoBtn = $('btn-demo'); if (demoBtn) demoBtn.classList.add('hidden');
    $('waiting-section').classList.remove('hidden');
    $('waiting-code').textContent = state.coupleId;

    // Start location tracking in background
    startLocationTracking();

    // Poll for partner
    state.waitingTimer = setInterval(async () => {
      try {
        const partner = await apiCall(
          'GET',
          '/partnerLocation?couple_id=' + state.coupleId + '&device_id=' + state.deviceId
        );
        if (partner.partner_found) {
          clearInterval(state.waitingTimer);
          state.waitingTimer = null;
          showScreen('compass');
          showCompassLoading(true);
          startCompass();
        }
      } catch (e) {
        // Silently retry
      }
    }, WAIT_POLL_INTERVAL);
  } catch (e) {
    showToast('Something went wrong. Please try again.');
    btn.disabled = false;
    btn.textContent = 'Create a new compass';
  }
}

function cancelWaiting() {
  if (state.waitingTimer) {
    clearInterval(state.waitingTimer);
    state.waitingTimer = null;
  }
  stopLocationTracking();
  state.coupleId = null;
  state.role = null;
  localStorage.removeItem('couple_id');
  localStorage.removeItem('role');

  $('waiting-section').classList.add('hidden');
  $('pair-buttons').classList.remove('hidden');
  $('btn-create').disabled = false;
  var demoBtn = $("btn-demo"); if (demoBtn) demoBtn.classList.remove("hidden");
  $('btn-create').textContent = 'Create a new compass';
}

async function joinCompass() {
  const code = $('join-code').value.trim().toUpperCase();
  if (code.length !== 8) {
    showToast('Please enter an 8-character code');
    return;
  }

  const btn = $('btn-join');
  btn.disabled = true;
  btn.textContent = 'Connecting...';

  try {
    const result = await apiCall('POST', '/pair', {
      action: 'join',
      couple_id: code,
      device_id: state.deviceId,
    });

    if (result.detail) {
      showToast(result.detail);
      btn.disabled = false;
      btn.textContent = 'Connect';
      return;
    }

    state.coupleId = result.couple_id;
    state.role = 'partner';
    localStorage.setItem('couple_id', state.coupleId);
    localStorage.setItem('role', state.role);

    showScreen('compass');
    showCompassLoading(true);
    startCompass();
  } catch (e) {
    showToast('Failed to connect. Check the code and try again.');
    btn.disabled = false;
    btn.textContent = 'Connect';
  }
}

// ---- Demo Mode ----
function startDemoMode() {
  window.demoMode = true;
  window.demoPartnerLat = 90.0;
  window.demoPartnerLng = 0.0;
  localStorage.setItem('lc_device_id', 'DEMO-DEVICE');
  localStorage.setItem('lc_demo_mode', 'true');

  // Inject demo banner into compass screen if not present
  if (!$('demo-banner')) {
    var banner = document.createElement('div');
    banner.id = 'demo-banner';
    banner.className = 'demo-banner';
    banner.setAttribute('role', 'status');
    banner.innerHTML = '❤️ Heart points North (demo)';
    $('screen-compass').insertBefore(banner, $('screen-compass').firstChild);
  }

  showScreen('compass');
  showCompassLoading(false);
  startCompass();
}

function exitDemoMode() {
  window.demoMode = false;
  window.demoPartnerLat = null;
  window.demoPartnerLng = null;
  localStorage.removeItem('lc_device_id');
  localStorage.removeItem('lc_demo_mode');
  var banner = $('demo-banner');
  if (banner) banner.remove();
}

function injectDemoButton() {
  if ($('btn-demo')) return;
  var btn = document.createElement('button');
  btn.id = 'btn-demo';
  btn.className = 'demo-btn';
  btn.textContent = 'Try Demo';
  btn.onclick = startDemoMode;
  // Insert after pair-buttons section
  var pairButtons = $('pair-buttons');
  pairButtons.parentNode.insertBefore(btn, pairButtons.nextSibling);
}

// ---- Compass Logic ----
function startCompass() {
  startLocationTracking();
  startPartnerPolling();
  startPokePolling();
  startDeviceOrientation();
  startNeedleAnimation();
  startStaleCheck();
  setupDebugToggle();
  updateSharingUI();
}

function stopCompass() {
  stopLocationTracking();
  if (state.pollTimer) {
    clearInterval(state.pollTimer);
    state.pollTimer = null;
  }
  if (state.pokePollTimer) {
    clearInterval(state.pokePollTimer);
    state.pokePollTimer = null;
  }
  if (_needleRAF) {
    cancelAnimationFrame(_needleRAF);
    _needleRAF = null;
  }
  if (state.headingCheckTimer) {
    clearTimeout(state.headingCheckTimer);
    state.headingCheckTimer = null;
  }
  if (state.staleCheckTimer) {
    clearInterval(state.staleCheckTimer);
    state.staleCheckTimer = null;
  }
}

// ---- Location Tracking ----
function startLocationTracking() {
  if (state.watchId !== null) return;
  if (!navigator.geolocation) {
    showToast('Location services not available');
    return;
  }

  state.watchId = navigator.geolocation.watchPosition(
    function (pos) {
      state.myLat = pos.coords.latitude;
      state.myLng = pos.coords.longitude;
      state.lastGPSUpdate = Date.now();
      hideGpsError();
      // Recalculate compass on every GPS update
      updateCompassDisplay();
    },
    function (err) {
      if (err.code === 1) {
        // PERMISSION_DENIED
        showGpsError('Location Access Needed', 'Lover\u2019s Compass needs your location to point you toward your partner. Please allow location access to continue.');
      } else if (err.code === 2) {
        // POSITION_UNAVAILABLE
        showGpsError('Location Unavailable', 'Your device can\u2019t determine its location right now. Make sure location services are enabled and try again.');
      } else if (err.code === 3) {
        // TIMEOUT
        showGpsError('Location Timeout', 'It\u2019s taking too long to find your location. Make sure you have a clear view of the sky or a stable connection.');
      }
    },
    { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 }
  );

  // Send location periodically
  sendLocation();
  state.updateTimer = setInterval(sendLocation, UPDATE_INTERVAL);
}

function stopLocationTracking() {
  if (state.watchId !== null) {
    navigator.geolocation.clearWatch(state.watchId);
    state.watchId = null;
  }
  if (state.updateTimer) {
    clearInterval(state.updateTimer);
    state.updateTimer = null;
  }
}

async function sendLocation() {
  if (window.demoMode) return;
  if (!state.coupleId || state.myLat === null) return;
  if (!state.isOnline) return;
  try {
    await apiCall('POST', '/updateLocation', {
      couple_id: state.coupleId,
      device_id: state.deviceId,
      latitude: state.myLat,
      longitude: state.myLng,
      is_sharing: state.isSharing,
    });
    state.networkRetryCount = 0;
  } catch (e) {
    state.networkRetryCount++;
  }
}

// ---- Partner Polling ----
function startPartnerPolling() {
  if (state.pollTimer) return;

  pollPartner();
  state.pollTimer = setInterval(pollPartner, POLL_INTERVAL);
}

async function pollPartner() {
  if (window.demoMode) {
    state.partnerLat = window.demoPartnerLat;
    state.partnerLng = window.demoPartnerLng;
    state.partnerStaleness = 0;
    state.lastPartnerPoll = Date.now();
    showCompassLoading(false);
    updatePartnerStatusUI();
    updateCompassDisplay();
    return;
  }
  if (!state.coupleId) return;
  try {
    const result = await apiCall(
      'GET',
      '/partnerLocation?couple_id=' + state.coupleId + '&device_id=' + state.deviceId
    );

    if (result.partner_found && result.is_sharing && result.latitude != null && result.longitude != null) {
      state.partnerLat = result.latitude;
      state.partnerLng = result.longitude;
      state.partnerStaleness = result.staleness_seconds || 0;
      state.lastPartnerPoll = Date.now();
      state.networkRetryCount = 0;
      showCompassLoading(false);
      updatePartnerStatusUI();
      updateCompassDisplay();
    } else if (result.partner_found && !result.is_sharing) {
      state.partnerLat = null;
      state.partnerLng = null;
      state.partnerStaleness = result.staleness_seconds || null;
      showCompassLoading(false);
      updatePartnerStatusUI();
      $('distance-text').textContent = 'Waiting for partner\u2019s location\u2026';
      setNeedleRotation(0);
    } else {
      state.partnerStaleness = null;
      showCompassLoading(false);
      updatePartnerStatusUI();
      $('distance-text').textContent = 'Waiting for your partner to connect\u2026';
    }
  } catch (e) {
    // Silently retry
  }
}

function updatePartnerStatusUI() {
  var dot = $('partner-dot');
  var text = $('partner-status-text');
  if (!dot || !text) return;

  if (state.partnerStaleness === null) {
    dot.className = 'dot dot-gray';
    text.textContent = 'Partner offline';
    return;
  }

  var staleSeconds = state.partnerStaleness;
  if (staleSeconds <= 120) {
    // Online: last update within 2 minutes
    dot.className = 'dot dot-green-pulse';
    text.textContent = 'Partner online';
  } else {
    // Offline: show last seen
    dot.className = 'dot dot-gray';
    var mins = Math.floor(staleSeconds / 60);
    if (mins < 60) {
      text.textContent = 'Last seen ' + mins + 'm ago';
    } else {
      var hrs = Math.floor(mins / 60);
      text.textContent = 'Last seen ' + hrs + 'h ago';
    }
  }
}

// ---- Compass Display ----
function updateCompassDisplay() {
  if (state.myLat === null || state.partnerLat === null) return;

  const bearing = calculateBearing(state.myLat, state.myLng, state.partnerLat, state.partnerLng);
  const distance = calculateDistance(state.myLat, state.myLng, state.partnerLat, state.partnerLng);

  // Adjust for device heading
  let needleBearing = bearing;
  if (state.deviceHeading !== null) {
    needleBearing = bearing - state.deviceHeading;
  }

  console.log('[Compass] bearing:', bearing.toFixed(1), 'heading:', state.deviceHeading, 'rotation:', needleBearing.toFixed(1));

  setNeedleRotation(needleBearing);
  updateDistanceText(distance);

  // Update cardinal direction text
  var directions = ['North', 'Northeast', 'East', 'Southeast', 'South', 'Southwest', 'West', 'Northwest'];
  var dirIndex = Math.round(bearing / 45) % 8;
  var dirEl = $('direction-text');
  if (dirEl) dirEl.textContent = 'Your partner is ' + directions[dirIndex];

  announceDirection(bearing, distance);
  updateDebugOverlay();
}

function announceDirection(bearing, distKm) {
  var directions = ['North', 'Northeast', 'East', 'Southeast', 'South', 'Southwest', 'West', 'Northwest'];
  var index = Math.round(bearing / 45) % 8;
  var dir = directions[index];

  // Only announce if direction changed
  if (dir === state.lastSrDirection) return;
  state.lastSrDirection = dir;

  var distMiles = distKm * 0.621371;
  var distText;
  if (distMiles < 0.01) {
    distText = 'right next to each other';
  } else if (distMiles < 1) {
    distText = Math.round(distKm * 3280.84) + ' feet away';
  } else {
    distText = distMiles.toFixed(1) + ' miles away';
  }

  var el = $('compass-sr-announcement');
  if (el) {
    el.textContent = 'Partner is ' + dir + ', ' + distText;
  }
}

function setNeedleRotation(targetDeg) {
  // Normalize to 0-360
  targetDeg = ((targetDeg % 360) + 360) % 360;

  // Find shortest rotation path from current target
  var currentNorm = ((state.targetRotation % 360) + 360) % 360;
  var diff = targetDeg - currentNorm;
  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;

  state.targetRotation += diff;
}

// ---- Smooth Needle Animation Loop ----
var _needleRAF = null;
function startNeedleAnimation() {
  if (_needleRAF) return;
  function animate() {
    // Lerp needle rotation
    var diff = state.targetRotation - state.currentRotation;
    if (Math.abs(diff) > 0.5) {
      var step = diff * 0.2;
      if (Math.abs(step) > 10) step = Math.sign(step) * 10;
      state.currentRotation += step;
    } else {
      state.currentRotation = state.targetRotation;
    }
    var needle = $('compass-needle');
    if (needle) {
      needle.style.transform = 'rotate(' + state.currentRotation + 'deg)';
    }

    // Lerp heading for cardinal labels (smooth counter-rotation)
    if (state.deviceHeading !== null) {
      var targetH = state.deviceHeading;
      // Find shortest path
      var hDiff = targetH - ((state.currentHeading % 360) + 360) % 360;
      if (hDiff > 180) hDiff -= 360;
      if (hDiff < -180) hDiff += 360;
      var hStep = hDiff * 0.15;
      if (Math.abs(hDiff) > 0.5) {
        state.currentHeading += hStep;
      } else {
        state.currentHeading = targetH;
      }
    }
    var cardinals = $('compass-cardinals');
    if (cardinals) {
      cardinals.style.transform = 'rotate(' + (-state.currentHeading) + 'deg)';
    }

    _needleRAF = requestAnimationFrame(animate);
  }
  _needleRAF = requestAnimationFrame(animate);
}

function updateDistanceText(distKm) {
  var el = $('distance-text');
  var distMiles = distKm * 0.621371;
  var distFeet = distKm * 3280.84;

  if (distFeet < 50) {
    el.innerHTML = '<span class="distance-close">Right next to each other!</span>';
  } else if (distMiles < 0.5) {
    var feet = Math.round(distFeet);
    el.innerHTML = 'You are <span class="distance-value">' + feet + ' ft</span> apart';
  } else if (distMiles < 100) {
    var miles = distMiles.toFixed(1);
    el.innerHTML = 'You are <span class="distance-value">' + miles + ' mi</span> apart';
  } else {
    var miles = Math.round(distMiles);
    el.innerHTML = 'You are <span class="distance-value">' + miles + ' mi</span> apart';
  }
}

// ---- Geolocation Math ----
function calculateBearing(lat1, lon1, lat2, lon2) {
  var dLon = toRad(lon2 - lon1);
  var la1 = toRad(lat1);
  var la2 = toRad(lat2);

  var y = Math.sin(dLon) * Math.cos(la2);
  var x = Math.cos(la1) * Math.sin(la2) - Math.sin(la1) * Math.cos(la2) * Math.cos(dLon);

  var brng = Math.atan2(y, x);
  return ((brng * 180) / Math.PI + 360) % 360;
}

function calculateDistance(lat1, lon1, lat2, lon2) {
  var R = 6371; // km
  var dLat = toRad(lat2 - lat1);
  var dLon = toRad(lon2 - lon1);
  var a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg) {
  return (deg * Math.PI) / 180;
}

// ---- Device Orientation ----
function startDeviceOrientation() {
  if (typeof DeviceOrientationEvent !== 'undefined' && typeof DeviceOrientationEvent.requestPermission === 'function') {
    // iOS 13+ — try requesting immediately (works if called from user gesture)
    requestOrientationPermission();
  } else {
    window.addEventListener('deviceorientationabsolute', handleOrientation, true);
    window.addEventListener('deviceorientation', handleOrientation, true);
  }
  // If no heading after 3 seconds, show enable button
  startHeadingCheck();
}

function handleOrientation(event) {
  var heading = null;

  if (event.webkitCompassHeading !== undefined) {
    // iOS Safari
    heading = event.webkitCompassHeading;
  } else if (event.alpha !== null) {
    // Android / others
    if (event.absolute) {
      heading = (360 - event.alpha) % 360;
    } else {
      heading = (360 - event.alpha) % 360;
    }
  }

  if (heading !== null) {
    state.deviceHeading = heading;
    hideEnableCompassButton();
    var hint = $('heading-hint');
    if (hint) hint.classList.add('hidden');
    // Update target on every heading change; rAF loop handles smooth rendering
    updateCompassDisplay();
  }
}

// ---- Poke System ----
async function sendPoke() {
  var btn = $('btn-poke');
  if (btn.classList.contains('poked')) return;
  btn.classList.add('poked');

  // Swap label to "Sent!"
  var label = btn.querySelector('span');
  var origText = label.textContent;
  label.textContent = 'Sent!';

  if (window.demoMode) {
    showToast('\uD83D\uDC8C Poke sent!', true);
  } else if (!state.isOnline) {
    // Queue poke for when we're back online
    state.pokeQueue.push({
      couple_id: state.coupleId,
      device_id: state.deviceId,
    });
    showToast('You\u2019re offline \u2014 poke will send when reconnected');
  } else {
    if (!state.coupleId) return;
    try {
      await apiCall('POST', '/poke', {
        couple_id: state.coupleId,
        device_id: state.deviceId,
      });
      showToast('Poke sent!', true);
    } catch (e) {
      showToast('Could not send poke. Try again.');
    }
  }

  // Vibrate for haptic feedback
  if (navigator.vibrate) navigator.vibrate(50);

  // Reset button after cooldown
  if (state.pokeTimeout) clearTimeout(state.pokeTimeout);
  state.pokeTimeout = setTimeout(function () {
    btn.classList.remove('poked');
    label.textContent = origText;
  }, 3000);
}

function startPokePolling() {
  if (window.demoMode) return;
  if (state.pokePollTimer) return;

  state.pokePollTimer = setInterval(async function () {
    if (!state.coupleId) return;
    try {
      var result = await apiCall(
        'GET',
        '/pokes?couple_id=' + state.coupleId + '&device_id=' + state.deviceId
      );
      if (result.pokes > 0) {
        showPokeBanner();
      }
    } catch (e) {
      // Silently retry
    }
  }, POKE_POLL_INTERVAL);
}

function showPokeBanner() {
  var banner = $('poke-banner');
  banner.textContent = 'Your partner is thinking of you!';
  banner.classList.remove('hidden');
  banner.classList.add('visible');

  // Vibrate if supported
  if (navigator.vibrate) navigator.vibrate([200, 100, 200]);

  setTimeout(function () {
    banner.classList.remove('visible');
    setTimeout(function () {
      banner.classList.add('hidden');
    }, 400);
  }, 4000);
}

// ---- Sharing Toggle ----
function toggleSharing() {
  state.isSharing = $('sharing-checkbox').checked;
  updateSharingUI();
  sendLocation();
}

function updateSharingUI() {
  var dot = $('sharing-dot');
  var label = $('sharing-label');
  var checkbox = $('sharing-checkbox');

  checkbox.checked = state.isSharing;

  if (state.isSharing) {
    dot.className = 'dot dot-green';
    label.textContent = 'Sharing';
  } else {
    dot.className = 'dot dot-gray';
    label.textContent = 'Paused';
  }
}

// ---- Settings ----
async function unpair() {
  if (!confirm('Disconnect from your partner? This will remove all shared data.')) return;

  // Call backend to delete couple data
  if (state.coupleId && !window.demoMode && state.isOnline) {
    try {
      await apiCall(
        'DELETE',
        '/api/pair/' + state.coupleId + '?device_id=' + state.deviceId
      );
    } catch (e) {
      // Continue with local cleanup even if server call fails
    }
  }

  stopCompass();
  state.coupleId = null;
  state.role = null;
  state.myLat = null;
  state.myLng = null;
  state.partnerLat = null;
  state.partnerLng = null;
  state.isSharing = true;
  state.currentRotation = 0;
  state.targetRotation = 0;
  state.currentHeading = 0;
  state.pokeQueue = [];
  state.lastGPSUpdate = null;
  state.lastPartnerPoll = null;
  state.debugVisible = false;

  localStorage.removeItem('couple_id');
  localStorage.removeItem('role');

  // Clear demo mode if active
  if (window.demoMode) exitDemoMode();

  // Reset pair screen
  $('waiting-section').classList.add('hidden');
  $('join-section').classList.add('hidden');
  $('pair-buttons').classList.remove('hidden');
  $('btn-create').disabled = false;
  $('btn-create').textContent = 'Create a new compass';
  $('join-code').value = '';

  showScreen('pair');
  showToast('Unpaired successfully');
}

function copyCode() {
  if (!state.coupleId) return;
  if (navigator.clipboard) {
    navigator.clipboard.writeText(state.coupleId).then(function () {
      showToast('Code copied!');
    });
  } else {
    // Fallback
    var ta = document.createElement('textarea');
    ta.value = state.coupleId;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
    showToast('Code copied!');
  }
}

// ---- API Helper ----
async function apiCall(method, path, body) {
  var options = {
    method: method,
    headers: { 'Content-Type': 'application/json' },
  };
  if (body) options.body = JSON.stringify(body);

  var response = await fetch(path, options);
  return response.json();
}

// ---- Toast ----
var toastTimer = null;
function showToast(message, isLove) {
  var toast = $('toast');
  toast.textContent = message;
  toast.className = 'toast' + (isLove ? ' toast-love' : '');

  if (toastTimer) clearTimeout(toastTimer);

  // Force reflow for animation
  void toast.offsetWidth;

  toastTimer = setTimeout(function () {
    toast.classList.add('hidden');
    toastTimer = null;
  }, 2500);
}

// ---- Compass Tick Marks ----
function generateTickMarks() {
  var container = $('tick-marks');
  if (!container) return;

  for (var i = 0; i < 360; i += 10) {
    // Skip cardinal positions
    if (i % 90 === 0) continue;
    var tick = document.createElement('div');
    tick.className = 'tick' + (i % 30 === 0 ? ' major' : '');
    tick.style.transform = 'rotate(' + i + 'deg)';
    container.appendChild(tick);
  }
}

// ---- GPS Permission Error ----
function showGpsError(title, message) {
  var banner = $('gps-error-banner');
  if (!banner) return;
  if (title) {
    var titleEl = banner.querySelector('.gps-error-title');
    if (titleEl) titleEl.textContent = title;
  }
  if (message) {
    var textEl = banner.querySelector('.gps-error-text');
    if (textEl) textEl.textContent = message;
  }
  banner.classList.remove('hidden');
}

function hideGpsError() {
  var banner = $('gps-error-banner');
  if (banner) banner.classList.add('hidden');
}

function retryLocationPermission() {
  hideGpsError();
  stopLocationTracking();
  navigator.geolocation.getCurrentPosition(
    function (pos) {
      startLocationTracking();
    },
    function (err) {
      if (err.code === 1) {
        showGpsError('Location Access Needed', 'Please allow location access in your browser or device settings.');
      } else if (err.code === 2) {
        showGpsError('Location Unavailable', 'Your device can\u2019t determine its location. Check that location services are enabled.');
      } else {
        showGpsError('Location Timeout', 'It\u2019s taking too long to find your location. Please try again.');
      }
    },
    { enableHighAccuracy: true, timeout: 15000 }
  );
}

// ---- Network Status ----
function handleOnline() {
  state.isOnline = true;
  state.networkRetryCount = 0;
  updateNetworkUI();
  // Flush queued pokes
  flushPokeQueue();
  // Resume sending location immediately
  sendLocation();
}

function handleOffline() {
  state.isOnline = false;
  updateNetworkUI();
}

function updateNetworkUI() {
  var indicator = $('offline-indicator');
  if (!indicator) return;
  if (state.isOnline) {
    indicator.classList.add('hidden');
  } else {
    indicator.classList.remove('hidden');
  }
}

async function flushPokeQueue() {
  while (state.pokeQueue.length > 0) {
    var poke = state.pokeQueue[0];
    try {
      await apiCall('POST', '/poke', poke);
      state.pokeQueue.shift();
    } catch (e) {
      break;
    }
  }
  if (state.pokeQueue.length === 0) return;
}

// ---- Orientation Permission ----
function requestOrientationPermission() {
  DeviceOrientationEvent.requestPermission()
    .then(function (response) {
      if (response === 'granted') {
        window.addEventListener('deviceorientationabsolute', handleOrientation, true);
        window.addEventListener('deviceorientation', handleOrientation, true);
      }
    })
    .catch(function () {
      // Requires user gesture — show enable button
      showEnableCompassButton();
    });
}

function startHeadingCheck() {
  if (state.headingCheckTimer) clearTimeout(state.headingCheckTimer);
  state.headingCheckTimer = setTimeout(function () {
    if (state.deviceHeading === null) {
      showEnableCompassButton();
    }
  }, 3000);
}

function showEnableCompassButton() {
  // Only show on iOS where permission can be re-requested
  if (typeof DeviceOrientationEvent === 'undefined' || typeof DeviceOrientationEvent.requestPermission !== 'function') return;
  var btn = $('btn-enable-compass');
  if (btn) btn.classList.remove('hidden');
}

function hideEnableCompassButton() {
  var btn = $('btn-enable-compass');
  if (btn) btn.classList.add('hidden');
}

function enableCompass() {
  if (typeof DeviceOrientationEvent !== 'undefined' && typeof DeviceOrientationEvent.requestPermission === 'function') {
    DeviceOrientationEvent.requestPermission()
      .then(function (response) {
        if (response === 'granted') {
          window.addEventListener('deviceorientationabsolute', handleOrientation, true);
          window.addEventListener('deviceorientation', handleOrientation, true);
          hideEnableCompassButton();
        }
      })
      .catch(function () {
        showToast('Could not enable compass. Check your settings.');
      });
  }
}

// ---- HTTPS Check ----
function checkHttps() {
  if (location.protocol !== 'https:' && location.hostname !== 'localhost' && location.hostname !== '127.0.0.1') {
    var warning = $('https-warning');
    if (warning) warning.classList.remove('hidden');
  }
}

// ---- Debug Overlay ----
var _debugTaps = 0;
var _debugTapTimer = null;

function setupDebugToggle() {
  var wrapper = $('compass-main');
  if (!wrapper || wrapper._debugSetup) return;
  wrapper._debugSetup = true;
  wrapper.addEventListener('click', function () {
    _debugTaps++;
    if (_debugTapTimer) clearTimeout(_debugTapTimer);
    if (_debugTaps >= 3) {
      _debugTaps = 0;
      toggleDebugOverlay();
    } else {
      _debugTapTimer = setTimeout(function () { _debugTaps = 0; }, 500);
    }
  });
}

function toggleDebugOverlay() {
  state.debugVisible = !state.debugVisible;
  var overlay = $('debug-overlay');
  if (overlay) {
    overlay.classList.toggle('hidden', !state.debugVisible);
    if (state.debugVisible) updateDebugOverlay();
  }
}

function updateDebugOverlay() {
  if (!state.debugVisible) return;
  var overlay = $('debug-overlay');
  if (!overlay) return;
  var bearing = (state.myLat !== null && state.partnerLat !== null)
    ? calculateBearing(state.myLat, state.myLng, state.partnerLat, state.partnerLng).toFixed(1)
    : 'N/A';

  overlay.textContent =
    'myLat: ' + (state.myLat !== null ? state.myLat.toFixed(6) : 'null') + '\n' +
    'myLng: ' + (state.myLng !== null ? state.myLng.toFixed(6) : 'null') + '\n' +
    'pLat: ' + (state.partnerLat !== null ? state.partnerLat.toFixed(6) : 'null') + '\n' +
    'pLng: ' + (state.partnerLng !== null ? state.partnerLng.toFixed(6) : 'null') + '\n' +
    'bearing: ' + bearing + '\n' +
    'heading: ' + (state.deviceHeading !== null ? state.deviceHeading.toFixed(1) : 'null') + '\n' +
    'needle: ' + state.currentRotation.toFixed(1) + '\n' +
    'lastGPS: ' + (state.lastGPSUpdate ? new Date(state.lastGPSUpdate).toLocaleTimeString() : 'never') + '\n' +
    'lastPoll: ' + (state.lastPartnerPoll ? new Date(state.lastPartnerPoll).toLocaleTimeString() : 'never');
}

// ---- Stale Data Check ----
function startStaleCheck() {
  if (state.staleCheckTimer) return;
  state.staleCheckTimer = setInterval(checkStaleData, 2000);
}

function checkStaleData() {
  var now = Date.now();
  var gpsStale = $('gps-stale-text');
  var partnerStale = $('partner-stale-text');
  var hint = $('heading-hint');

  if (gpsStale) {
    var gpsIsStale = state.lastGPSUpdate !== null && (now - state.lastGPSUpdate > 10000);
    gpsStale.classList.toggle('hidden', !gpsIsStale);
  }

  if (partnerStale) {
    var partnerIsStale = state.lastPartnerPoll !== null && (now - state.lastPartnerPoll > 10000);
    partnerStale.classList.toggle('hidden', !partnerIsStale);
  }

  if (hint) {
    hint.classList.toggle('hidden', state.deviceHeading !== null);
  }

  updateDebugOverlay();
}

// ---- Start ----

// ---- Reconnect Validation ----
async function validateAndReconnect() {
  showScreen('compass');
  showCompassLoading(true);
  try {
    var result = await apiCall(
      'GET',
      '/partnerLocation?couple_id=' + state.coupleId + '&device_id=' + state.deviceId
    );
    // Check if the response indicates a valid couple
    if (result.detail || result.error) {
      throw new Error('Invalid couple');
    }
    // Valid - start compass
    startCompass();
  } catch (e) {
    // Couple no longer exists - clear and show pair screen
    console.log('Stored couple_id is stale, clearing...');
    state.coupleId = null;
    state.role = null;
    localStorage.removeItem('couple_id');
    localStorage.removeItem('role');
    showScreen('pair');
    injectDemoButton();
    showToast('Your previous session expired. Please pair again.');
  }
}
document.addEventListener('DOMContentLoaded', init);
