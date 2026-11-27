function renderRelayGrid() {
      const container = document.getElementById('relayGrid');
      container.innerHTML = '';

      APP_STATE.channels.forEach((ch) => {
        const card = document.createElement('div');
        card.className = `relay-card ${ch.state ? 'energized' : ''} ${ch.isPulsing ? 'pulsing' : ''}`;
        card.id = `relayCard_${ch.id}`;

        // Build GPIO options
        const gpioOptions = STANDARD_GPIOS.map(g => 
          `<option value="${g}" ${g === ch.gpio ? 'selected' : ''}>GPIO ${g}</option>`
        ).join('');

        card.innerHTML = `
          <div class="card-header">
            <div class="card-header-left">
              <span class="channel-badge">CH ${ch.id}</span>
              <input type="text" class="channel-alias-input" value="${escapeHtml(ch.name)}" 
                onchange="updateChannelName(${ch.id}, this.value)" title="Click to rename channel">
            </div>
            <select class="gpio-selector" onchange="updateChannelGpio(${ch.id}, this.value)" title="Assign Hardware GPIO">
              ${gpioOptions}
            </select>
            ${APP_STATE.channels.length > 1 ? `
              <button class="card-remove-btn" onclick="removeRelayChannel(${ch.id})" title="Remove Channel ${ch.id}">
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <polyline points="3 6 5 6 21 6"></polyline>
                  <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
                </svg>
              </button>
            ` : ''}
          </div>

          <!-- Status Bar with Industrial LED -->
          <div class="relay-status-bar">
            <div class="status-left">
              <div class="industrial-led-bezel">
                <div class="industrial-led-core"></div>
              </div>
              <div class="status-label-group">
                <div class="status-primary-text" id="statusText_${ch.id}">
                  ${ch.isPulsing ? 'PULSE ACTIVE' : (ch.state ? 'ENERGIZED (ON)' : 'DE-ENERGIZED (OFF)')}
                </div>
                <div class="status-sub-text" id="statusSub_${ch.id}">
                  ${ch.activeLow ? 'Polarity: Active LOW' : 'Polarity: Active HIGH'} · Pin ${ch.gpio}
                </div>
              </div>
            </div>
            <span class="status-timer-badge" id="timerBadge_${ch.id}">${ch.remainingMs} ms</span>
          </div>

          <!-- Tactile Primary Toggle Button -->
          <button class="tactile-toggle-btn" id="btnToggle_${ch.id}" onclick="toggleRelayState(${ch.id})">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M18.36 6.64a9 9 0 1 1-12.73 0"></path>
              <line x1="12" y1="2" x2="12" y2="12"></line>
            </svg>
            <span>${ch.state ? 'TURN OFF' : 'TURN ON'}</span>
          </button>

          <!-- Pulse / Momentary Control Section (Clean slider & free input without presets) -->
          <div class="pulse-section">
            <div class="pulse-header">
              <span>PULSE DURATION</span>
              <span style="font-family: var(--font-mono); color: var(--accent-amber-soft);">${ch.pulseDurationMs} ms</span>
            </div>
            <div class="pulse-input-row">
              <input type="range" class="pulse-slider" min="50" max="10000" step="50" value="${ch.pulseDurationMs}"
                oninput="onPulseSliderChange(${ch.id}, this.value)">
              <input type="number" class="pulse-num-box" min="50" max="60000" value="${ch.pulseDurationMs}"
                onchange="onPulseSliderChange(${ch.id}, this.value)">
            </div>
            <button class="btn-trigger-pulse" onclick="triggerChannelPulse(${ch.id})">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>
              </svg>
              TRIGGER PULSE (${ch.pulseDurationMs} ms)
            </button>
            <div class="pulse-live-progress" id="pulseProg_${ch.id}">
              <div class="pulse-progress-fill" id="pulseFill_${ch.id}"></div>
            </div>
          </div>

          <!-- Card Polarity Configuration -->
          <div class="card-config-footer">
            <span>Hardware Polarity:</span>
            <select class="polarity-select" onchange="updateChannelPolarity(${ch.id}, this.value)">
              <option value="high" ${!ch.activeLow ? 'selected' : ''}>Active HIGH</option>
              <option value="low" ${ch.activeLow ? 'selected' : ''}>Active LOW</option>
            </select>
          </div>
        `;

        container.appendChild(card);
      });
    }

    function updateCardView(chId) {
      const ch = APP_STATE.channels.find(c => c.id === chId);
      if (!ch) return;
      const card = document.getElementById(`relayCard_${chId}`);
      if (!card) return;

      card.classList.toggle('energized', ch.state);
      card.classList.toggle('pulsing', ch.isPulsing);

      const statusText = document.getElementById(`statusText_${chId}`);
      const btnToggle = document.getElementById(`btnToggle_${chId}`);
      const timerBadge = document.getElementById(`timerBadge_${chId}`);

      if (statusText) {
        statusText.textContent = ch.isPulsing ? 'PULSE ACTIVE' : (ch.state ? 'ENERGIZED (ON)' : 'DE-ENERGIZED (OFF)');
      }
      if (btnToggle) {
        btnToggle.querySelector('span').textContent = ch.state ? 'TURN OFF' : 'TURN ON';
      }
      if (timerBadge) {
        timerBadge.textContent = `${ch.remainingMs} ms`;
      }
    }

    function updateChannelCounter() {
      const numLbl = document.getElementById('lblChannelCountNum');
      if (numLbl) {
        numLbl.textContent = APP_STATE.channels.length;
      }
    }

    /* ==========================================================================
     * Dynamic Free Channel Management
     * ========================================================================== */
    function addNewRelayChannel() {
      if (APP_STATE.channels.length >= 16) {
        showToast("Maximum of 16 relay channels supported by firmware.");
        return;
      }

      // Find next free ID and unique GPIO
      const existingIds = new Set(APP_STATE.channels.map(c => c.id));
      let newId = 0;
      while (existingIds.has(newId)) newId++;

      const usedGpios = new Set(APP_STATE.channels.map(c => c.gpio));
      const freeGpio = STANDARD_GPIOS.find(g => !usedGpios.has(g)) || (4 + newId);

      const newCh = {
        id: newId,
        name: `Relay ${newId + 1}`,
        gpio: freeGpio,
        state: false,
        isPulsing: false,
        pulseDurationMs: APP_STATE.defaultPulseDurationMs || 500,
        remainingMs: 0,
        activeLow: false
      };

      APP_STATE.channels.push(newCh);
      APP_STATE.channels.sort((a, b) => a.id - b.id);
      renderRelayGrid();
      updateChannelCounter();
      showToast(`Channel ${newId} (GPIO ${freeGpio}) added.`);
      logTerminal(`[CONFIG] Added dynamic relay channel CH ${newId} (GPIO ${freeGpio})`, "sys");
    }

    function removeRelayChannel(chId) {
      if (APP_STATE.channels.length <= 1) {
        showToast("At least 1 relay channel must remain active.");
        return;
      }
      APP_STATE.channels = APP_STATE.channels.filter(c => c.id !== chId);
      renderRelayGrid();
      updateChannelCounter();
      showToast(`Channel ${chId} removed.`);
      logTerminal(`[CONFIG] Removed channel CH ${chId}`, "sys");
    }

    function updateChannelName(chId, newName) {
      const ch = APP_STATE.channels.find(c => c.id === chId);
      if (ch) {
        ch.name = newName.trim() || `Channel ${chId}`;
      }
    }

    function updateChannelGpio(chId, gpioVal) {
      const ch = APP_STATE.channels.find(c => c.id === chId);
      if (ch) {
        ch.gpio = parseInt(gpioVal, 10);
        const sub = document.getElementById(`statusSub_${chId}`);
        if (sub) {
          sub.textContent = `${ch.activeLow ? 'Polarity: Active LOW' : 'Polarity: Active HIGH'} · Pin ${ch.gpio}`;
        }
        logTerminal(`[CONFIG] Channel CH ${chId} assigned to GPIO ${ch.gpio}`, "sys");
      }
    }

    function updateChannelPolarity(chId, polarity) {
      const ch = APP_STATE.channels.find(c => c.id === chId);
      if (ch) {
        ch.activeLow = (polarity === 'low');
        const sub = document.getElementById(`statusSub_${chId}`);
        if (sub) {
          sub.textContent = `${ch.activeLow ? 'Polarity: Active LOW' : 'Polarity: Active HIGH'} · Pin ${ch.gpio}`;
        }
        logTerminal(`[CONFIG] Channel CH ${chId} polarity set to ${ch.activeLow ? 'Active LOW' : 'Active HIGH'}`, "sys");
      }
    }

    function onPulseSliderChange(chId, val) {
      const ch = APP_STATE.channels.find(c => c.id === chId);
      if (!ch) return;
      const parsed = Math.max(50, Math.min(60000, parseInt(val, 10) || 500));
      ch.pulseDurationMs = parsed;

      const card = document.getElementById(`relayCard_${chId}`);
      if (card) {
        const slider = card.querySelector('.pulse-slider');
        const num = card.querySelector('.pulse-num-box');
        const btn = card.querySelector('.btn-trigger-pulse');
        const headVal = card.querySelector('.pulse-header span:last-child');
        if (slider) slider.value = parsed;
        if (num) num.value = parsed;
        if (headVal) headVal.textContent = `${parsed} ms`;
        if (btn) btn.innerHTML = `
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>
          </svg>
          TRIGGER PULSE (${parsed} ms)
        `;
      }
    }

    function updateDefaultPulse(val) {
      const parsed = Math.max(50, Math.min(60000, parseInt(val, 10) || 500));
      APP_STATE.defaultPulseDurationMs = parsed;
      document.getElementById('valDefaultPulseLabel').textContent = `${parsed} ms`;
      showToast(`Default pulse set to ${parsed} ms.`);
    }

    function updateStaggerDelay(val) {
      const parsed = Math.max(50, Math.min(5000, parseInt(val, 10) || 200));
      APP_STATE.staggerDelayMs = parsed;
      document.getElementById('valStaggerDelayLabel').textContent = `${parsed} ms`;
      showToast(`Stagger delay set to ${parsed} ms.`);
    }

    /* ==========================================================================
     * Relay Actions & Safety Interlock Logic
     * ========================================================================== */
    function toggleRelayState(chId) {
      const ch = APP_STATE.channels.find(c => c.id === chId);
      if (!ch) return;

      if (ch.state) {
        turnRelayOff(chId);
      } else {
        turnRelayOn(chId);
      }
    }

    function turnRelayOn(chId) {
      const ch = APP_STATE.channels.find(c => c.id === chId);
      if (!ch) return;

      // Handle Mutual Interlock safety check
      if (APP_STATE.interlockActive) {
        APP_STATE.channels.forEach(other => {
          if (other.id !== chId && (other.state || other.isPulsing)) {
            other.state = false;
            other.isPulsing = false;
            other.remainingMs = 0;
            updateCardView(other.id);
            sendRawSerialCmd(`off ${other.id}`);
          }
        });
      }

      ch.state = true;
      ch.isPulsing = false;
      ch.remainingMs = 0;
      updateCardView(chId);

      sendSerialCmd(`on ${chId}`);
    }

    function turnRelayOff(chId) {
      const ch = APP_STATE.channels.find(c => c.id === chId);
      if (!ch) return;

      ch.state = false;
      ch.isPulsing = false;
      ch.remainingMs = 0;
      updateCardView(chId);

      sendSerialCmd(`off ${chId}`);
    }

    function triggerChannelPulse(chId) {
      const ch = APP_STATE.channels.find(c => c.id === chId);
      if (!ch) return;

      // Interlock safety check
      if (APP_STATE.interlockActive) {
        APP_STATE.channels.forEach(other => {
          if (other.id !== chId && (other.state || other.isPulsing)) {
            other.state = false;
            other.isPulsing = false;
            other.remainingMs = 0;
            updateCardView(other.id);
            sendRawSerialCmd(`off ${other.id}`);
          }
        });
      }

      ch.state = true;
      ch.isPulsing = true;
      ch.remainingMs = ch.pulseDurationMs;
      updateCardView(chId);

      sendSerialCmd(`pulse ${chId} ${ch.pulseDurationMs}`);
    }

    function triggerEmergencyAllOff() {
      APP_STATE.channels.forEach(ch => {
        ch.state = false;
        ch.isPulsing = false;
        ch.remainingMs = 0;
        updateCardView(ch.id);
      });

      sendSerialCmd("all_off");
      showToast("EMERGENCY ALL-OFF EXECUTED");
    }

    function triggerAllChannelsOn() {
      if (APP_STATE.interlockActive) {
        showToast("Cannot energize all channels while Mutual Interlock is active.");
        return;
      }
      APP_STATE.channels.forEach(ch => {
        ch.state = true;
        ch.isPulsing = false;
        ch.remainingMs = 0;
        updateCardView(ch.id);
        sendRawSerialCmd(`on ${ch.id}`);
      });
      logTerminal("[MASTER] All channels energized simultaneously", "tx");
    }

    function triggerStaggeredSequencer() {
      if (APP_STATE.interlockActive) {
        showToast("Cannot execute staggered sequence while Mutual Interlock is active.");
        return;
      }
      const delay = APP_STATE.staggerDelayMs || 200;
      logTerminal(`[SEQUENCER] Commencing staggered inrush-safe power up (${delay}ms step)...`, "sys");
      APP_STATE.channels.forEach((ch, idx) => {
        setTimeout(() => {
          ch.state = true;
          ch.isPulsing = false;
          ch.remainingMs = 0;
          updateCardView(ch.id);
          sendRawSerialCmd(`on ${ch.id}`);
        }, idx * delay);
      });
    }

    function toggleInterlockMode(active) {
      APP_STATE.interlockActive = active;
      if (active) {
        showToast("Mutual Interlock Enabled: Only 1 relay can be active at a time.");
        logTerminal("[SAFETY] Mutual Interlock activated. Mutual exclusivity enforced.", "sys");
        // Ensure at most 1 relay is currently energized
        let foundOne = false;
        APP_STATE.channels.forEach(ch => {
          if (ch.state || ch.isPulsing) {
            if (!foundOne) {
              foundOne = true;
            } else {
              ch.state = false;
              ch.isPulsing = false;
              ch.remainingMs = 0;
              updateCardView(ch.id);
              sendRawSerialCmd(`off ${ch.id}`);
            }
          }
        });
      } else {
        showToast("Mutual Interlock Disabled: Independent multi-relay switching allowed.");
        logTerminal("[SAFETY] Mutual Interlock deactivated.", "sys");
      }
    }

    /* Pulse Timer Engine (100ms interval) */
    function startPulseTicker() {
      setInterval(() => {
        APP_STATE.channels.forEach(ch => {
          if (ch.isPulsing && ch.remainingMs > 0) {
            ch.remainingMs = Math.max(0, ch.remainingMs - 100);
            
            // Update progress bar
            const fill = document.getElementById(`pulseFill_${ch.id}`);
            if (fill && ch.pulseDurationMs > 0) {
              const pct = ((ch.pulseDurationMs - ch.remainingMs) / ch.pulseDurationMs) * 100;
              fill.style.width = `${pct}%`;
            }

            const timerBadge = document.getElementById(`timerBadge_${ch.id}`);
            if (timerBadge) {
              timerBadge.textContent = `${ch.remainingMs} ms`;
            }

            if (ch.remainingMs === 0) {
              ch.isPulsing = false;
              ch.state = false;
              updateCardView(ch.id);
              if (APP_STATE.isSimulating) {
                logTerminal(`channel ${ch.id}: PULSE_COMPLETE (ok)`, "rx");
              }
            }
          }
        });
      }, 100);
    }

    /* ==========================================================================
     * Serial Communication & Simulator Protocol
     * ========================================================================== */
