//TO ALIGN ELEMENTS NICELY WHEN A SCROLL BAR IS NEEDED, DT TABLES DRAW A FOOTER THAT IS A TABLE ELEMENT THAT IS EMPTY, WHICH MESSES UP SCREEN READERS. THIS FINDS THE EMPTY TABLE AND GIVES IT A PRESENTATION ROLE SO SCREEN READERS KNOW THE EFFECT IS ONLY VISUAL. IT ALSO HIDES IT VIA ARIA-HIDDEN. 
//THE EARLIER BIT IN HERE IS FROM CHATGPT. IT SETS EACH COLUMN HEADER AS A SEMANTIC HEADER CELL. THIS SHOULD HELP SCREEN READERS ASSOCIATE HEADERS WITH THE APPROPRIATE CELLS IN THE TABLE. OTHERWISE, THE TH ELEMENTS COULD BE ROW/COLUMN/BOTH HEADERS, SO A SCREEN READER WOULDN'T GUESS AND JUST WOULDN'T SAY THE HEADERS ALOUD AT ALL WHEN A USER NAVIGATES TO A CELL.
//IT ALSO DYNAMICALLY RECOGNIZES THE SORT DIRECTION FOR EACH COLUMN AND UPDATES THE ARIA-SORT ATTRIBUTE SO THAT A SCREEN READER WOULD SAY THE SORT DIRECTION WHEN A TABLE ROW IS HIGHLIGHTED. 
//ANOTHER THING IT DOES IS FIND ANY OF THE NUMBERED PAGINATION BUTTONS AND GIVES THEM ARIA LABELS THAT APPEND "PAGE" TO THE FRONT OF THE NUMBERS SO IT'S MORE OBVIOUS WHAT THEY'RE FOR FOR SCREEN READERS. 

table.on("draw", function() {
    // Scope and sort attributes on header cells
    var headerCells = table.table().header().querySelectorAll("th");
    headerCells.forEach(function(th) {
      th.setAttribute("scope", "col");
      th.removeAttribute("aria-sort");

      if (th.classList.contains("sorting_asc")) {
        th.setAttribute("aria-sort", "ascending");
      } else if (th.classList.contains("sorting_desc")) {
        th.setAttribute("aria-sort", "descending");
      } else {
        th.setAttribute("aria-sort", "none");
      }
    });

    // Hide the visual-only footer table
    var footerTable = $(table.table().container()).find("div.dataTables_scrollFootInner table");
    if (footerTable.length > 0) {
      footerTable.attr("role", "presentation");
      footerTable.attr("aria-hidden", "true");
      if (footerTable.find("thead").length === 0) {
        footerTable.prepend(\'<thead><tr><th style="visibility: hidden;">This is not a real table.</th></tr></thead>\');
      }
    }

    // Add aria-label to numbered pagination buttons
    $(".dataTables_paginate a").each(function() {
      var $this = $(this);
      var text = $this.text().trim();
      if (!isNaN(text)) {
        $this.attr("aria-label", "Page " + text);
      }
    });
  });