/* Global Application State */
    const APP_STATE = {
      connected: false,
      isSimulating: true,
      port: null,
      reader: null,
      writer: null,
      readLoopActive: false,
      interlockActive: false,
      defaultPulseDurationMs: 500,
      staggerDelayMs: 200,
      channels: [
        { id: 0, name: "Main Pump",       gpio: 4,  state: false, isPulsing: false, pulseDurationMs: 500,  remainingMs: 0, activeLow: false },
        { id: 1, name: "Solenoid Valve",  gpio: 5,  state: false, isPulsing: false, pulseDurationMs: 1000, remainingMs: 0, activeLow: false },
        { id: 2, name: "Cooling Fan",     gpio: 6,  state: false, isPulsing: false, pulseDurationMs: 2000, remainingMs: 0, activeLow: false },
        { id: 3, name: "Aux Actuator",    gpio: 7,  state: false, isPulsing: false, pulseDurationMs: 500,  remainingMs: 0, activeLow: false }
      ],
      cmdHistory: [],
      historyIndex: -1
    };

    /* Available Standard GPIO Pins on ESP32/P4/S3 */
    const STANDARD_GPIOS = [
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
      16, 17, 18, 19, 20, 21, 22, 23, 25, 26, 27, 32, 33, 34, 35
    ];

    /* Initialize Application */
    document.addEventListener('DOMContentLoaded', () => {
      renderRelayGrid();
      updateChannelCounter();
      logTerminal("Relay Controller Studio initialized. Running built-in firmware simulator.", "sys");
      startPulseTicker();
      setupTerminalInput();
    });

    /* ==========================================================================
     * Relay Grid Rendering & UI Management
     * ========================================================================== */
