Shiny.addCustomMessageHandler('a11yLiveMessage', function(message) {
    var liveEl = document.getElementById('a11y-live-region');
    if (liveEl) {
      liveEl.textContent = message;
    }
  });