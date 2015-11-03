var concourse = {
  redirect: function(href) {
    window.location = href;
  }
};

$(".js-expandable").on("click", function() {
  if($(this).parent().hasClass("expanded")) {
    $(this).parent().removeClass("expanded");
  } else {
    $(this).parent().addClass("expanded");
  }
});
