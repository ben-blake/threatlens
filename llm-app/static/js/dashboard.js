/**
 * Dashboard JavaScript functionality
 */

document.addEventListener('DOMContentLoaded', function () {
  // Handle example log buttons
  setupExampleLogs();

  // Format analysis results - called immediately when page loads
  formatAnalysisResults();
});

/**
 * Set up example log entries that users can click to populate the textarea
 */
function setupExampleLogs() {
  // Example logs that users can quickly insert
  const exampleLogs = [
    'sshd[1234]: Failed password for invalid user admin from 123.45.67.89 port 22 ssh2',
    'kernel: [UFW BLOCK] IN=eth0 OUT= MAC=00:00:00:00:00:00 SRC=192.168.1.100 DST=192.168.1.1 LEN=40 TOS=0x00 PROTO=TCP SPT=45678 DPT=22 WINDOW=65535 SYN',
    'nginx: 192.168.1.10 - - [10/Jul/2025:13:55:36 +0000] "GET /wp-admin/setup-config.php HTTP/1.1" 404 0 "-" "Mozilla/5.0 zgrab/0.x"',
    'app[web.1]: Exception in thread "main" java.lang.OutOfMemoryError: Java heap space',
    'CRON[3123]: pam_unix(cron:session): session opened for user root by (uid=0)',
    'systemd: Started Daily apt upgrade and clean activities.',
  ];

  // Create example buttons container
  const logEntryField = document.getElementById('log_entry');
  if (!logEntryField) return;

  const exampleContainer = document.createElement('div');
  exampleContainer.className = 'example-logs';
  exampleContainer.innerHTML = '<p class="text-muted mb-2">Example logs:</p>';

  // Create buttons for each example
  exampleLogs.forEach((log) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'btn btn-sm btn-outline-secondary mb-2 me-2';
    button.textContent = log.substring(0, 25) + '...';
    button.title = log;
    button.addEventListener('click', () => {
      logEntryField.value = log;
      logEntryField.focus();
    });
    exampleContainer.appendChild(button);
  });

  // Add the example container after the textarea
  logEntryField.parentNode.insertBefore(
    exampleContainer,
    logEntryField.nextSibling
  );
}

/**
 * Format the analysis results to enhance readability
 */
function formatAnalysisResults() {
  // Target the special formatted-analysis div for the single result view
  const formattedAnalysisElement = document.querySelector(
    '.formatted-analysis'
  );

  if (formattedAnalysisElement && window.rawAnalysisText) {
    const analysisText = window.rawAnalysisText;
    console.log('Raw analysis text:', analysisText); // Debug logging

    try {
      // Simpler approach - directly extract each section with a more robust pattern that handles multi-line text

      // Extract threat classification - look for pattern like "1. **Threat Classification:** Text" even with line breaks
      const threatMatch = analysisText.match(
        /(?:\d+\.?\s*)?(?:\*\*)?Threat\s+Classification(?:\*\*)?\s*:\s*([\s\S]*?)(?=(?:\d+\.?\s*)?(?:\*\*)?Risk\s+Score)/i
      );

      // Extract risk score - look for pattern like "2. **Risk Score:** 7" even with line breaks
      const riskMatch = analysisText.match(
        /(?:\d+\.?\s*)?(?:\*\*)?Risk\s+Score(?:\*\*)?\s*:\s*([\s\S]*?)(?=(?:\d+\.?\s*)?(?:\*\*)?Summary)/i
      );

      // Extract summary - look for pattern like "3. **Summary:** Text" to the end of the text
      // Fixed to properly capture the remaining text as the summary
      const summaryMatch = analysisText.match(
        /(?:\d+\.?\s*)?(?:\*\*)?Summary(?:\*\*)?\s*:\s*([\s\S]*$)/i
      );

      console.log('Extraction results:', {
        threatMatch: threatMatch ? threatMatch[1] : null,
        riskMatch: riskMatch ? riskMatch[1] : null,
        summaryMatch: summaryMatch ? summaryMatch[1] : null,
      });

      // Only proceed if we found at least some parts
      if (
        (threatMatch && threatMatch[1]) ||
        (riskMatch && riskMatch[1]) ||
        (summaryMatch && summaryMatch[1])
      ) {
        // Clean up the extracted text to remove markdown formatting
        const cleanText = (text) => {
          if (!text) return 'Not specified';
          // Remove any ** markers and extra whitespace
          return text
            .trim()
            .replace(/^\s*\*\*\s*/gm, '') // Remove ** at the start of any line
            .replace(/\s*\*\*\s*$/gm, '') // Remove ** at the end of any line
            .trim();
        };

        const threatText = cleanText(threatMatch && threatMatch[1]);
        const riskText = cleanText(riskMatch && riskMatch[1]);
        const summaryText = cleanText(summaryMatch && summaryMatch[1]);

        // Extract risk score number (more robust)
        let riskScore = 5; // Default medium risk
        const scoreMatch = riskText.match(/(\d+)/);
        if (scoreMatch && scoreMatch[1]) {
          riskScore = parseInt(scoreMatch[1]);
          if (isNaN(riskScore) || riskScore < 1 || riskScore > 10) {
            riskScore = 5; // Default if parsing fails or out of range
          }
        }

        // Determine risk level class
        let riskClass = 'risk-medium';
        if (riskScore <= 3) riskClass = 'risk-low';
        if (riskScore >= 7) riskClass = 'risk-high';

        // Build the formatted HTML
        const formattedHTML = `
          <div class="d-flex align-items-start mb-3">
              <div class="risk-score ${riskClass} me-3">${riskScore}</div>
              <div class="flex-grow-1">
                  <h5>Analysis Results</h5>
              </div>
          </div>
          <div class="analysis-section mb-2">
              <div class="threat-classification fw-bold text-primary">Threat Classification</div>
              <div class="ps-2 mb-3">${threatText}</div>
          </div>
          <div class="analysis-section mb-2">
              <div class="risk-score-label fw-bold text-primary">Risk Score</div>
              <div class="ps-2 mb-3">${riskText}</div>
          </div>
          <div class="analysis-section">
              <div class="summary-label fw-bold text-primary">Summary</div>
              <div class="summary-text ps-2 fst-italic">${summaryText}</div>
          </div>
        `;

        // Set the formatted HTML
        formattedAnalysisElement.innerHTML = formattedHTML;
      } else {
        // Fallback if parsing failed with more details
        formattedAnalysisElement.innerHTML = `
          <div class="alert alert-warning">
            <p><strong>Could not parse the analysis format.</strong> Raw output:</p>
            <pre class="mt-2 p-2 bg-light">${analysisText}</pre>
          </div>
        `;
        console.warn('Failed to parse analysis format:', analysisText);
      }
    } catch (e) {
      console.error('Error formatting analysis:', e);
      formattedAnalysisElement.innerHTML = `
        <div class="alert alert-danger">
          <p><strong>Error formatting analysis:</strong> ${e.message}</p>
          <pre class="mt-2 p-2 bg-light">${analysisText}</pre>
        </div>
      `;
    }
  }
}
