function toggleTerminalDrawer(forceState) {
      const drawer = document.getElementById('bottomTerminalDrawer');
      const btnToggle = document.getElementById('btnToggleTerm');
      const isOpen = (forceState !== undefined) ? forceState : !drawer.classList.contains('open');

      drawer.classList.toggle('open', isOpen);
      btnToggle.classList.toggle('active', isOpen);
      if (isOpen) {
        document.getElementById('termInput').focus();
      }
    }

    function logTerminal(msg, tag = "sys") {
      const body = document.getElementById('termBody');
      const row = document.createElement('div');
      row.className = 'terminal-row';

      const now = new Date();
      const ts = `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}:${String(now.getSeconds()).padStart(2,'0')}.${String(Math.floor(now.getMilliseconds()/100))}`;

      row.innerHTML = `
        <span class="term-ts">[${ts}]</span>
        <span class="term-tag ${tag}">[${tag.toUpperCase()}]</span>
        <span class="term-msg">${escapeHtml(msg)}</span>
      `;

      body.appendChild(row);
      body.scrollTop = body.scrollHeight;
    }

    function clearTerminalLog() {
      document.getElementById('termBody').innerHTML = '';
    }

    function readTerminalLog() {
      const body = document.getElementById('termBody');
      return Array.from(body.children, row => {
        const parts = Array.from(row.children, part => part.textContent);
        return parts.length ? parts.join(' ') : row.textContent;
      }).join('\n');
    }

    async function copyTerminalLog() {
      try {
        const text = readTerminalLog();
        if (navigator.clipboard && window.isSecureContext) {
          await navigator.clipboard.writeText(text);
          return;
        }

        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.setAttribute('readonly', '');
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        let copied;
        try {
          textarea.select();
          copied = document.execCommand('copy');
        } finally {
          textarea.remove();
        }
        if (!copied) throw new Error('Clipboard access is unavailable in this browser.');
      } catch (err) {
        logTerminal(`Could not copy serial log: ${err.message}`, 'err');
      }
    }

    function downloadTerminalLog() {
      let objectUrl;
      try {
        const blob = new Blob([readTerminalLog()], { type: 'text/plain;charset=utf-8' });
        objectUrl = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = objectUrl;
        link.download = 'relay-control-serial-console-log.txt';
        document.body.appendChild(link);
        link.click();
        link.remove();
      } catch (err) {
        logTerminal(`Could not download serial log: ${err.message}`, 'err');
      } finally {
        if (objectUrl) window.setTimeout(() => URL.revokeObjectURL(objectUrl), 1000);
      }
    }

    document.getElementById('btnCopyTerm').addEventListener('click', copyTerminalLog);
    document.getElementById('btnDownloadTerm').addEventListener('click', downloadTerminalLog);

    function setupTerminalInput() {
      const input = document.getElementById('termInput');
      input.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          sendCustomTerminalCmd();
        } else if (e.key === 'ArrowUp') {
          if (APP_STATE.cmdHistory.length > 0) {
            if (APP_STATE.historyIndex < APP_STATE.cmdHistory.length - 1) {
              APP_STATE.historyIndex++;
              input.value = APP_STATE.cmdHistory[APP_STATE.cmdHistory.length - 1 - APP_STATE.historyIndex];
            }
          }
        } else if (e.key === 'ArrowDown') {
          if (APP_STATE.historyIndex > 0) {
            APP_STATE.historyIndex--;
            input.value = APP_STATE.cmdHistory[APP_STATE.cmdHistory.length - 1 - APP_STATE.historyIndex];
          } else if (APP_STATE.historyIndex === 0) {
            APP_STATE.historyIndex = -1;
            input.value = "";
          }
        }
      });
    }

    function sendCustomTerminalCmd() {
      const input = document.getElementById('termInput');
      const cmd = input.value.trim();
      if (!cmd) return;

      APP_STATE.cmdHistory.push(cmd);
      APP_STATE.historyIndex = -1;
      input.value = "";

      sendSerialCmd(cmd);
    }

    /* ==========================================================================
     * Help & Utilities
     * ========================================================================== */
    function openHelpModal() {
      document.getElementById('modalHelp').classList.add('active');
    }

    function closeHelpModal() {
      document.getElementById('modalHelp').classList.remove('active');
    }

    function showToast(msg) {
      const toast = document.getElementById('toastMsg');
      toast.textContent = msg;
      toast.classList.add('show');
      setTimeout(() => toast.classList.remove('show'), 2600);
    }

    function escapeHtml(str) {
      if (!str) return '';
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
    }
