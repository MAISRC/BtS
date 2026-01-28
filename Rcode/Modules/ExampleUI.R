#A MODULE ELEMENT (ON THE UI SIDE) IS JUST A FUNCTION WITH NO PARAMETERS. STUFF WHATEVER UI ELEMENTS SHOULD BE BUNDLED TOGETHER INSIDE THE FUNCTIONS INPUTS.

exampleUI = function() {
  div( #SOME UI ELEMENT

      tags$main( #SEMANTICALLY APPROPRIATE DIV HERE. PERHAPS A HEADER ABOVE OR BELOW

      tags$section( #SEMANTICALLY APPROPRIATE DIV HERE

        #IF YOU WANT A BUTTON THAT CONTROLS AN ACCORDIAN STYLE MENU, HERE IS A TEMPLATE. IT USES THE ARIA-EXPANDED AND ARIA-CONTROLS MECHANICS PLUS OPENCLOSEINFO TO WORKS.
    actionButton("toggle_filters",
                 label = '  Click here for toggles/filters!',
                 icon = icon("plus"),
                 `aria-expanded` = "false",
                 `aria-controls` = "hidden_filters")),
  hidden(tags$section(id = "hidden_filters",
          tags$fieldset( #THIS IS A TEMPLATE FOR HOW A FIELDSET WITH A LEGEND WORKS.
            tags$legend(),
            #SEVERAL INPUTS GO IN HERE.
            p("I\'m a sample input!")
            #OR WHATEVER
          )
   )),

 tags$section( 
   #HERE'S HOW A FIGURE + FIGCAPTION SECTION WOULD WORK.
          tags$figure(
            #A FIGURE WOULD GO HERE, LIKE A PLOTLY GRAPH OR LEAFLET MAP.
            tags$figcaption("Map markers indicate lakes with survey data. To view more information, hover over or click a marker (long press and touch on mobile, respectively).")
    )
   )
  )
 )
}