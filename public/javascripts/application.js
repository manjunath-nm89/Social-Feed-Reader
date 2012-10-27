$(document).ready(function() {
  $("#primary-search-box").submit(function(event){
    event.preventDefault();
    var searchValue = $("#primary-search-box").find(".search-box").val();
    if(searchValue.length > 0){
      $.ajax({
        url: "/search",
        data: {query: searchValue},
        beforeSend: function(){ 
          $(".ajax-spinner").css({visibility: "visible"});
        },
        complete: function(data){
          $(".ajax-spinner").css({visibility: "hidden"});
          $("#result_set").html(data.responseText);
          processTimeAndVids();
        }
      });
    }
  });

  $(".show-more-div a#show_more_link").live("click", function(event){
    event.preventDefault();
    var showMoreDiv = jQuery(this).closest(".show-more-div");
    var aLink = jQuery(this);
    $.ajax({
      url: "/search",
      data: {
        pagination: true,
        q: aLink.data("q"), 
        access_token: aLink.data("access-token"), 
        until: aLink.data("until"),
        limit: aLink.data("limit")
      },
      beforeSend: function(){ 
        aLink.hide();
        showMoreDiv.find(".ajax-spinner").show();
      },
      complete: function(data){
        showMoreDiv.remove();
        $("#result_set").append(data.responseText);
        processTimeAndVids();
      }
    });
  });
});

function processTimeAndVids(){
  calculateTimeAgo();
  $(".iframe_container").each(function(){
    var aLink = $(this).find("a")
    $(this).oembed(aLink.attr("href"));  
  });
}

function calculateTimeAgo(){
  jQuery("abbr.timeago").timeago();
}

