/* THIS SCRIPT PREVENTS USERS FROM ENTERING NEGATIVE NUMBERS OR E (FOR SCIENTIFIC NOTATION) INTO SHINY'S NUMERIC INPUTS. THIS GIVES US FEWER CASES TO HANDLE ON THE BACKEND (THOUGH ISN'T HELPFUL IF SUCH USER INPUTS ARE DESIRED, OBVIOUSLY!) */

$(document).on("keydown", "input[type=number]", function (e) {
      if (e.key === "e" || e.key === "E" || e.key === "-") {
        e.preventDefault(); /* DON'T DO WHAT YOU'D NORMALLY DO WHEN THESE KEYS ARE PRESSED */
        return false; /* INSTEAD, JUST IGNORE THE INPUTS */
      }
    });