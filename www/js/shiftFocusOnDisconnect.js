//FUNCTION THAT RECEIVES MESSAGE FROM SHINY SAYING, HEY, THE SESSION JUST ENDED. WHEN THAT HAPPENS, IT'LL GIVE THE SHINY DISCONNECT OVERLAY THE ARIA ROLE OF ALERTDIALOG, MAKE IT FOCUSABLE, AND MOVE FOCUS THERE. ALSO, IT ENSURES THE DISCONNECT MESSAGE REFRESH LINK ACTUALLY HAS TEXT IN IT. LASTLY, THIS IS ALSO WHERE NEW DISCONNECT MESSAGE TEXT SHOULD GO.

$(document).on('shiny:disconnected', function(event) {
    var el = document.getElementById('ss-connect-dialog');
    if (el) {
      // Create an accessible alert
      var msgContainer = document.createElement('div');
      msgContainer.innerHTML = 'Beating the Spread has timed out or crashed.<br>If you suspect a crash, contact <address><a href=\"mailto:bajcz003@umn.edu\" id = \"disconnectemail\">Dr. Alex Bajcz</a></address>.';
      msgContainer.setAttribute('role', 'alertdialog');
      msgContainer.setAttribute('tabindex', '-1');
      msgContainer.setAttribute('aria-label', 'Error message');
      msgContainer.style.outline = 'none';
      msgContainer.style.marginBottom = '1em';

      // Insert it at the beginning of the disconnect dialog
      el.insertBefore(msgContainer, el.firstChild);
      
      // WIPE OUT CONTENT THAT GETS ASSIGNED TO THIS LINK
      const link = document.querySelector('#ss-connect-dialog > div > address > a');
      
      if (link) {
        const style = document.createElement('style');
        style.textContent = `
         #ss-connect-dialog address a::before {
           content: none !important;
         }
         #ss-connect-dialog a#disconnectemail {
         display: inline !important;
         margin-top: 0px !important;
         }
        `;
          document.head.appendChild(style);
        }

      // Shift focus
      msgContainer.focus();
      
      // MAKE SURE THAT THE DISCONNECT LINK ALSO HAS TEXT IN IT:
      $(document).ready(function() {
      var reloadLink = document.getElementById('ss-reload-link');
      if (reloadLink) {
        reloadLink.innerText = 'Refresh the page';
       }
      });
    }
  });