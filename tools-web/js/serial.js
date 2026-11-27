async function toggleSerialConnection() {
      if (APP_STATE.connected) {
        await disconnectSerial();
      } else {
        await connectSerial();
      }
    }

    async function connectSerial() {
      if (!('serial' in navigator)) {
        showToast("Web Serial API is not supported in this browser. Running simulator mode.");
        return;
      }

      const btnConnect = document.getElementById('btnConnect');
      btnConnect.classList.add('connecting');

      try {
        const port = await navigator.serial.requestPort();
        await port.open({ baudRate: 115200 });

        APP_STATE.port = port;
        APP_STATE.connected = true;
        APP_STATE.isSimulating = false;

        btnConnect.classList.remove('connecting');
        btnConnect.classList.add('connected');
        btnConnect.setAttribute('data-tooltip', 'Disconnect Serial');

        const connDot = document.getElementById('connDot');
        const connLabel = document.getElementById('connLabel');
        connDot.classList.add('connected');
        connLabel.textContent = "CONNECTED (115200)";

        logTerminal("[SERIAL] Connected to ESP32 Relay Controller @ 115200 Baud", "sys");
        showToast("Connected to hardware serial.");

        // Start read loop
        startSerialReadLoop();

        // Query initial state
        sendSerialCmd("status");
        setTimeout(() => sendSerialCmd("list"), 200);

      } catch (err) {
        console.error("Serial connection error:", err);
        btnConnect.classList.remove('connecting');
        showToast(`Connection failed: ${err.message || 'Cancelled'}`);
      }
    }

    async function disconnectSerial() {
      APP_STATE.readLoopActive = false;
      if (APP_STATE.reader) {
        try { await APP_STATE.reader.cancel(); } catch (e) {}
      }
      if (APP_STATE.port) {
        try { await APP_STATE.port.close(); } catch (e) {}
      }

      APP_STATE.port = null;
      APP_STATE.connected = false;
      APP_STATE.isSimulating = true;

      const btnConnect = document.getElementById('btnConnect');
      btnConnect.classList.remove('connected', 'connecting');
      btnConnect.setAttribute('data-tooltip', 'Connect ESP32 (115200 Baud)');

      const connDot = document.getElementById('connDot');
      const connLabel = document.getElementById('connLabel');
      connDot.classList.remove('connected');
      connLabel.textContent = "SIMULATOR ACTIVE";

      logTerminal("[SERIAL] Disconnected from hardware. Simulator active.", "sys");
      showToast("Disconnected from serial port.");
    }

    async function startSerialReadLoop() {
      APP_STATE.readLoopActive = true;
      const textDecoder = new TextDecoderStream();
      const readableStreamClosed = APP_STATE.port.readable.pipeTo(textDecoder.writable);
      const reader = textDecoder.readable.getReader();
      APP_STATE.reader = reader;

      let lineBuffer = "";

      try {
        while (APP_STATE.readLoopActive) {
          const { value, done } = await reader.read();
          if (done) break;
          if (value) {
            lineBuffer += value;
            const lines = lineBuffer.split('\n');
            lineBuffer = lines.pop(); // Retain remainder
            for (const line of lines) {
              const clean = line.trim();
              if (clean) handleFirmwareLine(clean);
            }
          }
        }
      } catch (err) {
        if (APP_STATE.readLoopActive) {
          console.error("Read loop error:", err);
          logTerminal(`[SERIAL ERROR] ${err.message}`, "err");
        }
      } finally {
        reader.releaseLock();
      }
    }

    function sendSerialCmd(cmd) {
      logTerminal(cmd, "tx");
      sendRawSerialCmd(cmd);

      // If in simulator mode, simulate response
      if (APP_STATE.isSimulating) {
        simulateFirmwareResponse(cmd);
      }
    }

    async function sendRawSerialCmd(cmd) {
      if (APP_STATE.connected && APP_STATE.port && APP_STATE.port.writable) {
        try {
          const encoder = new TextEncoder();
          const writer = APP_STATE.port.writable.getWriter();
          await writer.write(encoder.encode(cmd + "\n"));
          writer.releaseLock();
        } catch (e) {
          console.error("Serial write error:", e);
          logTerminal(`[TX ERROR] Failed to send: ${e.message}`, "err");
        }
      }
    }

    /* Firmware Response Parsing */
    function handleFirmwareLine(line) {
      logTerminal(line, "rx");

      // Match 'Channel <N>: ON|OFF (remaining <ms> ms)'
      const statusMatch = line.match(/Channel\s+(\d+):\s+(ON|OFF)(?:\s+\(remaining\s+(\d+)\s+ms\))?/i);
      if (statusMatch) {
        const chId = parseInt(statusMatch[1], 10);
        const isOn = statusMatch[2].toUpperCase() === 'ON';
        const remMs = statusMatch[3] ? parseInt(statusMatch[3], 10) : 0;
        const ch = APP_STATE.channels.find(c => c.id === chId);
        if (ch) {
          ch.state = isOn;
          ch.isPulsing = (remMs > 0);
          ch.remainingMs = remMs;
          updateCardView(chId);
        }
      }

      // Match 'channel <N>: STATE_CHANGED | PULSE_COMPLETE | TIMEOUT'
      const eventMatch = line.match(/channel\s+(\d+):\s+([A-Z_]+)/i);
      if (eventMatch) {
        const chId = parseInt(eventMatch[1], 10);
        const ev = eventMatch[2].toUpperCase();
        const ch = APP_STATE.channels.find(c => c.id === chId);
        if (ch) {
          if (ev === 'PULSE_COMPLETE' || ev === 'TIMEOUT') {
            ch.state = false;
            ch.isPulsing = false;
            ch.remainingMs = 0;
            updateCardView(chId);
          }
        }
      }
    }

    /* Built-in Offline Firmware Simulator */
    function simulateFirmwareResponse(cmd) {
      const parts = cmd.trim().split(/\s+/);
      const action = parts[0].toLowerCase();
      const chIdx = parts[1] !== undefined ? parseInt(parts[1], 10) : null;
      const duration = parts[2] !== undefined ? parseInt(parts[2], 10) : 500;

      setTimeout(() => {
        if (action === "status") {
          logTerminal(`Channels: ${APP_STATE.channels.length}`, "rx");
          APP_STATE.channels.forEach(c => {
            logTerminal(`Channel ${c.id}: ${c.state ? 'ON' : 'OFF'} (remaining ${c.remainingMs} ms)`, "rx");
          });
        } else if (action === "list") {
          logTerminal(`Configured Channels: ${APP_STATE.channels.length}`, "rx");
          APP_STATE.channels.forEach(c => {
            logTerminal(`  Channel ${c.id}: GPIO ${c.gpio}, Polarity: ${c.activeLow ? 'LOW' : 'HIGH'}`, "rx");
          });
        } else if (action === "info") {
          logTerminal("ESP32 Relay Controller v2.1 (Industrial Studio Build, Free-Channel Matrix)", "rx");
        } else if (action === "all_off") {
          logTerminal("All channels switched OFF.", "rx");
        } else if (action === "on" && chIdx !== null) {
          logTerminal(`channel ${chIdx}: STATE_CHANGED (ok)`, "rx");
        } else if (action === "off" && chIdx !== null) {
          logTerminal(`channel ${chIdx}: STATE_CHANGED (ok)`, "rx");
        } else if (action === "pulse" && chIdx !== null) {
          logTerminal(`channel ${chIdx}: PULSE_STARTED (${duration} ms)`, "rx");
        } else {
          logTerminal(`OK: executed '${cmd}'`, "rx");
        }
      }, 50);
    }

    /* ==========================================================================
     * Terminal UI & Custom Commands
     * ========================================================================== */
