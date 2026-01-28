/* SHINY'S DEFAULT DATE PICKERS COME WITH A TEXT BOX YOU CAN TYPE A DATE INTO AND A POP-UP CALENDAR WIDGET THAT ALLOWS YOU TO CLICK A SPECIFIC DATE. HOWEVER, THE LATTER WILL OFTEN OBSCURE THE FORMER, WHICH IS ANNOYING, SO THIS CODE IS DESIGNED TO BUMP THE LATTER UP A LITTLE SO IT CAN'T OVERLAP WITH THE FORMER. */

$(document).ready(function(){
  // Function to adjust the datepicker position
  function adjustDatepickerPosition(input) {
    setTimeout(function(){
      var datepicker = $('body').find('.datepicker');
      var offset = $(input).offset();
      var dpHeight = datepicker.outerHeight();
      datepicker.css({
        top: (offset.top - dpHeight - 10) + 'px',
        left: offset.left + 'px'
      });
    }, 10);
  }

  // Bind focus and click events to ALL date inputs
  $(document).on('focus click', 'input[data-provide=\"datepicker\"]', function(){
    adjustDatepickerPosition(this);
  });

  // Also adjust position when the datepicker is shown
  $(document).on('shown.bs.datepicker', function(e){
    adjustDatepickerPosition(e.target);
  });
});