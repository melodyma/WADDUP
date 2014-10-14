// Range Slider Value //
function showValue(newValue){
  document.getElementById("range").innerHTML=newValue;
};

// Loading Page Image //
$(function(){
  $("#waddup-btn").click(function(){
    $("html").addClass("loading");
  });
});

