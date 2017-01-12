# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

show_or_hide_selected_works = ->
  selected_works_count = $(".work.panel input[type=checkbox]:checked").length
  if selected_works_count > 0
    $("#selected-works-count").html(selected_works_count)
    $("#selected-works").show()
    batch_edit_property = $("#batch_edit_property").val()
    if batch_edit_property.endsWith("_new")
      $("#new-batch-edit-name").show()
    else
      $("#new-batch-edit-name").hide()
  else
    $("#selected-works").hide()

show_screen_image = (e)->
  document.location = e.target.src.replace('screen_','')

click_thumb_event = (e)->
  image_url = $(e.currentTarget).attr("href")
  show_area = $(e.target).closest(".imageviewer").find("img.show")
  show_area.attr("src",image_url)
  show_area.click(show_screen_image)
  return false

$(document).on("change",".work.panel input[type=checkbox], #batch_edit_property", ->
  show_or_hide_selected_works()
)
$(document).on("click","img.show",show_screen_image)
$(document).on("click",".imageviewer .thumbs a", click_thumb_event)
$(document).on("submit","form#new_work", ->
  d = new Date()
  d.setHours(24)
  docCookies.setItem("lastLocation", $("form#new_work input#work_location").val(), d);
);

$(document).on("ready", ->
  show_or_hide_selected_works()
  $("form#new_work input#work_location").val(docCookies.getItem("lastLocation"));
)
$(document).on("turbolinks:load", ->
  $("form#new_work input#work_location").val(docCookies.getItem("lastLocation"));
  show_or_hide_selected_works()
)

$(document).on("click", "span.select_all", (e)->
  container_div = $(e.target).parents("form,.select_all_scope")[0]
  inputs = container_div.querySelectorAll("input[name='selected_works[]']")
  for elem in inputs
    elem.checked = true
  $(inputs[0]).trigger('change')
  e.target.classList.add "unselect_all"
  e.target.classList.remove "select_all"
  e.target.innerHTML = "Deselecteer alles"
  buttons = container_div.querySelectorAll("span.select_all")
  for elem in buttons
    elem.classList.add "unselect_all"
    elem.classList.remove "select_all"
    elem.innerHTML = "Deselecteer alles"
)

$(document).on("click", "span.unselect_all", (e)->
  container_div = $(e.target).parents("form,.select_all_scope")[0]
  inputs = container_div.querySelectorAll("input[name='selected_works[]']")
  for elem in inputs
    elem.checked = false
  $(inputs[0]).trigger('change')
  e.target.classList.add "select_all"
  e.target.classList.remove "unselect_all"
  e.target.innerHTML = "Selecteer alles"
  buttons = container_div.querySelectorAll("span.unselect_all")
  for elem in buttons
    elem.classList.add "select_all"
    elem.classList.remove "unselect_all"
    elem.innerHTML = "Selecteer alles"
)