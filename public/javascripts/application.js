$(document).ready(function() {
  $("#primary-search-box").submit(function(event){
    event.preventDefault();
    var searchValue = $("#primary-search-box").find(".search-box").val();
    if(searchValue.length > 0){
      $.ajax({
        url: "/search",
        data: {query: searchValue},
        beforeSend: function(){ 
          $(".ajax-spinner").show();
        }
      });
    }
  });
});