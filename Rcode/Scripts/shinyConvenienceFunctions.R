#FUNCTION FOR CHECKING IF A VALUE IS EVEN (FOR ACCORDIANS MOSTLY)
checkIfEven = function(val) {
  if(val %% 2 == 0) { 
    return(TRUE) 
  } else { return(FALSE) }
}

#FUNCTION TO OPEN/CLOSE ACCORDIANS DEPENDING ON BUTTON CLICKS
openCloseInfo = function(result, answer, question, session) {
  if(result) {
    shinyjs::hide(answer, anim=T, animType = "slide")
    updateActionButton(session, question, icon=icon("plus"))
    runjs(paste0("$('#", question, "').attr('aria-expanded', 'false');")) #These commands update the aria-expanded attribute to reflect whether the accordion is open or closed.
  } else {
    shinyjs::show(answer, anim=T, animType="slide")
    updateActionButton(session, question, icon=icon("minus"))
    runjs(paste0("$('#", question, "').attr('aria-expanded', 'true');"))
  }
}

#RELATED FUNCTION THAT TOGGLES THE ARIA-EXPANDED ATTRIBUTE OF A SHINY ACTIONBUTTON THAT IS RUNNING AN ACCORDIAN-STYLE MENU.
toggleAriaExpanded = function(id) {
  runjs(sprintf("
    (function() {
      var el = document.getElementById('%s');
      if (el) {
        var current = el.getAttribute('aria-expanded');
        // Toggle from 'true' -> 'false' or 'false' -> 'true'
        if (current === 'true') {
          el.setAttribute('aria-expanded', 'false');
        } else {
          el.setAttribute('aria-expanded', 'true');
        }
      }
    })();
  ", id))
}

#FUNCTION FOR DETECTING A VALID EMAIL ADDRESS
isValidEmail = function(x) {
  grepl("\\<[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}\\>",
        as.character(x), 
        ignore.case=TRUE)
}

#Function converts a lookup table into a function that does find and replacement in a vectorized way.
replaceViaLookup = function(strings, toreplace, replacements) {
  
  replacement.vec = setNames(replacements, toreplace) #Make a named vector with the replacements as the names.
  
  stringr::str_replace_all(strings, replacement.vec) #Use this function to do the string replacements.
}




# A11Y FIXERS -------------------------------------------------------------

##SHINY'S DATE INPUTS WILL BY DEFAULT SET A LABEL'S FOR ATTRIBUTE TO POINT AT THE HOUSING DIV INSTEAD OF AT THE INPUT SUB-ELEMENT. THIS FUNCTION IS A DROP-IN FIX FOR THIS--ADD IT TO THE UI AFTER ANY DATE INPUT AND REFERENCE ITS inputID.
fixDateInputLabel = function(inputId) {
  tags$script(HTML(sprintf("
    $(document).ready(function() {
      const container = document.getElementById('%s');
      if (!container) return;

      const label = document.getElementById('%s-label');
      const input = container.querySelector('input');

      if (label && input) {
        if (!input.id) {
          input.id = '%s-fixed-input';
        }
        label.setAttribute('for', input.id);
      }
    });
  ", inputId, inputId, inputId)))
}


##APPARENTLY, PICKER INPUTS FUNCTIONALLY SUPPRESS A SELECT INPUT THEY CREATE BY JUST HIDING IT VIA TRANSPARENCY, BUT OBVIOUSLY WAVE DOESN'T LIKE THAT, SO WE USE THIS JS TO GO FULL NUCLEAR IN TERMS OF ACTUALLY HIDING THAT ELEMENT SO THAT NO ASSISTIVE TECHNOLOGIES COULD TRIP ON IT AND NO USER WOULD EASIER RE-DISPLAY IT.
suppressNativeSelectAccessibility = function(inputId) {
  tags$script(HTML(sprintf("
    $(document).ready(function() {
      var el = document.getElementById('%s');
      if (el) {
        el.setAttribute('aria-hidden', 'true');
        el.setAttribute('tabindex', '-1');
        el.style.visibility = 'hidden';
        el.style.position = 'absolute';
        el.style.width = '0';
        el.style.height = '0';
        el.style.overflow = 'hidden';
        el.style.pointerEvents = 'none';
        el.style.color = 'inherit';  // prevent contrast warnings
        el.style.backgroundColor = 'inherit';
      }
    });
  ", inputId)))
}

##PICKERINPUTS ACTUALLY FUNCTION UNDER THE HOOD BY CREATING BUTTON ELEMENTS THAT DO THE REAL WORK. HOWEVER, BY DEFAULT, THEY GIVE THESE BUTTONS A TITLE ATTRIBUTE THAT DUPLICATES THE BUTTON TEXT, WHICH WAVE DOESN'T LIKE. THIS FUNCTION SUPPRESSES THE TITLE ATTRIBUTE SINCE IT'D BE REDUNDANT IN THESE INSTANCES ANYHOW
stripPickerDuplicateTitles = function(inputId) {
  tags$script(HTML(sprintf("
    $(document).ready(function() {
      function fixTitle() {
        var button = document.querySelector('button[data-id=\"%s\"]');
        if (button) {
          var labelText = button.innerText.trim();
          var titleText = button.getAttribute('title')?.trim();
          button.setAttribute('tabindex', '0'); //MAKE IT TABBABLE AND PUT IN ACCESSIBILITY TREE.

          if (titleText && labelText === titleText) {
            button.removeAttribute('title');
            console.log('Removed redundant title from: %s');
          }
        }
      }

      // Run once on load
      fixTitle();

      // Set up a MutationObserver to detect DOM changes
      var target = document.getElementById('%s');
      if (!target) return;

      var observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
          if (mutation.type === 'childList') {
            fixTitle();
          }
        });
      });

      observer.observe(target.parentNode, { childList: true, subtree: true });
    });
  ", inputId, inputId, inputId)))
}


#FILEINPUTS HAVE THIS BOGUS, JUST-FOR-SHOW TEXT INPUT ELEMENT THAT HOLDS PLACEHOLDER TEXT, PROGRESS BAR, AND FILE NAMES. THIS FAILS TO GET A LABEL, WHICH WAVE DOESN'T LIKE. THIS FUNCTION CHANGES THIS INPUT'S ATTRIBUTES TO BE MORE FULLY IGNORABLE. IT ALSO PROVIDES SOME ADDITIONAL ATTRIBUTES TO MAKE SURE IT CAN'T GET FOCUS OR GET PUT IN THE ACCESSIBILITY TREE FOR SCREEN READERS.
suppressFileInputFauxTextbox = function(inputId) {
  tags$script(HTML(sprintf("
    $(document).ready(function() {
      var fileInput = document.getElementById('%s');
      if (!fileInput) return;

      var inputGroup = fileInput.closest('.input-group');
      if (!inputGroup) return;

      var fauxInput = inputGroup.querySelector('input.form-control[type=\"text\"]');
      if (fauxInput) {
        fauxInput.setAttribute('aria-hidden', 'true');
        fauxInput.setAttribute('tabindex', '-1');
        fauxInput.setAttribute('role', 'presentation');
        fauxInput.setAttribute('aria-label', 'Filename display only (decorative)'); 
      }
    });
  ", inputId)))
}

#RADIOBUTTONS TURN THE PROVIDED LABEL INTO AN "OUTER LABEL" FOR THE WHOLE GROUP OF BUTTONS, EVEN THOUGH EACH IS AN INPUT THAT THEN GETS A LABEL FORMED BY ITS CHOICE'S STRING. SO, THE OUTER LABEL HAS A FOR ATTRIBUTE THAT SAYS IT LABELS A FORM CONTROL WHEN IT DOESN'T.
suppressRadioGroupLabelWarnings = function(inputId){
  tags$script(HTML(sprintf("
    $(document).ready(function() {
      var label = document.getElementById('%s-label');
      if (label && label.tagName.toLowerCase() === 'label') {
        var ele = document.createElement('p');
        ele.id = label.id;
        ele.className = label.className;
        ele.classList.add('p-label');
        ele.textContent = label.textContent;
        label.parentNode.replaceChild(ele, label);
      }
    });
  ", inputId)))
}